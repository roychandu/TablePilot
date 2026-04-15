import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/table_booking_model.dart';

class BillReceiptScreen extends StatelessWidget {
  final TableBookingModel booking;

  const BillReceiptScreen({super.key, required this.booking});

  String _formatDate(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _generateOrderNumber() {
    if (booking.id != null) {
      final dateStr = DateFormat('yyyyMMdd').format(booking.createdAt);
      final idStr = booking.id!.substring(0, 6);
      return 'ORD-$dateStr-$idStr';
    }
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final randomStr = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(7);
    return 'ORD-$dateStr-$randomStr';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? 24.0 : 16.0;

    // Calculate totals
    double subtotal = 0.0;
    for (final item in booking.menuItems) {
      subtotal += item.totalPrice;
    }
    const taxRate = 0.18; // 18% tax
    final tax = subtotal * taxRate;
    final total = subtotal + tax;

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
          'Bill Receipt',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Restaurant Information Card
            _buildRestaurantInfoCard(),
            const SizedBox(height: 20),
            // Order Information Card
            _buildOrderInfoCard(),
            const SizedBox(height: 20),
            // Order Items Card
            _buildOrderItemsCard(subtotal),
            const SizedBox(height: 20),
            // Bill Summary Card
            _buildBillSummaryCard(subtotal, tax, total),
            const SizedBox(height: 40),
            // Thank you message
            _buildThankYouMessage(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: AppColors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SFC Plus - Southern Fried Chicken',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.location,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Abu Dhabi, United Arab Emirates',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Order Information',
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: CupertinoIcons.number,
            label: 'Order Number',
            value: _generateOrderNumber(),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: CupertinoIcons.calendar,
            label: 'Date & Time',
            value:
                '${_formatDate(booking.bookingDate)} | ${_formatTime(booking.bookingTime)}',
          ),
          if (booking.tableNumber != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: CupertinoIcons.square_grid_2x2,
              label: 'Table',
              value: 'Table ${booking.tableNumber}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemsCard(double subtotal) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Order Items',
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (booking.menuItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No items ordered',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...booking.menuItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty: ${item.quantity} x ${item.priceAed.toStringAsFixed(2)} AED',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.totalPrice.toStringAsFixed(2)} AED',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBillSummaryCard(double subtotal, double tax, double total) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Bill Summary',
            style: AppTextStyles.h6.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal', subtotal),
          const SizedBox(height: 12),
          _buildSummaryRow('Tax (18%)', tax),
          const Divider(color: AppColors.border, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${total.toStringAsFixed(2)} AED',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} AED',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildThankYouMessage() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Text(
            'Thank you for your order!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
