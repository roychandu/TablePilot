// ignore_for_file: deprecated_member_use, empty_catches, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

import '../../common_widgets/app_colors.dart';
import '../../models/menu_model.dart';
import '../../services/menu_service.dart';
import '../../aws/aws_fields.dart';

class AddMenuScreen extends StatefulWidget {
  const AddMenuScreen({super.key});

  @override
  State<AddMenuScreen> createState() => _AddMenuScreenState();
}

class _AddMenuScreenState extends State<AddMenuScreen> {
  final MenuService _menuService = MenuService();
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _primaryIngredientController =
      TextEditingController();

  File? _pickedImage;
  String? _imageUrl;
  bool _isLoading = false;
  bool _addAnotherClicked = false;
  bool _isVeg = true; // Default to veg
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isNewCategory = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      // Load both Firebase menu and Default menu
      final firebaseMenu = await _menuService.getMenu();
      final defaultMenu = RestaurantMenu.getDefaultMenu();

      // Use a Set to avoid duplicates while preserving order
      final Set<String> categoryNames = {};

      // Add default categories first (to keep them at the top)
      for (final category in defaultMenu.categories) {
        categoryNames.add(category.categoryName);
      }

      // Add firebase categories (merging any new ones)
      for (final category in firebaseMenu.categories) {
        categoryNames.add(category.categoryName);
      }

      if (mounted) {
        setState(() {
          _categories = categoryNames.toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _primaryIngredientController.dispose();
    super.dispose();
  }

  Future<String?> uploadMenuItemImage(String imagePath) async {
    try {
      String fileName =
          "menuitem_${FirebaseAuth.instance.currentUser?.uid}_${DateTime.now().millisecondsSinceEpoch}.png";
      String? newImageName = await uploadImageToAWS(
        file: File(imagePath),
        fileName: fileName,
      );
      return newImageName;
    } catch (e) {
      debugPrint('Error uploading menu item image: $e');
    }
    return null;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', AppColors.error);
    }
  }

  Future<void> _showImageSourceDialog() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      title: 'Camera',
                      subtitle: 'Take a photo',
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildImageSourceOption(
                      icon: Icons.photo_library,
                      title: 'Gallery',
                      subtitle: 'Choose from gallery',
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );

      if (source != null) {
        await _pickImage(source);
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', AppColors.error);
    }
  }

  void _clearForm() {
    _categoryNameController.clear();
    _itemNameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _primaryIngredientController.clear();
    setState(() {
      _pickedImage = null;
      _imageUrl = null;
      _isVeg = true; // Reset to default
      _selectedCategory = null;
      _isNewCategory = false;
    });
    _formKey.currentState?.reset();
    _loadCategories(); // Reload categories in case new ones were added
  }

  void _addAnotherItem() {
    _clearForm();
    // Scroll to top
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    String categoryName;
    if (_isNewCategory) {
      categoryName = _categoryNameController.text.trim();
      if (categoryName.isEmpty) {
        _showSnackBar('Category name is required', AppColors.error);
        return;
      }
    } else {
      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        _showSnackBar('Please select a category', AppColors.error);
        return;
      }
      categoryName = _selectedCategory!;
    }

