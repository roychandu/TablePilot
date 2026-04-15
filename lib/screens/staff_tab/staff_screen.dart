// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/staff_model.dart';
import '../../services/staff_service.dart';
import 'add_staff_screen.dart';
import 'staff_profile_screen.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final StaffService _staffService = StaffService();
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = const ['All', 'Cleaner', 'Cook', 'Waiter'];

  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  List<StaffModel> _filterStaff(List<StaffModel> staff) {
    final query = _searchController.text.trim().toLowerCase();
    return staff.where((s) {
      final matchesCategory =
          _selectedCategory == 'All' || s.category == _selectedCategory;
      final searchable = '${s.firstName} ${s.lastName} ${s.category} ${s.shift}'
          .toLowerCase();
      final matchesSearch = query.isEmpty || searchable.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  int _countForCategory(List<StaffModel> staff, String category) {
    if (category == 'All') return staff.length;
    return staff.where((s) => s.category == category).length;
  }

  Future<void> _toggleInFloor(StaffModel staff) async {
    final id = staff.id;
    if (id == null) return;
    final newValue = !staff.inFloor;

    final success = await _staffService.updateInFloor(id, newValue);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update in-floor status. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'Staff',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<StaffModel>>(
          stream: _staffService.getStaffStream(),
          builder: (context, snapshot) {
            final staff = snapshot.data ?? [];
            final filtered = _filterStaff(staff);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: _buildSearchField(),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      final count = _countForCategory(staff, category);
                      return ChoiceChip(
                        label: Text(
                          '$category $count',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isSelected
                                ? AppColors.white
                                : AppColors.text2,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        backgroundColor: AppColors.cardBackground,
                        selectedColor: AppColors.primary,
                        shape: const StadiumBorder(),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: _categories.length,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No staff added yet',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final staffMember = filtered[index];
                            return _buildStaffCard(staffMember);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddStaffScreen()),
          );
          if (created == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Staff added successfully')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.cardBackground,
        prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
        hintText: 'Search by name, duty',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildStaffCard(StaffModel staff) {
    final initials = _getInitials(staff.fullName);
    final joinDate =
        '${staff.startDate.day.toString().padLeft(2, '0')}/${staff.startDate.month.toString().padLeft(2, '0')}/${staff.startDate.year}';

    return InkWell(
      onTap: () async {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => StaffProfileScreen(staff: staff)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStaffAvatar(staff, initials),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.fullName,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Work : ${staff.category}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Shift : ${staff.shift}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Join Date : $joinDate',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildInFloorToggle(staff),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffAvatar(StaffModel staff, String initials) {
    final photoUrl = staff.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

    if (!hasPhoto) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.surface,
        child: Text(
          initials,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.surface,
      child: ClipOval(
        child: Image.network(
          photoUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              initials,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInFloorToggle(StaffModel staff) {
    final id = staff.id;
    final isDisabled = id == null;
    final isActive = staff.inFloor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'In Floor',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: isActive,
            onChanged: isDisabled ? null : (value) => _toggleInFloor(staff),
            activeColor: AppColors.success,
            inactiveThumbColor: AppColors.error,
            inactiveTrackColor: AppColors.error.withOpacity(0.3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isActive ? 'Active' : 'In-active',
          style: AppTextStyles.bodySmall.copyWith(
            color: isActive ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1 && parts.first.isNotEmpty) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first.substring(0, 1)
        : '';
    final second = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].substring(0, 1)
        : '';
    final initials = (first + second).toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }
}
