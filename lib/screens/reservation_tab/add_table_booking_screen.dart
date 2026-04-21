// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/table_booking_model.dart';
import '../../models/reservation_model.dart';
import '../../models/menu_model.dart';
import '../../models/staff_model.dart';
import '../../services/table_booking_service.dart';
import '../../services/menu_service.dart';
import '../../services/staff_service.dart';
import '../../services/offer_service.dart';
import '../../models/offer_model.dart';
import '../../utils/offer_helper.dart';
import '../staff_tab/add_staff_screen.dart';

class AddTableBookingScreen extends StatefulWidget {
  final int? tableNumber;

  const AddTableBookingScreen({super.key, this.tableNumber});

  @override
  State<AddTableBookingScreen> createState() => _AddTableBookingScreenState();
}

class _AddTableBookingScreenState extends State<AddTableBookingScreen> {
  final TableBookingService _tableBookingService = TableBookingService();
  final MenuService _menuService = MenuService();
  final StaffService _staffService = StaffService();
  final OfferService _offerService = OfferService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _specialPreferencesController = TextEditingController();

  // Form fields
  bool _isSubmitting = false;

  // Custom message display
  String? _messageText;
  Color? _messageColor;
  Timer? _messageTimer;

  // Get the selected table number
  int? get _selectedTable => widget.tableNumber;

  // Get seat count for a table number
  // Pattern: 1-3 (2 seats), 4-6 (4 seats), 7-8 (6 seats), 9-10 (8 seats)
  // This pattern repeats for each floor
  int _getSeatCount(int tableNumber) {
    // Get the position within the floor (1-10)
    final positionInFloor = ((tableNumber - 1) % 10) + 1;

    if (positionInFloor >= 1 && positionInFloor <= 3) {
      return 2;
    } else if (positionInFloor >= 4 && positionInFloor <= 6) {
      return 4;
    } else if (positionInFloor >= 7 && positionInFloor <= 8) {
      return 6;
    } else if (positionInFloor >= 9 && positionInFloor <= 10) {
      return 8;
    }
    return 2; // Default fallback
  }

  // Get table status from bookings
  Future<String> _getTableStatus(int tableNumber) async {
    try {
      final bookings = await _tableBookingService.getTableBookings();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Find active bookings for this table
      for (final booking in bookings) {
        if (booking.tableNumber == tableNumber &&
            booking.status != TableBookingStatus.cancelled) {
          final bookingDateTime = DateTime(
            booking.bookingDate.year,
            booking.bookingDate.month,
            booking.bookingDate.day,
            booking.bookingTime.hour,
            booking.bookingTime.minute,
          );

          // Only consider bookings for today or future
          if (bookingDateTime.isAfter(todayStart) ||
              bookingDateTime.isAtSameMomentAs(todayStart)) {
            switch (booking.status) {
              case TableBookingStatus.seated:
                return 'Occupied';
              case TableBookingStatus.confirmed:
                return 'Reserved';
              case TableBookingStatus.cleaning:
                return 'Cleaning';
              case TableBookingStatus.completed:
                return 'Completed';
              case TableBookingStatus.cancelled:
                break;
            }
          }
        }
      }
      return 'Available';
    } catch (e) {
      return 'Available';
    }
  }

  // Menu selection fields
  final List<ReservationMenuItem> _selectedMenuItems = [];
  RestaurantMenu? _menu;

  // Staff assignment
  final List<String> _assignedStaffIds = [];
  List<StaffModel> _availableStaff = [];

  // Offers
  List<OfferModel> _activeOffers = [];

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _loadStaff();
    _loadOffers();
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

