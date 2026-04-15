// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/staff_model.dart';
import '../../services/staff_service.dart';
import 'edit_staff_screen.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key, required this.staff});

  final StaffModel staff;

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  late StaffModel _staff;
  final StaffService _staffService = StaffService();

  @override
  void initState() {
    super.initState();
    _staff = widget.staff;
  }

  String get _formattedStartDate =>
      '${_staff.startDate.day.toString().padLeft(2, '0')}/${_staff.startDate.month.toString().padLeft(2, '0')}/${_staff.startDate.year}';

  Future<void> _onEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditStaffScreen(staff: _staff)),
    );
    if (updated == true && mounted) {
      // No direct refresh from backend needed as list screen listens to stream;
      // here we just pop with true so parent can refresh if needed.
      Navigator.pop(context, true);
    }
  }

  Future<void> _onRemove() async {
    if (_staff.id == null) {
      Navigator.pop(context);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Delete Staff Profile',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete ${_staff.fullName} profile?',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete profile',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.highlight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final success = await _staffService.deleteStaff(_staff.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${_staff.fullName} profile deleted successfully'
                : 'Failed to delete ${_staff.fullName} profile',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, success);
    }
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
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _staff.fullName,
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildOverviewTab()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.cardBackground,
                        side: BorderSide(color: AppColors.cardBackground),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _onEdit,
                      child: Text(
                        'Edit',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.highlight,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _onRemove,
                      child: Text(
                        'Delete profile',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                _buildProfileAvatar(),
                const SizedBox(height: 8),
                Text(
                  _staff.category,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('Email'),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.email_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                _staff.email,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionLabel('Phone'),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                _staff.phone,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow('Category', _staff.category),
          _buildDetailRow('Shift', _staff.shift),
          _buildDetailRow(
            'Salary',
            'AED ${_staff.salaryAed.toStringAsFixed(0)}/month',
          ),
          _buildDetailRow('Experience', '${_staff.experienceYears} years'),
          _buildDetailRow('Start Date', _formattedStartDate),
          _buildDetailRow(
            'Status',
            _staff.inFloor ? 'Active' : 'In-active',
            valueColor: _staff.inFloor ? AppColors.success : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: valueColor ?? AppColors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
    );
  }

  Widget _buildProfileAvatar() {
    final initials = _getInitials(_staff.fullName);
    final photoUrl = _staff.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

    if (!hasPhoto) {
      return CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.surface,
        child: Text(
          initials,
          style: AppTextStyles.h4.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 32,
      backgroundColor: AppColors.surface,
      child: ClipOval(
        child: Image.network(
          photoUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              initials,
              style: AppTextStyles.h4.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1 && parts.first.isNotEmpty) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first[0]
        : '';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final initials = (first + second).toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }
}
