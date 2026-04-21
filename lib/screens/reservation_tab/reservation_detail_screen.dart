// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/reservation_model.dart';
import '../../models/staff_model.dart';
import '../../services/reservation_service.dart';
import '../../services/staff_service.dart';
import 'add_order_screen.dart';
import 'edit_reservation_screen.dart';

class ReservationDetailScreen extends StatefulWidget {
  ReservationDetailScreen({super.key, required this.event});

  final dynamic
  event; // Accepts both ReservationModel and EventModel for compatibility

  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  final ReservationService _eventService = ReservationService();
  final StaffService _staffService = StaffService();
  late dynamic _event; // Can be ReservationModel or EventModel
  List<StaffModel> _availableStaff = [];

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadStaff();
  }

  // Helper to get reservation name
  String get _reservationName {
    if (_event is ReservationModel) {
      return (_event as ReservationModel).reservationName;
    }
    return _event.eventName;
  }

  // Helper to get reservation date
  DateTime get _reservationDate {
    if (_event is ReservationModel) {
      return (_event as ReservationModel).reservationDate;
    }
    return _event.eventDate;
  }

  // Helper to get reservation type
  ReservationType get _reservationType {
    if (_event is ReservationModel) {
      return (_event as ReservationModel).reservationType;
    }
    return eventTypeToReservationType(_event.eventType);
  }

  // Helper to get reservation status
  ReservationStatus get _reservationStatus {
    if (_event is ReservationModel) {
      return (_event as ReservationModel).status;
    }
    return eventStatusToReservationStatus(_event.status);
  }

  // Helper to get table number
  int? get _tableNumber {
    if (_event is ReservationModel) {
      return (_event as ReservationModel).tableNumber;
    }
    return null; // Legacy EventModel doesn't have tableNumber
  }

  Future<void> _loadStaff() async {
    final staff = await _staffService.getStaff();
    setState(() {
      _availableStaff = staff;
    });
  }

  List<StaffModel> _getAssignedStaff() {
    return _availableStaff
        .where(
          (staff) =>
              staff.id != null && _event.assignedStaffIds.contains(staff.id),
        )
        .toList();
  }

  IconData _getEventTypeIcon(ReservationType type) {
    switch (type) {
      case ReservationType.corporateEvent:
        return CupertinoIcons.building_2_fill;
      case ReservationType.wedding:
        return CupertinoIcons.heart_fill;
      case ReservationType.birthdayParty:
        return Icons.cake;
      case ReservationType.anniversary:
        return CupertinoIcons.heart_fill;
      case ReservationType.conference:
        return CupertinoIcons.chart_bar_fill;
      case ReservationType.galaDinner:
        return Icons.restaurant;
      case ReservationType.other:
        return CupertinoIcons.question_circle_fill;
    }
  }

  Color _getEventTypeColor(ReservationType type) {
    switch (type) {
      case ReservationType.corporateEvent:
        return AppColors.info;
      case ReservationType.wedding:
        return AppColors.accent1;
      case ReservationType.birthdayParty:
        return AppColors.warning;
      case ReservationType.anniversary:
        return AppColors.error;
      case ReservationType.conference:
        return AppColors.occupied;
      case ReservationType.galaDinner:
        return AppColors.warning;
      case ReservationType.other:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  bool _canMarkAsCompleted() {
    final now = DateTime.now();
    final reservationDateTime = DateTime(
      _reservationDate.year,
      _reservationDate.month,
      _reservationDate.day,
      _event.startTime.hour,
      _event.startTime.minute,
    );
    // Show button if current time is after or equal to reservation time
    return now.isAfter(reservationDateTime) ||
        now.isAtSameMomentAs(reservationDateTime);
  }

  Future<void> _markAsCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Mark as Completed',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to mark this reservation as completed?',
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
                'Mark Completed',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && _event.id != null) {
      final success = await _eventService.updateReservationStatus(
        reservationId: _event.id!,
        status: ReservationStatus.completed,
      );
      if (success && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _cancelEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Cancel Reservation',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel this reservation? This action cannot be undone.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep Reservation',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Cancel Reservation',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && _event.id != null) {
      final success = await _eventService.updateReservationStatus(
        reservationId: _event.id!,
        status: ReservationStatus.cancelled,
      );
      if (success && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventTypeColor = _getEventTypeColor(_reservationType);
    final eventTypeIcon = _getEventTypeIcon(_reservationType);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: eventTypeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(eventTypeIcon, color: eventTypeColor, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _reservationName,
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Completed Status Indicator (if completed)
            if (_reservationStatus == ReservationStatus.completed) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reservation Completed',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_reservationStatus == ReservationStatus.cancelled) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reservation Cancelled',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_reservationStatus == ReservationStatus.rejected) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reservation Rejected',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Reservation Details
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Date
                  _buildDetailRow(
                    icon: CupertinoIcons.calendar,
                    label: 'Date',
                    value: _formatDate(_reservationDate),
                  ),
                  SizedBox(height: 16),
                  // Time
                  _buildDetailRow(
                    icon: CupertinoIcons.time,
                    label: 'Time',
                    value: _formatTime(_event.startTime),
                  ),
                  SizedBox(height: 16),
                  // Guest Count
                  _buildDetailRow(
                    icon: CupertinoIcons.person_2,
                    label: 'Guest Count',
                    value: '${_event.numberOfGuests} guests',
                  ),
                  SizedBox(height: 16),
                  // Table Number (if available)
                  if (_tableNumber != null) ...[
                    _buildDetailRow(
                      icon: CupertinoIcons.square_grid_2x2,
                      label: 'Table Number',
                      value: 'Table T$_tableNumber',
                    ),
                    SizedBox(height: 16),
                  ],
                  // Contact Person
                  _buildDetailRow(
                    icon: CupertinoIcons.person,
                    label: 'Contact Person',
                    value: _event.contactPerson,
                  ),
                  SizedBox(height: 16),
                  // Email
                  _buildDetailRow(
                    icon: CupertinoIcons.mail,
                    label: 'Email',
                    value: _event.email,
                  ),
                  SizedBox(height: 16),
                  // Phone
                  _buildDetailRow(
                    icon: CupertinoIcons.phone,
                    label: 'Phone',
                    value: _event.phone,
                  ),
                  SizedBox(height: 16),
                  // Menu Categories
                  if (_event.menuCategories.isNotEmpty) ...[
                    _buildDetailRow(
                      icon: Icons.category_outlined,
                      label: 'Menu Categories',
                      value: _event.menuCategories.join('\n'),
                      maxLines: _event.menuCategories.length,
                    ),
                    SizedBox(height: 16),
                  ],
                  // Menu Items
                  if (_event.menuItems.isNotEmpty) ...[
                    _buildMenuItemsRow(),
                    SizedBox(height: 16),
                  ],
                  // Special Dietary Requirements
                  if (_event.specialDietaryRequirements.isNotEmpty) ...[
                    _buildDetailRow(
                      icon: Icons.restaurant_menu,
                      label: 'Special Dietary Requirements',
                      value: _event.specialDietaryRequirements,
                      maxLines: 3,
                    ),
                    SizedBox(height: 16),
                  ],
                  // Assigned Staff
                  if (_event.assignedStaffIds.isNotEmpty) ...[_buildStaffRow()],
                ],
              ),
            ),
            // Action Buttons (only show for non-completed and non-cancelled reservations)
            if (_reservationStatus != ReservationStatus.completed &&
                _reservationStatus != ReservationStatus.cancelled &&
                _reservationStatus != ReservationStatus.rejected) ...[
              SizedBox(height: 24),
              Column(
                children: [
                  _buildActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit Reservation',
                    color: AppColors.info,
                    onTap: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditReservationScreen(event: _event),
                        ),
                      );
                      if (updated == true && mounted) {
                        // Refresh reservation data
                        if (_event.id != null) {
                          final refreshedReservation = await _eventService
                              .getReservation(_event.id!);
                          if (refreshedReservation != null) {
                            setState(() {
                              _event = refreshedReservation;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Reservation updated successfully',
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                  SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.cancel_outlined,
                    label: 'Cancel Reservation',
                    color: AppColors.error,
                    onTap: _cancelEvent,
                  ),
                  if (_canMarkAsCompleted()) ...[
                    SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.check_circle_outline,
                      label: 'Mark as Completed',
                      color: AppColors.success,
                      onTap: _markAsCompleted,
                    ),
                  ],
                ],
              ),
            ],
            // Show "Add Orders" button ONLY when status is completed (Confirmed)
            if (_reservationStatus == ReservationStatus.completed) ...[
              SizedBox(height: 24),
              _buildActionButton(
                icon: Icons.shopping_cart_outlined,
                label: 'Add Orders',
                color: AppColors.warning,
                onTap: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddOrderScreen(event: _event),
                    ),
                  );
                  if (created == true && mounted) {
                    // Refresh reservation data to show updated menu items
                    if (_event.id != null) {
                      final refreshedReservation = await _eventService
                          .getReservation(_event.id!);
                      if (refreshedReservation != null) {
                        setState(() {
                          _event = refreshedReservation;
                        });
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Menu items updated successfully'),
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffRow() {
    final assignedStaff = _getAssignedStaff();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          CupertinoIcons.person_2_fill,
          size: 20,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assigned Staff',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 4),
              if (assignedStaff.isEmpty)
                Text(
                  'No staff assigned',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...assignedStaff.map(
                  (staff) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${staff.fullName} (${staff.category})',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        SizedBox(width: 12),
        Expanded(
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
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: maxLines,
                overflow: maxLines > 1
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.restaurant, size: 20, color: AppColors.textSecondary),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu Items',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 4),
              ..._event.menuItems.map((item) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${item.quantity}x ${item.itemName} (AED ${item.totalPrice.toStringAsFixed(0)})',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.white),
        label: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
