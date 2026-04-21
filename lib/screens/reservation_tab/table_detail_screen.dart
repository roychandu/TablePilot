// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/table_booking_model.dart';
import '../../services/table_booking_service.dart';
import 'add_order_screen.dart';
import 'bill_receipt_screen.dart';

class TableDetailScreen extends StatefulWidget {
  final TableBookingModel booking;

  const TableDetailScreen({super.key, required this.booking});

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  final TableBookingService _tableBookingService = TableBookingService();
  late TableBookingModel _booking;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _loadBookingData();
  }

  Future<void> _loadBookingData() async {
    if (_booking.id == null) return;

    try {
      final bookings = await _tableBookingService.getTableBookings();
      final updatedBooking = bookings.firstWhere(
        (b) => b.id == _booking.id,
        orElse: () => _booking,
      );

      if (mounted) {
        setState(() {
          _booking = updatedBooking;
        });
      }
    } catch (e) {
      // Handle error silently or show a message
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Color _getStatusColor(TableBookingStatus status) {
    switch (status) {
      case TableBookingStatus.confirmed:
        return AppColors.info;
      case TableBookingStatus.seated:
        return AppColors.success;
      case TableBookingStatus.cleaning:
        return AppColors.info;
      case TableBookingStatus.completed:
        return AppColors.success;
      case TableBookingStatus.cancelled:
        return AppColors.error;
    }
  }

  String _getStatusText(TableBookingStatus status) {
    switch (status) {
      case TableBookingStatus.confirmed:
        return 'Confirmed';
      case TableBookingStatus.seated:
        return 'Seated';
      case TableBookingStatus.cleaning:
        return 'Cleaning';
      case TableBookingStatus.completed:
        return 'Completed';
      case TableBookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  IconData _getStatusIcon(TableBookingStatus status) {
    switch (status) {
      case TableBookingStatus.confirmed:
        return Icons.check_circle_outline;
      case TableBookingStatus.seated:
        return Icons.restaurant;
      case TableBookingStatus.cleaning:
        return Icons.cleaning_services;
      case TableBookingStatus.completed:
        return Icons.check_circle;
      case TableBookingStatus.cancelled:
        return Icons.cancel;
    }
  }

  Future<void> _updateStatus(TableBookingStatus newStatus) async {
    if (_booking.id == null) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final updatedBooking = _booking.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      final success = await _tableBookingService.updateTableBooking(
        updatedBooking,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _booking = updatedBooking;
          });
          // Add a small delay to ensure Firebase propagates the update
          await Future.delayed(const Duration(milliseconds: 300));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to ${_getStatusText(newStatus)}'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update status'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    final verticalSpacing = isTablet ? 24.0 : 16.0;

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
          'Table Booking Details',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isUpdating
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: verticalSpacing),
                    // Status Badge
                    _buildStatusBadge(),
                    SizedBox(height: verticalSpacing),
                    // Booking Details Section
                    _buildSectionHeader(
                      icon: CupertinoIcons.calendar,
                      title: 'Booking Details',
                    ),
                    SizedBox(height: verticalSpacing * 0.75),
                    _buildInfoCard(
                      children: [
                        // Date and Time in one line
                        _buildInfoRow(
                          icon: CupertinoIcons.calendar,
                          label: 'Date & Time',
                          value:
                              '${_formatDate(_booking.bookingDate)} • ${_formatTime(_booking.bookingTime)}',
                        ),
                        const SizedBox(height: 16),
                        // Number of Guests
                        _buildInfoRow(
                          icon: CupertinoIcons.person_2,
                          label: 'Number of Guests',
                          value:
                              '${_booking.numberOfGuests} ${_booking.numberOfGuests == 1 ? 'Guest' : 'Guests'}',
                        ),
                        if (_booking.tableNumber != null) ...[
                          const SizedBox(height: 16),
                          // Selected Table
                          _buildInfoRow(
                            icon: CupertinoIcons.square_grid_2x2,
                            label: 'Table',
                            value: 'Table ${_booking.tableNumber}',
                          ),
                        ],
                        if (_booking.specialPreferences != null &&
                            _booking.specialPreferences!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          // Special Preferences
                          _buildInfoRow(
                            icon: Icons.note,
                            label: 'Special Preferences',
                            value: _booking.specialPreferences!,
                            isMultiline: true,
                          ),
                        ],
                      ],
                    ),
                    // Menu Items Section
                    if (_booking.menuItems.isNotEmpty) ...[
                      SizedBox(height: verticalSpacing),
                      _buildSectionHeader(
                        icon: Icons.restaurant_menu,
                        title: 'Menu Items',
                      ),
                      SizedBox(height: verticalSpacing * 0.75),
                      _buildMenuItemsCard(),
                    ],
                    SizedBox(height: verticalSpacing * 1.5),
                    // Add Order Button
                    if (_booking.status != TableBookingStatus.cancelled &&
                        _booking.status != TableBookingStatus.completed)
                      _buildAddOrderButton(),
                    if (_booking.status != TableBookingStatus.cancelled &&
                        _booking.status != TableBookingStatus.completed)
                      SizedBox(height: verticalSpacing * 0.75),
                    // Change Status Button
                    if (_booking.status != TableBookingStatus.cancelled &&
                        _booking.status != TableBookingStatus.completed)
                      _buildChangeStatusButton(),
                    // View Bill Button (only for completed bookings)
                    if (_booking.status == TableBookingStatus.completed)
                      _buildViewBillButton(),
                    if (_booking.status == TableBookingStatus.completed)
                      SizedBox(height: verticalSpacing * 0.75),
                    SizedBox(height: verticalSpacing),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final statusColor = _getStatusColor(_booking.status);
    final statusText = _getStatusText(_booking.status);
    final statusIcon = _getStatusIcon(_booking.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: AppTextStyles.bodyMedium.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: isMultiline ? null : 1,
                overflow: isMultiline ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemsCard() {
    double subtotal = 0.0;
    for (final item in _booking.menuItems) {
      subtotal += item.totalPrice;
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._booking.menuItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}x ${item.itemName}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'AED ${item.totalPrice.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: AppColors.border, height: 24),
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

  Widget _buildAddOrderButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDisabled = _booking.status == TableBookingStatus.cleaning;

    return SizedBox(
      width: double.infinity,
      height: isTablet ? 56.0 : 48.0,
      child: ElevatedButton.icon(
        onPressed: isDisabled
            ? null
            : () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddOrderScreen(event: _booking),
                  ),
                );
                // Refresh booking data after order is updated
                if (created == true && mounted) {
                  await _loadBookingData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order updated successfully'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
        icon: const Icon(Icons.add_shopping_cart, size: 20),
        label: const Text('Add Order'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.success.withOpacity(0.5),
          disabledForegroundColor: AppColors.white.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildChangeStatusButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return SizedBox(
      width: double.infinity,
      height: isTablet ? 56.0 : 48.0,
      child: ElevatedButton.icon(
        onPressed: () => _showStatusSelectionDialog(),
        icon: const Icon(Icons.edit, size: 20),
        label: const Text('Change Status'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildViewBillButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return SizedBox(
      width: double.infinity,
      height: isTablet ? 56.0 : 48.0,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BillReceiptScreen(booking: _booking),
            ),
          );
        },
        icon: const Icon(Icons.receipt_long, size: 20),
        label: const Text('View Bill'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _showStatusSelectionDialog() async {
    if (_booking.id == null) return;

    final screenWidth = MediaQuery.of(context).size.width;

    final selectedStatus = await showDialog<TableBookingStatus>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        title: Text(
          'Change Status',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          width: screenWidth - 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seated option (if confirmed)
              if (_booking.status == TableBookingStatus.confirmed)
                InkWell(
                  onTap: () {
                    Navigator.pop(context, TableBookingStatus.seated);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.restaurant,
                          color: AppColors.success,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seated',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mark guests as seated',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_booking.status == TableBookingStatus.confirmed)
                const SizedBox(height: 12),
              // Cleaning option (not shown if already cleaning)
              if (_booking.status != TableBookingStatus.cleaning) ...[
                InkWell(
                  onTap: () {
                    Navigator.pop(context, TableBookingStatus.cleaning);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cleaning_services,
                          color: AppColors.info,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cleaning',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Table needs cleaning',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Completed option
              InkWell(
                onTap: () =>
                    Navigator.pop(context, TableBookingStatus.completed),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completed',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Booking is completed',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Cancelled option
              InkWell(
                onTap: () =>
                    Navigator.pop(context, TableBookingStatus.cancelled),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: AppColors.error, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cancel',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cancel this booking',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    if (selectedStatus != null && mounted) {
      await _updateStatus(selectedStatus);
    }
  }
}
