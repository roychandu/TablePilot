// ignore_for_file: deprecated_member_use, empty_catches

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:table_pilot/aws/aws_fields.dart';
import 'package:table_pilot/common_widgets/app_design_system.dart';
import '../../common_widgets/app_colors.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  dynamic _profileImage; // Can be File or String (AWS URL)
  File? pickedImage;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() {
        _isLoadingData = true;
      });

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoadingData = false;
        });
        _showSnackBar('User not authenticated', AppColors.error);
        return;
      }

      // Load user data from AuthService
      final userData = await _authService.getUserData();

      setState(() {
        _nameController.text = userData['name'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _profileImage = userData['photoUrl'] ??
            userData['profileImage'] ??
            userData['photoURL'];
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      _showSnackBar('Error loading profile data: $e', AppColors.error);
    }
  }

  Future<File> pickAndCompressImage(File imageFile) async {
    try {
      // For now, return the original file
      // You can add image compression logic here if needed
      return imageFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageFile;
    }
  }

  Future<String?> uploadProfileImage(String imagePath) async {
    try {
      String fileName =
          "profileimg_${FirebaseAuth.instance.currentUser?.uid}_${DateTime.now().millisecondsSinceEpoch}.png";
      String? newImageName = await uploadImageToAWS(
        file: File(imagePath),
        fileName: fileName,
      );

      debugPrint('newImageName: $newImageName : $fileName');
      return newImageName;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
    }
    return null;
  }

  Future<void> _handleImageFromSource(ImageSource source) async {
    try {
      final String? imagePath = await _pickImage(source);
      if (imagePath == null) return;

      final File compressedImage = await pickAndCompressImage(File(imagePath));

      if (!mounted) return;
      setState(() {
        pickedImage = compressedImage;
        _profileImage = compressedImage;
      });
    } catch (e) {
      debugPrint('Error handling selected image: $e');
    }
  }

  Future<String?> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        return image.path;
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  Future<void> _showImageSourceDialog() async {
    try {
      // Show options dialog for camera or gallery
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
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
        await _handleImageFromSource(source);
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', AppColors.error);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload profile image if selected
      String? uploadedImageUrl;
      if (_profileImage != null && _profileImage is File) {
        final uploadedImageName = await uploadProfileImage(_profileImage!.path);
        if (uploadedImageName != null && uploadedImageName.isNotEmpty) {
          uploadedImageUrl = getUrlForUserUploadedImage(uploadedImageName);
        }
      }

      // Update user profile
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        await _authService.updateUserProfile(
          displayName: _nameController.text.trim(),
          photoURL: uploadedImageUrl,
        );
      }

      if (mounted) {
        _showSnackBar('Profile updated successfully!', AppColors.success);
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate data was updated
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error updating profile: $e', AppColors.error);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(AppDesignSystem.radiusCard),
            bottomRight: Radius.circular(AppDesignSystem.radiusCard),
          ),
        ),
      ),
      body: _isLoadingData
          ? const Center(
              child: CupertinoActivityIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Picture Section
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _showImageSourceDialog,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.cardBackground,
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.shadow,
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: _profileImage != null
                                      ? ClipOval(
                                          child: _profileImage is File
                                              ? Image.file(
                                                  _profileImage!,
                                                  width: 120,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.network(
                                                  _profileImage!,
                                                  width: 120,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return const Icon(
                                                          Icons.person,
                                                          size: 60,
                                                          color:
                                                              AppColors.primary,
                                                        );
                                                      },
                                                ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: AppColors.primary,
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _showImageSourceDialog,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.cardBackground,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: AppColors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Profile Photo',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // User Information Section
                    _buildSectionHeader('User Information'),
                    const SizedBox(height: 16),

                    // Name Field
                    _buildFormField(
                      label: 'Name',
                      controller: _nameController,
                      hint: 'Enter your name',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field (Read-only)
                    _buildFormField(
                      label: 'Email',
                      controller: _emailController,
                      hint: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      isReadOnly: true,
                    ),
                    const SizedBox(height: 16),

                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                    AppColors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isReadOnly = false,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            if (isReadOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning, width: 1),
                ),
                child: const Text(
                  'READ-ONLY',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success, width: 1),
                ),
                child: const Text(
                  'EDITABLE',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isReadOnly
                ? AppColors.cardBackground.withOpacity(0.6)
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border,
              width: isReadOnly ? 2 : 1,
            ),
            boxShadow: isReadOnly
                ? []
                : [
                    BoxShadow(
                      color: AppColors.shadow.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextFormField(
            maxLength: maxLength,
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            enabled: !isReadOnly,
            decoration: InputDecoration(
              hintText: isReadOnly ? 'This field cannot be edited' : hint,
              hintStyle: TextStyle(
                color: isReadOnly
                    ? AppColors.textSecondary.withOpacity(0.8)
                    : AppColors.textSecondary,
                fontSize: 16,
                fontStyle: isReadOnly ? FontStyle.italic : FontStyle.normal,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: isReadOnly
                  ? const Icon(
                      Icons.lock_outline,
                      color: AppColors.textSecondary,
                      size: 20,
                    )
                  : const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
            ),
            style: TextStyle(
              fontSize: 16,
              color: isReadOnly ? AppColors.textSecondary : AppColors.primary,
              fontWeight: isReadOnly ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