    if (_itemNameController.text.trim().isEmpty) {
      _showSnackBar('Item name is required', AppColors.error);
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Description is required', AppColors.error);
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      _showSnackBar('Valid price is required', AppColors.error);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload image if picked
      String? finalImageUrl = _imageUrl;
      if (_pickedImage != null) {
        final uploadedImageName = await uploadMenuItemImage(_pickedImage!.path);
        if (uploadedImageName != null && uploadedImageName.isNotEmpty) {
          finalImageUrl = getUrlForUserUploadedImage(uploadedImageName);
        }
      }

      // Get existing menu or create new
      final existingMenu = await _menuService.getMenu();
      List<MenuCategory> categories = List.from(existingMenu.categories);

      // Find or create category
      MenuCategory? targetCategory;
      int categoryIndex = -1;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i].categoryName.toLowerCase() ==
            categoryName.toLowerCase()) {
          targetCategory = categories[i];
          categoryIndex = i;
          break;
        }
      }

      // Create menu item
      final menuItem = MenuItem(
        itemName: _itemNameController.text.trim(),
        description: _descriptionController.text.trim(),
        priceAed: price,
        imagePath: finalImageUrl,
        primaryIngredient: _primaryIngredientController.text.trim().isEmpty
            ? 'Chef Special'
            : _primaryIngredientController.text.trim(),
        isVeg: _isVeg,
      );

      // Add item to category or create new category
      if (targetCategory != null) {
        // Add to existing category
        final updatedItems = List<MenuItem>.from(targetCategory.items);
        updatedItems.add(menuItem);
        categories[categoryIndex] = MenuCategory(
          categoryName: targetCategory.categoryName,
          items: updatedItems,
        );
      } else {
        // Create new category
        categories.add(
          MenuCategory(categoryName: categoryName, items: [menuItem]),
        );
      }

      // Save menu
      final menu = RestaurantMenu(categories: categories);
      final success = await _menuService.saveMenu(menu);

      if (mounted) {
        if (success) {
          // Reload categories to include the new one
          await _loadCategories();
          // Show snackbar with option to add another
          _showSuccessSnackBarWithAction();
        } else {
          _showSnackBar('Error saving menu', AppColors.error);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving menu: $e', AppColors.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBarWithAction() {
    _addAnotherClicked = false;

    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text('Menu item saved successfully!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Add Another',
              textColor: AppColors.textPrimary,
              onPressed: () {
                _addAnotherClicked = true;
                _addAnotherItem();
              },
            ),
          ),
        )
        .closed
        .then((_) {
          // Navigate back only if user didn't click "Add Another"
          if (mounted && !_addAnotherClicked) {
            Navigator.pop(context, true);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Add Menu Item',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Name Dropdown
              _buildCategoryDropdown(),
              const SizedBox(height: 20),

              // Item Image
              _buildImageField(),
              const SizedBox(height: 20),

              // Item Name
              _buildTextField(
                label: 'Item Name',
                controller: _itemNameController,
                hintText: 'Enter item name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description
              _buildTextArea(
                label: 'Description',
                controller: _descriptionController,
                hintText: 'Enter item description',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Price
              _buildTextField(
                label: 'Price (AED)',
                controller: _priceController,
                hintText: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Price is required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Valid price required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Primary Ingredient
              _buildTextField(
                label: 'Primary Ingredient',
                controller: _primaryIngredientController,
                hintText: 'e.g., Chicken, Paneer',
              ),
              const SizedBox(height: 20),

              // Veg/Non-Veg Toggle
              _buildVegNonVegToggle(),
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMenu,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textPrimary,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Menu Item',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.border.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              hintText: hintText,
              hintStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.border.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            maxLines: 3,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              hintText: hintText,
              hintStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Image',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.border.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: _pickedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _pickedImage!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  )
                : _imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _imageUrl!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildImagePlaceholder();
                      },
                    ),
                  )
                : _buildImagePlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 32, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            'Tap to add image',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.border.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final TextEditingController newCategoryController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Add New Category',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: newCategoryController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Appetizers, Main Course',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            hintStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = newCategoryController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: Text('Add', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _selectedCategory = result;
        _isNewCategory = true;
        _categoryNameController.text = result;
      });
    }

    newCategoryController.dispose();
  }

  Widget _buildCategoryDropdown() {
    final List<String> categoryOptions = [
      if (_categories.isNotEmpty) ..._categories,
      'Add new category',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Name',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.border.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: _isNewCategory ? null : _selectedCategory,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              hintText: 'Select or add category',
              hintStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: AppColors.surface,
            icon: Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
            items: categoryOptions.map((String category) {
              final isAddNew = category == 'Add new category';

              return DropdownMenuItem<String>(
                value: isAddNew ? null : category,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAddNew) ...[
                      Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isAddNew
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: isAddNew
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? value) {
              if (value == null) {
                // "Add new category" was selected
                _showAddCategoryDialog();
              } else {
                setState(() {
                  _selectedCategory = value;
                  _isNewCategory = false;
                  _categoryNameController.text = value;
                });
              }
            },
            validator: (value) {
              if (_isNewCategory) {
                if (_categoryNameController.text.trim().isEmpty) {
                  return 'Category name is required';
                }
              } else {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
              }
              return null;
            },
          ),
        ),
        // Show text field for new category name if "Add new category" is selected
        if (_isNewCategory) ...[
          const SizedBox(height: 12),
          _buildTextField(
            label: 'New Category Name',
            controller: _categoryNameController,
            hintText: 'e.g., Appetizers, Main Course',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Category name is required';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildVegNonVegToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.border.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isVeg = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isVeg
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isVeg
                            ? AppColors.success
                            : AppColors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _isVeg
                                ? AppColors.success
                                : AppColors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isVeg
                                  ? AppColors.success
                                  : AppColors.textSecondary.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: _isVeg
                              ? const Icon(
                                  Icons.check,
                                  size: 8,
                                  color: AppColors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Veg',
                          style: TextStyle(
                            color: _isVeg
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontWeight: _isVeg
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isVeg = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: !_isVeg
                          ? AppColors.warning.withOpacity(0.2)
                          : AppColors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_isVeg
                            ? AppColors.warning
                            : AppColors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: !_isVeg
                                ? AppColors.warning
                                : AppColors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: !_isVeg
                                  ? AppColors.warning
                                  : AppColors.textSecondary.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: !_isVeg
                              ? const Icon(
                                  Icons.check,
                                  size: 8,
                                  color: AppColors.black,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Non-Veg',
                          style: TextStyle(
                            color: !_isVeg
                                ? AppColors.warning
                                : AppColors.textSecondary,
                            fontWeight: !_isVeg
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