  Future<void> _loadStaff() async {
    final staff = await _staffService.getStaff();
    setState(() {
      _availableStaff = staff;
    });
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await _offerService.getActiveOffersForCustomers();
      if (mounted) {
        setState(() {
          _activeOffers = offers;
        });
      }
    } catch (e) {
      debugPrint('Error loading offers: $e');
    }
  }

  void _showMessage(String message, Color color) {
    setState(() {
      _messageText = message;
      _messageColor = color;
    });

    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _messageText = null;
          _messageColor = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _specialPreferencesController.dispose();
    super.dispose();
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMenuItems.isEmpty) {
      _showMessage('Please select at least one menu item', AppColors.error);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Use defaults for removed fields
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentTime = TimeOfDay.fromDateTime(
        now,
      ); // Use actual current time

      final booking = TableBookingModel(
        guestName: null, // Not collected in simplified form
        phoneNumber: null, // Not collected in simplified form
        email: null, // Not collected in simplified form
        bookingDate: today, // Default to today
        bookingTime: currentTime, // Use actual current time
        numberOfGuests: 2, // Default to 2 guests
        durationHours: 1.0, // Default to 1 hour since we're using 1-hour slots
        floor: _selectedTable != null
            ? 'Floor ${((_selectedTable! - 1) ~/ 10) + 1}'
            : 'Floor 1', // Calculate floor from table number
        tableNumber: _selectedTable, // Use selected table number
        menuItems: _selectedMenuItems,
        specialPreferences: _specialPreferencesController.text.trim().isEmpty
            ? null
            : _specialPreferencesController.text.trim(),
        status: TableBookingStatus
            .seated, // Set to seated so it displays as "Occupied"
        assignedStaffIds: _assignedStaffIds,
      );

      final bookingId = await _tableBookingService.createTableBooking(booking);

      if (bookingId != null && mounted) {
        _showMessage('Table booking created successfully', AppColors.success);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        if (mounted) {
          _showMessage('Failed to create booking', AppColors.error);
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('An error occurred', AppColors.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 24.0 : 16.0;

    return Container(
      height: screenHeight * 0.9,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Table Booking',
                            style: AppTextStyles.h4.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Book a single table for guests',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              // Content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Scrollable Menu Selection Section
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(horizontalPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Selected Table Display
                              if (_selectedTable != null) ...[
                                _buildSelectedTableDisplay(),
                                const SizedBox(height: 12),
                              ],
                              // Menu Selection Section
                              _buildSectionHeader(
                                icon: Icons.restaurant_menu,
                                title: 'Menu Selection',
                              ),
                              const SizedBox(height: 8),
                              _buildMenuSelectionContent(),
                            ],
                          ),
                        ),
                      ),
                      // Fixed Bottom Section (Special Preferences, Staff Assignment, Action Buttons)
                      Container(
                        padding: EdgeInsets.all(horizontalPadding),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Special Preferences
                            _buildSectionHeader(
                              icon: CupertinoIcons.info,
                              title: 'Special Preferences',
                            ),
                            const SizedBox(height: 16),
                            _buildTextArea(
                              controller: _specialPreferencesController,
                              hintText: 'preferences, or special occasions...',
                            ),
                            const SizedBox(height: 12),
                            _buildStaffAssignmentSection(),
                            const SizedBox(height: 12),
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(child: _buildCancelButton(isTablet)),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildCreateButton(isTablet),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Custom message overlay
          if (_messageText != null)
            Positioned(top: 0, left: 0, right: 0, child: _buildMessageWidget()),
        ],
      ),
    );
  }

  Widget _buildMessageWidget() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _messageColor ?? AppColors.error,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _messageText ?? '',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.white, size: 20),
            onPressed: () {
              setState(() {
                _messageText = null;
                _messageColor = null;
              });
              _messageTimer?.cancel();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTableDisplay() {
    if (_selectedTable == null) return const SizedBox.shrink();

    final seatCount = _getSeatCount(_selectedTable!);

    return FutureBuilder<String>(
      future: _getTableStatus(_selectedTable!),
      builder: (context, snapshot) {
        final status = snapshot.data ?? 'Available';
        Color statusColor;
        Color statusBgColor;

        switch (status) {
          case 'Occupied':
            statusColor = AppColors.error;
            statusBgColor = AppColors.error.withOpacity(0.1);
            break;
          case 'Reserved':
            statusColor = AppColors.warning;
            statusBgColor = AppColors.warning.withOpacity(0.1);
            break;
          case 'Cleaning':
            statusColor = AppColors.info;
            statusBgColor = AppColors.info.withOpacity(0.1);
            break;
          default: // Available
            statusColor = AppColors.success;
            statusBgColor = AppColors.success.withOpacity(0.1);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.square_grid_2x2,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Table T$_selectedTable',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$seatCount ${seatCount == 1 ? 'seat' : 'seats'}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaffAssignmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign Staff (Optional)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Allocate team members to this booking',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _showStaffSelectionDialog,
                icon: Icon(Icons.add, size: 18, color: AppColors.white),
                label: Text(
                  'Add Staff',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_assignedStaffIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._getAssignedStaff().map((staff) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surface,
                    child: Text(
                      _getStaffInitials(staff.fullName),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.fullName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          staff.category,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () {
                      setState(() {
                        _assignedStaffIds.remove(staff.id);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  List<StaffModel> _getAssignedStaff() {
    return _availableStaff
        .where(
          (staff) => staff.id != null && _assignedStaffIds.contains(staff.id),
        )
        .toList();
  }

  void _showStaffSelectionDialog() {
    final unassignedStaff = _availableStaff
        .where(
          (staff) =>
              staff.id != null &&
              !_assignedStaffIds.contains(staff.id) &&
              staff.category.toLowerCase() == 'waiter',
        )
        .toList();

    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        title: Text(
          'Select Staff',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Container(
          width: screenWidth - 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SizedBox(
              width: double.maxFinite,
              child: unassignedStaff.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No staff available',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AddStaffScreen(),
                                ),
                              ).then((_) {
                                _loadStaff();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              'Add new Staff',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: unassignedStaff.length,
                      itemBuilder: (context, index) {
                        final staff = unassignedStaff[index];
                        final isActive = staff.inFloor;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.surface,
                            child: Text(
                              _getStaffInitials(staff.fullName),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            staff.fullName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  staff.category,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isActive
                                              ? AppColors.success
                                              : AppColors.error)
                                          .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'In-active',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isActive
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            if (!isActive) {
                              _showMessage(
                                'This staff member is In-active and cannot be assigned.',
                                AppColors.error,
                              );
                              return;
                            }
                            if (staff.id != null) {
                              setState(() {
                                _assignedStaffIds.add(staff.id!);
                              });
                              Navigator.pop(context);
                            }
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStaffInitials(String name) {
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

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.success, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSelectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_menu != null && _menu!.categories.isNotEmpty) ...[
          _buildMenuItemsList(),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'No menu items available',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
        if (_selectedMenuItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSelectedItemsCard(),
        ],
      ],
    );
  }

  Widget _buildMenuItemsList() {
    if (_menu == null || _menu!.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _menu!.categories.map((category) {
        if (category.items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Text(
                category.categoryName,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            // Menu Items in this category
            ...category.items.map((item) {
              final existingItem = _selectedMenuItems.firstWhere(
                (i) => i.itemName == item.itemName,
                orElse: () =>
                    ReservationMenuItem(itemName: '', quantity: 0, priceAed: 0),
              );
              final quantity = existingItem.itemName.isNotEmpty
                  ? existingItem.quantity
                  : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (item.imagePath != null && item.imagePath!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imagePath!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: AppColors.surface,
                          ),
                        ),
                      ),
                    if (item.imagePath != null && item.imagePath!.isNotEmpty)
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildPriceWithOffer(item, category.categoryName),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (quantity > 0)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            color: AppColors.textPrimary,
                            onPressed: () {
                              setState(() {
                                if (quantity > 1) {
                                  final index = _selectedMenuItems.indexWhere(
                                    (i) => i.itemName == item.itemName,
                                  );
                                  // Apply discount if offer exists
                                  double finalPrice = item.priceAed;
                                  final bestOffer =
                                      OfferHelper.getBestOfferForItem(
                                        _activeOffers,
                                        item,
                                        category.categoryName,
                                      );
                                  if (bestOffer != null) {
                                    finalPrice =
                                        OfferHelper.calculateDiscountedPrice(
                                          item.priceAed,
                                          bestOffer,
                                        );
                                  }
                                  _selectedMenuItems[index] =
                                      ReservationMenuItem(
                                        itemName: item.itemName,
                                        quantity: quantity - 1,
                                        priceAed: finalPrice,
                                      );
                                } else {
                                  _selectedMenuItems.removeWhere(
                                    (i) => i.itemName == item.itemName,
                                  );
                                }
                              });
                            },
                          ),
                          Text(
                            '$quantity',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            color: AppColors.textPrimary,
                            onPressed: () {
                              setState(() {
                                final index = _selectedMenuItems.indexWhere(
                                  (i) => i.itemName == item.itemName,
                                );
                                if (index >= 0) {
                                  // Apply discount if offer exists
                                  double finalPrice = item.priceAed;
                                  final bestOffer =
                                      OfferHelper.getBestOfferForItem(
                                        _activeOffers,
                                        item,
                                        category.categoryName,
                                      );
                                  if (bestOffer != null) {
                                    finalPrice =
                                        OfferHelper.calculateDiscountedPrice(
                                          item.priceAed,
                                          bestOffer,
                                        );
                                  }
                                  _selectedMenuItems[index] =
                                      ReservationMenuItem(
                                        itemName: item.itemName,
                                        quantity: quantity + 1,
                                        priceAed: finalPrice,
                                      );
                                } else {
                                  // Apply discount if offer exists
                                  double finalPrice = item.priceAed;
                                  final bestOffer =
                                      OfferHelper.getBestOfferForItem(
                                        _activeOffers,
                                        item,
                                        category.categoryName,
                                      );
                                  if (bestOffer != null) {
                                    finalPrice =
                                        OfferHelper.calculateDiscountedPrice(
                                          item.priceAed,
                                          bestOffer,
                                        );
                                  }
                                  _selectedMenuItems.add(
                                    ReservationMenuItem(
                                      itemName: item.itemName,
                                      quantity: 1,
                                      priceAed: finalPrice,
                                    ),
                                  );
                                }
                              });
                            },
                          ),
                        ],
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.add, size: 24),
                        color: AppColors.primary,
                        onPressed: () {
                          setState(() {
                            // Apply discount if offer exists
                            double finalPrice = item.priceAed;
                            final bestOffer = OfferHelper.getBestOfferForItem(
                              _activeOffers,
                              item,
                              category.categoryName,
                            );
                            if (bestOffer != null) {
                              finalPrice = OfferHelper.calculateDiscountedPrice(
                                item.priceAed,
                                bestOffer,
                              );
                            }
                            _selectedMenuItems.add(
                              ReservationMenuItem(
                                itemName: item.itemName,
                                quantity: 1,
                                priceAed: finalPrice,
                              ),
                            );
                          });
                        },
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPriceWithOffer(MenuItem item, String categoryName) {
    final bestOffer = OfferHelper.getBestOfferForItem(
      _activeOffers,
      item,
      categoryName,
    );

    if (bestOffer != null) {
      final discountedPrice = OfferHelper.calculateDiscountedPrice(
        item.priceAed,
        bestOffer,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AED ${discountedPrice.toStringAsFixed(0)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getOfferBadgeText(bestOffer),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'AED ${item.priceAed.toStringAsFixed(0)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              decoration: TextDecoration.lineThrough,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return Text(
      'AED ${item.priceAed.toStringAsFixed(0)}',
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.warning,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _getOfferBadgeText(OfferModel offer) {
    switch (offer.offerType) {
      case OfferType.percentageDiscount:
        return '${offer.discountValue.toInt()}% OFF';
      case OfferType.fixedAmountOff:
        return 'AED ${offer.discountValue.toStringAsFixed(0)} OFF';
      case OfferType.buyOneGetOne:
        return 'BOGO';
      case OfferType.freeItemWithPurchase:
        return 'FREE';
    }
  }

  Widget _buildSelectedItemsCard() {
    double subtotal = 0.0;
    double totalDiscount = 0.0;

    // Calculate subtotal and discounts
    for (final item in _selectedMenuItems) {
      // Use original price for subtotal calculation
      double originalItemPrice = item.priceAed;

      // Find menu item to get original price
      if (_menu != null) {
        for (final category in _menu!.categories) {
          final menuItem = category.items.firstWhere(
            (i) => i.itemName == item.itemName,
            orElse: () => MenuItem(itemName: '', description: '', priceAed: 0),
          );
          if (menuItem.itemName.isNotEmpty) {
            originalItemPrice = menuItem.priceAed;
            break;
          }
        }
      }

      subtotal += originalItemPrice * item.quantity;

      // Calculate discount (difference between original and discounted)
      final originalTotal = originalItemPrice * item.quantity;
      final discountedTotal = item.totalPrice;
      totalDiscount += (originalTotal - discountedTotal);
    }

    // Calculate order-level discount
    final orderDiscount = OfferHelper.calculateOrderDiscount(
      _activeOffers,
      subtotal,
      _selectedMenuItems,
      _menu,
    );
    final orderDiscountAmount = orderDiscount['discount'] as double? ?? 0.0;
    totalDiscount += orderDiscountAmount;

    final finalTotal = (subtotal - totalDiscount).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Items',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._selectedMenuItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.quantity}x ${item.itemName}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'AED ${item.totalPrice.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'AED ${subtotal.toStringAsFixed(0)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (totalDiscount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '-AED ${totalDiscount.toStringAsFixed(0)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'AED ${finalTotal.toStringAsFixed(0)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 1,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary.withOpacity(0.5),
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
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
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildCancelButton(bool isTablet) {
    return SizedBox(
      height: isTablet ? 56.0 : 48.0,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Cancel',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton(bool isTablet) {
    return SizedBox(
      height: isTablet ? 56.0 : 48.0,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : Text(
                'Take Order',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// Custom Time Slot Picker Sheet
// (Custom time slot picker widget removed; using standard time picker in _selectTime)
