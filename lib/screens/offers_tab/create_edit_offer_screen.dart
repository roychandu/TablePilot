// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/offer_model.dart';
import '../../models/menu_model.dart';
import '../../services/offer_service.dart';
import '../../services/menu_service.dart';
import '../../aws/aws_fields.dart';

class CreateEditOfferScreen extends StatefulWidget {
  final OfferModel? offer;

  CreateEditOfferScreen({super.key, this.offer});

  @override
  State<CreateEditOfferScreen> createState() => _CreateEditOfferScreenState();
}

class _CreateEditOfferScreenState extends State<CreateEditOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final OfferService _offerService = OfferService();
  final MenuService _menuService = MenuService();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _minimumOrderValueController = TextEditingController();
  final _termsController = TextEditingController();

  // Form fields
  OfferType _selectedOfferType = OfferType.percentageDiscount;
  List<OfferApplyTo> _selectedApplyTo = [OfferApplyTo.allItems];
  List<String> _selectedCategories = [];
  List<String> _selectedItems = [];
  DateTime? _validFrom;
  DateTime? _validUntil;
  File? _bannerImage;
  String? _bannerImageUrl;
  bool _visibleToCustomers = true;
  bool _isLoading = false;
  RestaurantMenu? _menu;

  @override
  void initState() {
    super.initState();
    _loadMenu();
    if (widget.offer != null) {
      _initializeFromOffer(widget.offer!);
    } else {
      _validFrom = DateTime.now();
      _validUntil = DateTime.now().add(Duration(days: 7));
    }
  }

  Future<void> _loadMenu() async {
    try {
      // Always start with the default predefined menu
      final defaultMenu = RestaurantMenu.getDefaultMenu();

      // Try to load menu from Firebase (admin-added items)
      RestaurantMenu firebaseMenu;
      try {
        firebaseMenu = await _menuService.getMenu();
      } catch (e) {
        debugPrint('Error loading menu from Firebase: $e');
        firebaseMenu = RestaurantMenu(categories: []);
      }

      // Merge default menu with Firebase menu (admin-added items)
      final mergedMenu = _mergeMenus(defaultMenu, firebaseMenu);

      if (mounted) {
        setState(() {
          _menu = mergedMenu;
        });
      }
    } catch (e) {
      debugPrint('Error loading menu: $e');
      // Fallback to default menu if there's an error
      if (mounted) {
        setState(() {
          _menu = RestaurantMenu.getDefaultMenu();
        });
      }
    }
  }

  // Merge default menu with Firebase menu (admin-added items)
  RestaurantMenu _mergeMenus(
    RestaurantMenu defaultMenu,
    RestaurantMenu firebaseMenu,
  ) {
    if (firebaseMenu.categories.isEmpty) {
      // If no Firebase menu, just return default menu
      return defaultMenu;
    }

    // Create a map of categories by name for quick lookup
    final Map<String, MenuCategory> mergedCategoriesMap = {};

    // First, add all default menu categories
    for (final category in defaultMenu.categories) {
      mergedCategoriesMap[category.categoryName.toUpperCase()] = category;
    }

    // Then, merge or add Firebase menu categories
    for (final firebaseCategory in firebaseMenu.categories) {
      final categoryKey = firebaseCategory.categoryName.toUpperCase();

      if (mergedCategoriesMap.containsKey(categoryKey)) {
        // Category exists in both - merge items (avoid duplicates)
        final existingCategory = mergedCategoriesMap[categoryKey]!;
        final existingItemNames = existingCategory.items
            .map((item) => item.itemName.toUpperCase())
            .toSet();

        // Add Firebase items that don't already exist
        final newItems = firebaseCategory.items
            .where(
              (item) =>
                  !existingItemNames.contains(item.itemName.toUpperCase()),
            )
            .toList();

        // Merge items: existing items first, then new Firebase items
        mergedCategoriesMap[categoryKey] = MenuCategory(
          categoryName: existingCategory.categoryName,
          section: existingCategory.section ?? firebaseCategory.section,
          items: [...existingCategory.items, ...newItems],
        );
      } else {
        // New category from Firebase - add it
        mergedCategoriesMap[categoryKey] = firebaseCategory;
      }
    }

    // Convert back to list, maintaining order: default categories first, then new Firebase categories
    final List<MenuCategory> mergedCategories = [];
    final Set<String> addedCategoryNames = {};

    // Add default categories first (in their original order)
    for (final category in defaultMenu.categories) {
      mergedCategories.add(
        mergedCategoriesMap[category.categoryName.toUpperCase()]!,
      );
      addedCategoryNames.add(category.categoryName.toUpperCase());
    }

    // Add new Firebase categories (that weren't in default menu)
    for (final firebaseCategory in firebaseMenu.categories) {
      final categoryKey = firebaseCategory.categoryName.toUpperCase();
      if (!addedCategoryNames.contains(categoryKey)) {
        mergedCategories.add(mergedCategoriesMap[categoryKey]!);
        addedCategoryNames.add(categoryKey);
      }
    }

    return RestaurantMenu(categories: mergedCategories);
  }

  void _initializeFromOffer(OfferModel offer) {
    _titleController.text = offer.title;
    _descriptionController.text = offer.description;
    _selectedOfferType = offer.offerType;
    _discountValueController.text = offer.discountValue.toString();
    _selectedApplyTo = offer.applyTo;
    _selectedCategories = offer.categoryNames ?? [];
    _selectedItems = offer.itemNames ?? [];
    _validFrom = offer.validFrom;
    _validUntil = offer.validUntil;
    _termsController.text = offer.termsAndConditions ?? '';
    _minimumOrderValueController.text =
        offer.minimumOrderValue?.toString() ?? '';
    _visibleToCustomers = offer.visibleToCustomers;
    _bannerImageUrl = offer.bannerImageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _minimumOrderValueController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? (_validFrom ?? DateTime.now())
          : (_validUntil ?? DateTime.now().add(Duration(days: 7))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _validFrom = picked;
          if (_validUntil != null && _validUntil!.isBefore(_validFrom!)) {
            _validUntil = _validFrom!.add(Duration(days: 7));
          }
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  Future<void> _pickBannerImage() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text(
                  'Camera',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: Text(
                  'Gallery',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      );

      if (source != null) {
        final XFile? image = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _bannerImage = File(image.path);
            _bannerImageUrl = null;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e');
    }
  }

  Future<void> _saveOffer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_validFrom == null || _validUntil == null) {
      _showSnackBar('Please select valid dates');
      return;
    }

    if (_validUntil!.isBefore(_validFrom!)) {
      _showSnackBar('Valid until date must be after valid from date');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? bannerUrl = _bannerImageUrl;

      // Upload banner image if selected
      if (_bannerImage != null) {
        final fileName =
            'offer_banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadedImageName = await uploadImageToAWS(
          file: _bannerImage!,
          fileName: fileName,
        );
        if (uploadedImageName != null) {
          bannerUrl = getUrlForUserUploadedImage(uploadedImageName);
        }
      }

      final offer = OfferModel(
        id: widget.offer?.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        offerType: _selectedOfferType,
        discountValue: double.parse(_discountValueController.text),
        applyTo: _selectedApplyTo,
        categoryNames: _selectedApplyTo.contains(OfferApplyTo.specificCategory)
            ? _selectedCategories
            : null,
        itemNames: _selectedApplyTo.contains(OfferApplyTo.specificItems)
            ? _selectedItems
            : null,
        validFrom: _validFrom!,
        validUntil: _validUntil!,
        termsAndConditions: _termsController.text.trim().isEmpty
            ? null
            : _termsController.text.trim(),
        bannerImageUrl: bannerUrl,
        minimumOrderValue: _minimumOrderValueController.text.trim().isEmpty
            ? null
            : double.tryParse(_minimumOrderValueController.text.trim()),
        visibleToCustomers: _visibleToCustomers,
      );

      if (widget.offer != null) {
        await _offerService.updateOffer(offer);
        _showSnackBar('Offer updated successfully!', AppColors.success);
      } else {
        await _offerService.createOffer(offer);
        _showSnackBar('Offer created successfully!', AppColors.success);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Error saving offer: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, [Color? color]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          widget.offer == null ? 'Create Offer' : 'Edit Offer',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Image
              _buildBannerImageSection(),
              SizedBox(height: 24),
              // Title
              _buildTextField(
                controller: _titleController,
                label: 'Offer Title',
                hint: 'e.g., 20% Off All Burgers',
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // Description
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Describe your offer',
                maxLines: 3,
                maxLength: 200,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // Offer Type
              _buildDropdown<OfferType>(
                label: 'Offer Type',
                value: _selectedOfferType,
                items: OfferType.values,
                onChanged: (value) {
                  setState(() {
                    _selectedOfferType = value!;
                  });
                },
                displayText: (type) => getOfferTypeDisplayText(type),
              ),
              SizedBox(height: 16),
              // Discount Value
              _buildTextField(
                controller: _discountValueController,
                label: 'Discount Value',
                hint: _selectedOfferType == OfferType.percentageDiscount
                    ? 'e.g., 20'
                    : 'e.g., 5',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Discount value is required';
                  }
                  final num = double.tryParse(value);
                  if (num == null || num <= 0) {
                    return 'Enter a valid positive number';
                  }
                  if (_selectedOfferType == OfferType.percentageDiscount &&
                      num > 100) {
                    return 'Percentage cannot exceed 100';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // Apply To
              _buildApplyToSection(),
              SizedBox(height: 16),
              // Valid Dates
              _buildDateSection(),
              SizedBox(height: 16),
              // Minimum Order Value
              _buildTextField(
                controller: _minimumOrderValueController,
                label: 'Minimum Order Value (Optional)',
                hint: 'e.g., 50',
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              // Terms & Conditions
              _buildTextField(
                controller: _termsController,
                label: 'Terms & Conditions (Optional)',
                hint: 'Enter terms and conditions',
                maxLines: 4,
              ),
              SizedBox(height: 16),
              // Visible to Customers
              SwitchListTile(
                title: Text(
                  'Visible to Customers',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _visibleToCustomers,
                onChanged: (value) {
                  setState(() {
                    _visibleToCustomers = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
              SizedBox(height: 32),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.buttonLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveOffer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Save Offer',
                              style: AppTextStyles.buttonLarge.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Banner Image (16:9 ratio)',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _pickBannerImage,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: _bannerImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_bannerImage!, fit: BoxFit.cover),
                  )
                : _bannerImageUrl != null && _bannerImageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _bannerImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                    ),
                  )
                : _buildImagePlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate,
          size: 48,
          color: AppColors.textSecondary,
        ),
        SizedBox(height: 8),
        Text(
          'Tap to add banner image',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.textFieldBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) displayText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.textFieldBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.cardBackground,
              style: TextStyle(color: AppColors.textPrimary),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(displayText(item)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApplyToSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Apply To',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: OfferApplyTo.values.map((applyTo) {
            final isSelected = _selectedApplyTo.contains(applyTo);
            return FilterChip(
              label: Text(_getApplyToText(applyTo)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (applyTo == OfferApplyTo.allItems) {
                      _selectedApplyTo = [OfferApplyTo.allItems];
                    } else {
                      _selectedApplyTo.remove(OfferApplyTo.allItems);
                      if (!_selectedApplyTo.contains(applyTo)) {
                        _selectedApplyTo.add(applyTo);
                      }
                    }
                  } else {
                    _selectedApplyTo.remove(applyTo);
                    if (_selectedApplyTo.isEmpty) {
                      _selectedApplyTo = [OfferApplyTo.allItems];
                    }
                  }
                });
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary.withOpacity(0.25),
              checkmarkColor: AppColors.white,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.borderMuted,
                ),
              ),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        if (_selectedApplyTo.contains(OfferApplyTo.specificCategory)) ...[
          SizedBox(height: 16),
          _buildCategorySelector(),
        ],
        if (_selectedApplyTo.contains(OfferApplyTo.specificItems)) ...[
          SizedBox(height: 16),
          _buildItemSelector(),
        ],
      ],
    );
  }

  String _getApplyToText(OfferApplyTo applyTo) {
    switch (applyTo) {
      case OfferApplyTo.allItems:
        return 'All Items';
      case OfferApplyTo.specificCategory:
        return 'Specific Category';
      case OfferApplyTo.specificItems:
        return 'Specific Items';
      case OfferApplyTo.reservations:
        return 'Reservations';
    }
  }

  Widget _buildCategorySelector() {
    if (_menu == null) {
      return SizedBox.shrink();
    }

    final categories = _menu!.categories.map((c) => c.categoryName).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Categories',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                });
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary.withOpacity(0.25),
              checkmarkColor: AppColors.white,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.borderMuted,
                ),
              ),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildItemSelector() {
    if (_menu == null) {
      return SizedBox.shrink();
    }

    final allItems = <String>[];
    for (final category in _menu!.categories) {
      for (final item in category.items) {
        allItems.add(item.itemName);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Items',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allItems.map((item) {
            final isSelected = _selectedItems.contains(item);
            return FilterChip(
              label: Text(item),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedItems.add(item);
                  } else {
                    _selectedItems.remove(item);
                  }
                });
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary.withOpacity(0.25),
              checkmarkColor: AppColors.white,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.borderMuted,
                ),
              ),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valid Dates',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Valid From',
                date: _validFrom,
                onTap: () => _selectDate(context, true),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                label: 'Valid Until',
                date: _validUntil,
                onTap: () => _selectDate(context, false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.textFieldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              date != null
                  ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                  : 'Select date',
              style: AppTextStyles.bodyMedium.copyWith(
                color: date != null
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
