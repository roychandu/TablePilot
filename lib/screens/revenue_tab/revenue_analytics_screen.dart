// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/reservation_model.dart';
import '../../models/bill_model.dart';
import '../../models/table_booking_model.dart';
import '../../services/reservation_service.dart';
import '../../services/bill_service.dart';
import '../../services/table_booking_service.dart';
import 'package:intl/intl.dart';

class RevenueAnalyticsScreen extends StatefulWidget {
  const RevenueAnalyticsScreen({super.key});

  @override
  State<RevenueAnalyticsScreen> createState() => _RevenueAnalyticsScreenState();
}

class _RevenueAnalyticsScreenState extends State<RevenueAnalyticsScreen> {
  final ReservationService _eventService = ReservationService();
  final BillService _billService = BillService();
  final TableBookingService _tableBookingService = TableBookingService();

  String _selectedTimeframe = 'weekly'; // 'weekly', 'monthly', 'yearly'
  List<BillModel>? _cachedBills;
  Future<List<BillModel>>? _billsFuture;
  List<ReservationModel>? _cachedEvents;
  List<TableBookingModel>? _cachedTableBookings;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // Load bills once on initialization
    _billsFuture = _billService.getAllBills();
    _billsFuture!.then((bills) {
      if (mounted) {
        setState(() {
          _cachedBills = bills;
        });
      }
    });
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
          'Revenue Analytics',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ReservationModel>>(
          stream: _eventService.getReservationsStream(),
          builder: (context, eventsSnapshot) {
            // Cache events for export
            if (eventsSnapshot.hasData) {
              _cachedEvents = eventsSnapshot.data;
            }
            // Only show loading on initial load when we don't have cached data
            if (_cachedBills == null && _billsFuture != null) {
              return FutureBuilder<List<BillModel>>(
                future: _billsFuture,
                builder: (context, billsSnapshot) {
                  if (billsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    );
                  }
                  final bills = billsSnapshot.data ?? [];
                  if (mounted) {
                    _cachedBills = bills;
                  }
                  return _buildContent(
                    eventsSnapshot.data ?? [],
                    bills,
                    screenWidth,
                    horizontalPadding,
                    verticalSpacing,
                  );
                },
              );
            }

            // Use cached bills if available, otherwise empty list
            final bills = _cachedBills ?? [];

            // Only show loading if events are loading and we have no data
            if (eventsSnapshot.connectionState == ConnectionState.waiting &&
                !eventsSnapshot.hasData &&
                bills.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }

            return _buildContent(
              eventsSnapshot.data ?? [],
              bills,
              screenWidth,
              horizontalPadding,
              verticalSpacing,
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    List<ReservationModel> events,
    List<BillModel> bills,
    double screenWidth,
    double horizontalPadding,
    double verticalSpacing,
  ) {
    // Load table bookings if not cached
    if (_cachedTableBookings == null) {
      _tableBookingService.getTableBookings().then((tableBookings) {
        if (mounted) {
          setState(() {
            _cachedTableBookings = tableBookings;
          });
        }
      });
    }
    final tableBookings = _cachedTableBookings ?? [];

    final revenueData = _calculateRevenueData(events, bills, tableBookings);
    final dailyBreakdown = _calculateDailyBreakdown(
      events,
      bills,
      tableBookings,
    );
    final performanceInsights = _calculatePerformanceInsights(
      events,
      bills,
      tableBookings,
      dailyBreakdown,
    );

    return RefreshIndicator(
      onRefresh: () async {
        // Reload bills and table bookings on refresh
        final refreshedBills = await _billService.getAllBills();
        final refreshedTableBookings = await _tableBookingService
            .getTableBookings();
        if (mounted) {
          setState(() {
            _cachedBills = refreshedBills;
            _cachedTableBookings = refreshedTableBookings;
          });
        }
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalSpacing,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Timeframe Buttons
            _buildHeaderWithTimeframe(screenWidth),
            SizedBox(height: verticalSpacing),
            // Key Metrics Cards
            _buildKeyMetricsCards(revenueData, screenWidth),
            SizedBox(height: verticalSpacing * 0.5),
            _buildKeyMetricsCardsBottom(revenueData, screenWidth),
            SizedBox(height: verticalSpacing),
            // Revenue Distribution
            _buildRevenueDistribution(revenueData, screenWidth),
            SizedBox(height: verticalSpacing),
            // Daily Breakdown
            _buildDailyBreakdown(dailyBreakdown, screenWidth),
            SizedBox(height: verticalSpacing),
            // Performance Insights
            _buildPerformanceInsights(performanceInsights, screenWidth),
            SizedBox(height: verticalSpacing),
            // Export Revenue Report
            _buildExportSection(screenWidth, revenueData),
            SizedBox(height: verticalSpacing),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithTimeframe(double screenWidth) {
    final isTablet = screenWidth > 600;
    final buttonHeight = isTablet ? 40.0 : 36.0;
    final fontSize = isTablet ? 15.0 : 14.0;
    final horizontalPadding = isTablet ? 20.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTablet) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimeframeButton(
                    label: 'Weekly',
                    value: 'weekly',
                    height: buttonHeight,
                    fontSize: fontSize,
                    horizontalPadding: horizontalPadding,
                  ),
                  const SizedBox(width: 8),
                  _buildTimeframeButton(
                    label: 'Monthly',
                    value: 'monthly',
                    height: buttonHeight,
                    fontSize: fontSize,
                    horizontalPadding: horizontalPadding,
                  ),
                  const SizedBox(width: 8),
                  _buildTimeframeButton(
                    label: 'Yearly',
                    value: 'yearly',
                    height: buttonHeight,
                    fontSize: fontSize,
                    horizontalPadding: horizontalPadding,
                  ),
                ],
              ),
            ],
          ],
        ),
        if (!isTablet) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTimeframeButton(
                  label: 'Weekly',
                  value: 'weekly',
                  height: buttonHeight,
                  fontSize: fontSize,
                  horizontalPadding: horizontalPadding,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimeframeButton(
                  label: 'Monthly',
                  value: 'monthly',
                  height: buttonHeight,
                  fontSize: fontSize,
                  horizontalPadding: horizontalPadding,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimeframeButton(
                  label: 'Yearly',
                  value: 'yearly',
                  height: buttonHeight,
                  fontSize: fontSize,
                  horizontalPadding: horizontalPadding,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimeframeButton({
    required String label,
    required String value,
    required double height,
    required double fontSize,
    required double horizontalPadding,
  }) {
    final isSelected = _selectedTimeframe == value;

    return InkWell(
      onTap: () => setState(() => _selectedTimeframe = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.cardBackground.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? AppColors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyMetricsCards(
    Map<String, dynamic> revenueData,
    double screenWidth,
  ) {
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenWidth < 360;
    final spacing = isTablet
        ? 16.0
        : isSmallScreen
        ? 8.0
        : 12.0;
    final cardHeight = isTablet
        ? 140.0
        : isSmallScreen
        ? 110.0
        : 120.0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: CupertinoIcons.money_dollar_circle_fill,
            iconColor: AppColors.success,
            label: 'Total Revenue',
            value: 'AED ${_formatNumber(revenueData['totalRevenue'])}',
            valueColor: AppColors.success,
            height: cardHeight,
            screenWidth: screenWidth,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.table_restaurant,
            iconColor: AppColors.primary,
            label: 'Table Booking',
            value:
                'AED ${_formatNumber(revenueData['tableBookingRevenue'] ?? 0.0)}',
            valueColor: AppColors.primary,
            height: cardHeight,
            screenWidth: screenWidth,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyMetricsCardsBottom(
    Map<String, dynamic> revenueData,
    double screenWidth,
  ) {
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenWidth < 360;
    final spacing = isTablet
        ? 16.0
        : isSmallScreen
        ? 8.0
        : 12.0;
    final cardHeight = isTablet
        ? 140.0
        : isSmallScreen
        ? 110.0
        : 120.0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: CupertinoIcons.calendar,
            iconColor: AppColors.warning,
            label: 'Reservation Bookings',
            value:
                'AED ${_formatNumber(revenueData['reservationRevenue'] ?? 0.0)}',
            valueColor: AppColors.warning,
            height: cardHeight,
            screenWidth: screenWidth,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.trending_up,
            iconColor: AppColors.success,
            label: 'Growth Rate',
            value: '${revenueData['growthRate'].toStringAsFixed(1)}%',
            valueColor: AppColors.success,
            height: cardHeight,
            screenWidth: screenWidth,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required double height,
    required double screenWidth,
  }) {
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenWidth < 360;
    final padding = isTablet
        ? const EdgeInsets.all(20)
        : isSmallScreen
        ? const EdgeInsets.all(12)
        : const EdgeInsets.all(16);
    final iconSize = isTablet
        ? 24.0
        : isSmallScreen
        ? 18.0
        : 20.0;
    final iconContainerSize = isTablet
        ? 40.0
        : isSmallScreen
        ? 32.0
        : 36.0;

    // Responsive font sizes based on screen width
    double valueFontSize;
    double labelFontSize;

    if (isTablet) {
      valueFontSize = 24.0;
      labelFontSize = 12.0;
    } else if (isSmallScreen) {
      valueFontSize = 18.0;
      labelFontSize = 10.0;
    } else {
      valueFontSize = 22.0;
      labelFontSize = 11.0;
    }

    return Container(
      height: height,
      padding: padding,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
          const Spacer(),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTextStyles.h4.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                  fontSize: valueFontSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: labelFontSize,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueDistribution(
    Map<String, dynamic> revenueData,
    double screenWidth,
  ) {
    final totalRevenue = revenueData['totalRevenue'] as double;
    final reservationRevenue =
        revenueData['reservationRevenue'] as double? ?? 0.0;
    final tableBookingRevenue =
        revenueData['tableBookingRevenue'] as double? ?? 0.0;

    final reservationPercentage = totalRevenue > 0
        ? (reservationRevenue / totalRevenue * 100)
        : 0.0;
    final tableBookingPercentage = totalRevenue > 0
        ? (tableBookingRevenue / totalRevenue * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Distribution',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // Reservation Bookings
          _buildDistributionItem(
            label: 'Reservation Bookings',
            value: reservationRevenue,
            percentage: reservationPercentage,
            color: AppColors.warning,
            screenWidth: screenWidth,
          ),
          const SizedBox(height: 20),
          // Table Bookings
          _buildDistributionItem(
            label: 'Table Bookings',
            value: tableBookingRevenue,
            percentage: tableBookingPercentage,
            color: AppColors.primary,
            screenWidth: screenWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionItem({
    required String label,
    required double value,
    required double percentage,
    required Color color,
    required double screenWidth,
  }) {
    final isTablet = screenWidth > 600;
    final fontSize = isTablet ? 15.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: fontSize,
              ),
            ),
            Text(
              'AED ${_formatNumber(value)} (${percentage.toStringAsFixed(1)}%)',
              style: AppTextStyles.bodyMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 10,
            backgroundColor: AppColors.border.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyBreakdown(
    List<Map<String, dynamic>> dailyBreakdown,
    double screenWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Breakdown',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...dailyBreakdown.map(
          (day) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildDailyItem(day, screenWidth),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyItem(Map<String, dynamic> day, double screenWidth) {
    final total = day['total'] as double;
    final reservations =
        day['reservations'] as double? ?? day['events'] as double? ?? 0.0;
    final tableBookings = day['tableBookings'] as double? ?? 0.0;
    final dayName = day['day'] as String;

    final totalRevenue = reservations + tableBookings;
    final reservationsPercentage = totalRevenue > 0
        ? (reservations / totalRevenue * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'AED ${_formatNumberWithCommas(total)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reservations: AED ${_formatNumberWithCommas(reservations)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Tables: AED ${_formatNumberWithCommas(tableBookings)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar with text inside
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final reservationsWidth =
                  (reservationsPercentage / 100) * barWidth;

              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 32,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Background
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.border.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      // Reservation Bookings segment
                      if (reservations > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: reservationsWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius:
                                  reservations > 0 && tableBookings > 0
                                  ? const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                    )
                                  : BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Reservations: AED ${_formatNumberWithCommas(reservations)}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Table Bookings segment
                      if (tableBookings > 0)
                        Positioned(
                          left: reservationsWidth,
                          top: 0,
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                                  reservations > 0 && tableBookings > 0
                                  ? const BorderRadius.only(
                                      topRight: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    )
                                  : BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Tables: AED ${_formatNumberWithCommas(tableBookings)}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceInsights(
    Map<String, dynamic> insights,
    double screenWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Insights',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          icon: Icons.calendar_today,
          iconColor: AppColors.success,
          label: 'Best Performing Day',
          value: insights['bestDay'] as String,
          value2: 'AED ${_formatNumber(insights['bestDayRevenue'] as double)}',
          screenWidth: screenWidth,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: CupertinoIcons.chart_bar_alt_fill,
          iconColor: AppColors.info,
          label: 'Average per Day',
          value: 'AED ${_formatNumber(insights['averagePerDay'] as double)}',
          screenWidth: screenWidth,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: CupertinoIcons.arrow_up_right,
          iconColor: AppColors.warning,
          label: 'Growth vs Previous Period',
          value: '+${insights['growthRate'].toStringAsFixed(1)}%',
          valueColor: AppColors.success,
          screenWidth: screenWidth,
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? value2,
    Color? valueColor,
    required double screenWidth,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: AppColors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (value2 != null)
                Text(
                  value2,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection(
    double screenWidth,
    Map<String, dynamic> revenueData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Export Revenue Report',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildExportDropdown(),
              const SizedBox(height: 16),
              _buildExportButton(
                screenWidth,
                hasRevenue:
                    (revenueData['totalRevenue'] as double? ?? 0.0) > 0.0,
              ),
              if ((revenueData['totalRevenue'] as double? ?? 0.0) <= 0.0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'No revenue data available for the selected period to export.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _selectedExportFormat = 'CSV Format';

  Widget _buildExportDropdown() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.cardBackground,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildExportFormatOption('CSV Format'),
                _buildExportFormatOption('Excel Format'),
                _buildExportFormatOption('PDF Format'),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedExportFormat,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportFormatOption(String format) {
    final isSelected = _selectedExportFormat == format;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedExportFormat = format;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              format,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(double screenWidth, {required bool hasRevenue}) {
    final isTablet = screenWidth > 600;
    final buttonHeight = isTablet ? 56.0 : 48.0;

    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton.icon(
        onPressed: _isExporting || !hasRevenue ? null : _exportRevenueReport,
        icon: _isExporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : const Icon(Icons.download, color: AppColors.white),
        label: Text(
          _isExporting
              ? 'Exporting...'
              : 'Export ${_selectedTimeframe == 'weekly'
                    ? 'Weekly'
                    : _selectedTimeframe == 'monthly'
                    ? 'Monthly'
                    : 'Yearly'} Report',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _exportRevenueReport() async {
    try {
      if (_cachedEvents == null ||
          _cachedBills == null ||
          _cachedTableBookings == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for data to load'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() {
        _isExporting = true;
      });

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );

      // Get save directory
      final directory = await _getSaveDirectory();
      if (directory == null) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to access storage. Please grant permissions.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Generate filename
      final fileName = _generateReportFileName();
      final filePath = '${directory.path}/$fileName';

      debugPrint('[Revenue Export] Saving report to: $filePath');

      // Generate and save file based on selected format
      final file = File(filePath);
      if (_selectedExportFormat == 'PDF Format') {
        final pdf = await _generateRevenuePDF();
        final pdfBytes = await pdf.save();
        await file.writeAsBytes(pdfBytes);
        debugPrint(
          '[Revenue Export] PDF saved successfully. File size: ${pdfBytes.length} bytes',
        );
      } else if (_selectedExportFormat == 'CSV Format') {
        final csvContent = await _generateRevenueCSV();
        await file.writeAsString(csvContent);
        debugPrint(
          '[Revenue Export] CSV saved successfully. File size: ${csvContent.length} bytes',
        );
      } else if (_selectedExportFormat == 'Excel Format') {
        // Excel format - generate CSV that Excel can open
        final csvContent = await _generateRevenueCSV();
        await file.writeAsString(csvContent);
        debugPrint(
          '[Revenue Export] Excel (CSV) saved successfully. File size: ${csvContent.length} bytes',
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close loading

        // Show success message with file path
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Revenue report saved successfully!'),
                Text('File: $fileName', style: const TextStyle(fontSize: 12)),
                Text(
                  'Location: ${directory.path}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Share',
              textColor: AppColors.white,
              onPressed: () => _shareReport(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      debugPrint('Error in _exportRevenueReport: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<pw.Document> _generateRevenuePDF() async {
    final pdf = pw.Document();
    final events = _cachedEvents ?? [];
    final bills = _cachedBills ?? [];
    final tableBookings = _cachedTableBookings ?? [];

    final revenueData = _calculateRevenueData(events, bills, tableBookings);
    final dailyBreakdown = _calculateDailyBreakdown(
      events,
      bills,
      tableBookings,
    );
    final performanceInsights = _calculatePerformanceInsights(
      events,
      bills,
      tableBookings,
      dailyBreakdown,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            _buildPDFHeader(),
            pw.SizedBox(height: 20),
            // Key Metrics
            _buildPDFKeyMetrics(revenueData),
            pw.SizedBox(height: 20),
            // Revenue Distribution
            _buildPDFRevenueDistribution(revenueData),
            pw.SizedBox(height: 20),
            // Daily Breakdown
            _buildPDFDailyBreakdown(dailyBreakdown),
            pw.SizedBox(height: 20),
            // Performance Insights
            _buildPDFPerformanceInsights(performanceInsights),
            pw.SizedBox(height: 20),
            // Footer
            _buildPDFFooter(),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPDFHeader() {
    final timeframeName = _selectedTimeframe == 'weekly'
        ? 'Weekly'
        : _selectedTimeframe == 'monthly'
        ? 'Monthly'
        : 'Yearly';
    final now = DateTime.now();
    final dateRange = _getDateRangeText();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'Revenue Analytics Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '$timeframeName Report',
          style: const pw.TextStyle(fontSize: 16),
        ),
        pw.SizedBox(height: 4),
        pw.Text(dateRange, style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generated: ${DateFormat('MMM dd, yyyy • hh:mm a').format(now)}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  String _getDateRangeText() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_selectedTimeframe) {
      case 'weekly':
        final daysFromMonday = now.weekday - 1;
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysFromMonday));
        endDate = now;
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      default:
        final daysFromMonday = now.weekday - 1;
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysFromMonday));
        endDate = now;
    }

    return '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}';
  }

  pw.Widget _buildPDFKeyMetrics(Map<String, dynamic> revenueData) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Key Metrics',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          _buildPDFMetricRow('Total Revenue', revenueData['totalRevenue']),
          pw.SizedBox(height: 6),
          _buildPDFMetricRow(
            'Reservation Bookings Revenue',
            revenueData['reservationRevenue'] ?? 0.0,
          ),
          pw.SizedBox(height: 6),
          _buildPDFMetricRow(
            'Growth Rate',
            revenueData['growthRate'],
            isPercentage: true,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFMetricRow(
    String label,
    double value, {
    bool isPercentage = false,
  }) {
    final displayValue = isPercentage
        ? '${value.toStringAsFixed(1)}%'
        : 'AED ${_formatNumberForPDF(value)}';
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
        pw.Text(
          displayValue,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildPDFRevenueDistribution(Map<String, dynamic> revenueData) {
    final totalRevenue = revenueData['totalRevenue'] as double;
    final reservationRevenue =
        revenueData['reservationRevenue'] as double? ?? 0.0;
    final tableBookingRevenue =
        revenueData['tableBookingRevenue'] as double? ?? 0.0;

    final reservationPercentage = totalRevenue > 0
        ? (reservationRevenue / totalRevenue * 100)
        : 0.0;
    final tableBookingPercentage = totalRevenue > 0
        ? (tableBookingRevenue / totalRevenue * 100)
        : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Revenue Distribution',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          _buildPDFDistributionRow(
            'Reservation Bookings',
            reservationRevenue,
            reservationPercentage,
          ),
          pw.SizedBox(height: 8),
          _buildPDFDistributionRow(
            'Table Bookings',
            tableBookingRevenue,
            tableBookingPercentage,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFDistributionRow(
    String label,
    double value,
    double percentage,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
            pw.Text(
              'AED ${_formatNumberForPDF(value)} (${percentage.toStringAsFixed(1)}%)',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Expanded(
              flex: (percentage * 100).toInt().clamp(0, 10000),
              child: pw.Container(
                height: 8,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
            ),
            pw.Expanded(
              flex: ((100 - percentage) * 100).toInt().clamp(0, 10000),
              child: pw.Container(
                height: 8,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFDailyBreakdown(List<Map<String, dynamic>> dailyBreakdown) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Daily Breakdown',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          ...dailyBreakdown.map((day) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    day['day'] as String,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    'AED ${_formatNumberForPDF(day['total'] as double)}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
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

  pw.Widget _buildPDFPerformanceInsights(Map<String, dynamic> insights) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Performance Insights',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          _buildPDFInsightRow(
            'Best Performing Day',
            insights['bestDay'] as String,
            'AED ${_formatNumberForPDF(insights['bestDayRevenue'] as double)}',
          ),
          pw.SizedBox(height: 6),
          _buildPDFInsightRow(
            'Average per Day',
            'AED ${_formatNumberForPDF(insights['averagePerDay'] as double)}',
            null,
          ),
          pw.SizedBox(height: 6),
          _buildPDFInsightRow(
            'Growth vs Previous Period',
            '+${insights['growthRate'].toStringAsFixed(1)}%',
            null,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFInsightRow(String label, String value, String? value2) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (value2 != null)
              pw.Text(value2, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        children: [
          pw.Text(
            'This is a computer-generated revenue report.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _formatNumberForPDF(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return NumberFormat('#,##0').format(number);
  }

  String _formatNumberForCSV(double number) {
    // Format number with commas for CSV
    return NumberFormat('#,##0.00').format(number);
  }

  String _generateReportFileName() {
    final timeframeName = _selectedTimeframe == 'weekly'
        ? 'Weekly'
        : _selectedTimeframe == 'monthly'
        ? 'Monthly'
        : 'Yearly';
    final date = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    String extension;
    if (_selectedExportFormat == 'PDF Format') {
      extension = 'pdf';
    } else if (_selectedExportFormat == 'CSV Format') {
      extension = 'csv';
    } else if (_selectedExportFormat == 'Excel Format') {
      extension = 'csv'; // CSV format that Excel can open
    } else {
      extension = 'pdf';
    }

    return 'RevenueReport_${timeframeName}_$date.$extension';
  }

  Future<String> _generateRevenueCSV() async {
    final events = _cachedEvents ?? [];
    final bills = _cachedBills ?? [];
    final tableBookings = _cachedTableBookings ?? [];

    final revenueData = _calculateRevenueData(events, bills, tableBookings);
    final dailyBreakdown = _calculateDailyBreakdown(
      events,
      bills,
      tableBookings,
    );
    final performanceInsights = _calculatePerformanceInsights(
      events,
      bills,
      tableBookings,
      dailyBreakdown,
    );

    final StringBuffer csv = StringBuffer();
    final timeframeName = _selectedTimeframe == 'weekly'
        ? 'Weekly'
        : _selectedTimeframe == 'monthly'
        ? 'Monthly'
        : 'Yearly';
    final dateRange = _getDateRangeText();
    final now = DateTime.now();

    // Header
    csv.writeln('Revenue Analytics Report');
    csv.writeln('$timeframeName Report');
    csv.writeln('Date Range: $dateRange');
    csv.writeln(
      'Generated: ${DateFormat('MMM dd, yyyy • hh:mm a').format(now)}',
    );
    csv.writeln(''); // Empty line

    // Key Metrics
    csv.writeln('Key Metrics');
    csv.writeln('Metric,Value');
    csv.writeln(
      'Total Revenue,AED ${_formatNumberForCSV(revenueData['totalRevenue'])}',
    );
    csv.writeln(
      'Reservation Bookings Revenue,AED ${_formatNumberForCSV(revenueData['reservationRevenue'] ?? 0.0)}',
    );
    csv.writeln(
      'Table Bookings Revenue,AED ${_formatNumberForCSV(revenueData['tableBookingRevenue'] ?? 0.0)}',
    );
    csv.writeln('Growth Rate,${revenueData['growthRate'].toStringAsFixed(1)}%');
    csv.writeln(''); // Empty line

    // Revenue Distribution
    final totalRevenue = revenueData['totalRevenue'] as double;
    final reservationRevenue =
        revenueData['reservationRevenue'] as double? ?? 0.0;
    final tableBookingRevenue =
        revenueData['tableBookingRevenue'] as double? ?? 0.0;
    final reservationPercentage = totalRevenue > 0
        ? (reservationRevenue / totalRevenue * 100)
        : 0.0;
    final tableBookingPercentage = totalRevenue > 0
        ? (tableBookingRevenue / totalRevenue * 100)
        : 0.0;

    csv.writeln('Revenue Distribution');
    csv.writeln('Category,Amount,Percentage');
    csv.writeln(
      'Reservation Bookings,AED ${_formatNumberForCSV(reservationRevenue)},${reservationPercentage.toStringAsFixed(1)}%',
    );
    csv.writeln(
      'Table Bookings,AED ${_formatNumberForCSV(tableBookingRevenue)},${tableBookingPercentage.toStringAsFixed(1)}%',
    );
    csv.writeln(''); // Empty line

    // Daily Breakdown
    csv.writeln('Daily Breakdown');
    csv.writeln(
      'Day/Date,Reservation Bookings Revenue,Table Bookings Revenue,Total Revenue',
    );
    for (final day in dailyBreakdown) {
      final dayName = day['day'] as String;
      final reservations =
          day['reservations'] as double? ?? day['events'] as double? ?? 0.0;
      final tableBookings = day['tableBookings'] as double? ?? 0.0;
      final total = day['total'] as double;
      csv.writeln(
        '$dayName,AED ${_formatNumberForCSV(reservations)},AED ${_formatNumberForCSV(tableBookings)},AED ${_formatNumberForCSV(total)}',
      );
    }
    csv.writeln(''); // Empty line

    // Performance Insights
    csv.writeln('Performance Insights');
    csv.writeln('Metric,Value');
    csv.writeln('Best Performing Day,${performanceInsights['bestDay']}');
    csv.writeln(
      'Best Day Revenue,AED ${_formatNumberForCSV(performanceInsights['bestDayRevenue'])}',
    );
    csv.writeln(
      'Average per Day,AED ${_formatNumberForCSV(performanceInsights['averagePerDay'])}',
    );
    csv.writeln(
      'Growth vs Previous Period,+${performanceInsights['growthRate'].toStringAsFixed(1)}%',
    );

    return csv.toString();
  }

  Future<Directory?> _getSaveDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Request storage permission
        final permissionStatus = await _requestStoragePermission();
        if (!permissionStatus) {
          debugPrint(
            '[Revenue Export] Storage permission denied - using app documents',
          );
          return await getApplicationDocumentsDirectory();
        }

        // Primary: Try public Downloads folder
        Directory? directory = await _tryDownloadsFolder();
        if (directory != null) {
          debugPrint(
            '[Revenue Export] Using Downloads folder: ${directory.path}',
          );
          return directory;
        }

        // Fallback: Create custom app folder in external storage
        directory = await _tryCustomAppFolder();
        if (directory != null) {
          debugPrint(
            '[Revenue Export] Using custom app folder: ${directory.path}',
          );
          return directory;
        }

        // Final fallback: App documents directory
        debugPrint(
          '[Revenue Export] Using app documents directory as final fallback',
        );
        return await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        // iOS: Use app documents directory
        debugPrint(
          '[Revenue Export] iOS platform - using app documents directory',
        );
        return await getApplicationDocumentsDirectory();
      } else {
        // Other platforms: Use app documents directory
        debugPrint(
          '[Revenue Export] Other platform - using app documents directory',
        );
        return await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      debugPrint('[Revenue Export] Error in _getSaveDirectory: $e');
      // Final fallback
      try {
        return await getApplicationDocumentsDirectory();
      } catch (fallbackError) {
        debugPrint(
          '[Revenue Export] Error getting app documents directory: $fallbackError',
        );
        return null;
      }
    }
  }

  /// Try to access the public Downloads folder
  Future<Directory?> _tryDownloadsFolder() async {
    try {
      // Primary path: Standard Android Downloads folder
      Directory directory = Directory('/storage/emulated/0/Download');

      if (await directory.exists()) {
        debugPrint(
          '[Revenue Export] Downloads folder exists: ${directory.path}',
        );
        return directory;
      }

      // Try to create if it doesn't exist
      try {
        await directory.create(recursive: true);
        debugPrint(
          '[Revenue Export] Created Downloads folder: ${directory.path}',
        );
        return directory;
      } catch (createError) {
        debugPrint(
          '[Revenue Export] Could not create Downloads folder: $createError',
        );
      }

      // Alternative path: Some devices use /sdcard/Download
      directory = Directory('/sdcard/Download');
      if (await directory.exists()) {
        debugPrint(
          '[Revenue Export] Using alternative Downloads path: ${directory.path}',
        );
        return directory;
      }

      // Try to create alternative path
      try {
        await directory.create(recursive: true);
        debugPrint(
          '[Revenue Export] Created alternative Downloads folder: ${directory.path}',
        );
        return directory;
      } catch (createError) {
        debugPrint(
          '[Revenue Export] Could not create alternative Downloads folder: $createError',
        );
      }

      return null;
    } catch (e) {
      debugPrint('[Revenue Export] Error accessing Downloads folder: $e');
      return null;
    }
  }

  /// Try to create custom app folder as fallback
  Future<Directory?> _tryCustomAppFolder() async {
    try {
      // Create custom app folder: /storage/emulated/0/Cafe Management/Download/
      Directory baseDir = Directory('/storage/emulated/0/Cafe Management');
      Directory appFolder = Directory('${baseDir.path}/Download');

      // Try to create the folder structure
      try {
        if (!await appFolder.exists()) {
          await appFolder.create(recursive: true);
          debugPrint(
            '[Revenue Export] Created custom app folder: ${appFolder.path}',
          );
        } else {
          debugPrint(
            '[Revenue Export] Custom app folder already exists: ${appFolder.path}',
          );
        }
        return appFolder;
      } catch (createError) {
        debugPrint(
          '[Revenue Export] Could not create custom app folder: $createError',
        );

        // Try alternative base path
        try {
          baseDir = Directory('/sdcard/Cafe Management P261');
          appFolder = Directory('${baseDir.path}/Download');
          if (!await appFolder.exists()) {
            await appFolder.create(recursive: true);
            debugPrint(
              '[Revenue Export] Created custom app folder (alternative): ${appFolder.path}',
            );
          }
          return appFolder;
        } catch (altError) {
          debugPrint(
            '[Revenue Export] Could not create alternative custom app folder: $altError',
          );
          return null;
        }
      }
    } catch (e) {
      debugPrint('[Revenue Export] Error creating custom app folder: $e');
      return null;
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) {
      debugPrint(
        '[Revenue Export] Not Android platform - permissions not needed',
      );
      return true;
    }

    try {
      debugPrint('[Revenue Export] Requesting storage permissions...');

      // Check if we're on Android 11+ (API 30+)
      final isAndroid11Plus = await _isAndroid11OrAbove();
      debugPrint('[Revenue Export] Android 11+: $isAndroid11Plus');

      if (isAndroid11Plus) {
        // Android 11+ (API 30+) - Scoped Storage
        // Try MANAGE_EXTERNAL_STORAGE first (for full access)
        try {
          final manageStatus = await Permission.manageExternalStorage.status;
          debugPrint(
            '[Revenue Export] MANAGE_EXTERNAL_STORAGE status: $manageStatus',
          );

          if (manageStatus.isGranted) {
            debugPrint(
              '[Revenue Export] MANAGE_EXTERNAL_STORAGE already granted',
            );
            return true;
          }

          // Request MANAGE_EXTERNAL_STORAGE
          final manageResult = await Permission.manageExternalStorage.request();
          debugPrint(
            '[Revenue Export] MANAGE_EXTERNAL_STORAGE request result: $manageResult',
          );

          if (manageResult.isGranted) {
            debugPrint('[Revenue Export] MANAGE_EXTERNAL_STORAGE granted');
            return true;
          }

          // Fallback: Try WRITE_EXTERNAL_STORAGE (for scoped storage access)
          debugPrint(
            '[Revenue Export] Trying WRITE_EXTERNAL_STORAGE as fallback',
          );
          final writeStatus = await Permission.storage.status;
          debugPrint(
            '[Revenue Export] WRITE_EXTERNAL_STORAGE status: $writeStatus',
          );

          if (writeStatus.isGranted) {
            debugPrint(
              '[Revenue Export] WRITE_EXTERNAL_STORAGE already granted',
            );
            return true;
          }

          final writeResult = await Permission.storage.request();
          debugPrint(
            '[Revenue Export] WRITE_EXTERNAL_STORAGE request result: $writeResult',
          );

          if (writeResult.isGranted) {
            debugPrint('[Revenue Export] WRITE_EXTERNAL_STORAGE granted');
            return true;
          }

          debugPrint('[Revenue Export] All storage permissions denied');
          return false;
        } catch (manageError) {
          debugPrint(
            '[Revenue Export] Error with MANAGE_EXTERNAL_STORAGE: $manageError',
          );
          // Fall through to try storage permission
        }
      }

      // Android 10 and below (API < 30) - Legacy Storage
      debugPrint('[Revenue Export] Using legacy storage permissions');
      final storageStatus = await Permission.storage.status;
      debugPrint('[Revenue Export] Storage permission status: $storageStatus');

      if (storageStatus.isGranted) {
        debugPrint('[Revenue Export] Storage permission already granted');
        return true;
      }

      final storageResult = await Permission.storage.request();
      debugPrint(
        '[Revenue Export] Storage permission request result: $storageResult',
      );

      if (storageResult.isGranted) {
        debugPrint('[Revenue Export] Storage permission granted');
        return true;
      }

      debugPrint('[Revenue Export] Storage permission denied');
      return false;
    } catch (e) {
      debugPrint('[Revenue Export] Error requesting storage permission: $e');
      return false;
    }
  }

  Future<bool> _isAndroid11OrAbove() async {
    if (!Platform.isAndroid) return false;

    try {
      // Use platform channel to get Android version
      // For now, we'll use a heuristic: try to request manageExternalStorage
      // If it's available, we're likely on Android 11+
      try {
        await Permission.manageExternalStorage.status;
        // If we can check the status, the permission exists (Android 11+)
        debugPrint(
          '[Revenue Export] manageExternalStorage available - Android 11+',
        );
        return true;
      } catch (e) {
        // If manageExternalStorage doesn't exist, we're on Android 10 or below
        debugPrint(
          '[Revenue Export] manageExternalStorage not available, likely Android 10 or below: $e',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[Revenue Export] Error checking Android version: $e');
      // Default to assuming Android 11+ for safety
      return true;
    }
  }

  Future<void> _shareReport(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File not found'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        text:
            'Revenue Report - ${_selectedTimeframe == 'weekly'
                ? 'Weekly'
                : _selectedTimeframe == 'monthly'
                ? 'Monthly'
                : 'Yearly'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      debugPrint('Error in _shareReport: $e');
    }
  }

  // Calculate revenue data based on timeframe
  Map<String, dynamic> _calculateRevenueData(
    List<ReservationModel> events,
    List<BillModel> bills,
    List<TableBookingModel> tableBookings,
  ) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_selectedTimeframe) {
      case 'weekly':
        final daysFromMonday = now.weekday - 1;
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysFromMonday));
        endDate = now;
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      default:
        final daysFromMonday = now.weekday - 1;
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysFromMonday));
        endDate = now;
    }

    // Filter events
    final filteredEvents = events.where((event) {
      final eventDateTime = DateTime(
        event.reservationDate.year,
        event.reservationDate.month,
        event.reservationDate.day,
      );
      final startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final endDateTime = DateTime(endDate.year, endDate.month, endDate.day);
      return event.status != ReservationStatus.cancelled &&
          (eventDateTime.isAtSameMomentAs(startDateTime) ||
              (eventDateTime.isAfter(startDateTime) &&
                  eventDateTime.isBefore(
                    endDateTime.add(const Duration(days: 1)),
                  )));
    }).toList();

    // Calculate reservation revenues
    double reservationRevenue = 0.0;
    for (final event in filteredEvents) {
      reservationRevenue += event.estimatedTotalCost > 0
          ? event.estimatedTotalCost
          : event.totalCost;
    }

    // Filter and calculate table booking revenue
    final filteredTableBookings = tableBookings.where((booking) {
      final bookingDateTime = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
      );
      final startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final endDateTime = DateTime(endDate.year, endDate.month, endDate.day);
      return booking.status != TableBookingStatus.cancelled &&
          (bookingDateTime.isAtSameMomentAs(startDateTime) ||
              (bookingDateTime.isAfter(startDateTime) &&
                  bookingDateTime.isBefore(
                    endDateTime.add(const Duration(days: 1)),
                  )));
    }).toList();

    double tableBookingRevenue = 0.0;
    for (final booking in filteredTableBookings) {
      // Calculate revenue from menu items
      double subtotal = 0.0;
      for (final item in booking.menuItems) {
        subtotal += item.totalPrice;
      }
      // Add service charge (10%)
      double serviceCharge = subtotal * 0.1;
      tableBookingRevenue += subtotal + serviceCharge;
    }

    final totalRevenue = reservationRevenue + tableBookingRevenue;

    // Calculate growth rate (compare with previous period)
    final previousStartDate = startDate.subtract(
      Duration(
        days: _selectedTimeframe == 'weekly'
            ? 7
            : _selectedTimeframe == 'monthly'
            ? 30
            : 365,
      ),
    );

    double previousReservationRevenue = 0.0;
    for (final event in events) {
      final eventDate = DateTime(
        event.reservationDate.year,
        event.reservationDate.month,
        event.reservationDate.day,
      );
      if (eventDate.isAfter(
            previousStartDate.subtract(const Duration(days: 1)),
          ) &&
          eventDate.isBefore(startDate.add(const Duration(days: 1))) &&
          event.status != ReservationStatus.cancelled) {
        previousReservationRevenue += event.estimatedTotalCost > 0
            ? event.estimatedTotalCost
            : event.totalCost;
      }
    }

    double previousTableBookingRevenue = 0.0;
    for (final booking in tableBookings) {
      final bookingDate = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
      );
      if (bookingDate.isAfter(
            previousStartDate.subtract(const Duration(days: 1)),
          ) &&
          bookingDate.isBefore(startDate.add(const Duration(days: 1))) &&
          booking.status != TableBookingStatus.cancelled) {
        double subtotal = 0.0;
        for (final item in booking.menuItems) {
          subtotal += item.totalPrice;
        }
        double serviceCharge = subtotal * 0.1;
        previousTableBookingRevenue += subtotal + serviceCharge;
      }
    }

    final previousTotalRevenue =
        previousReservationRevenue + previousTableBookingRevenue;
    final growthRate = previousTotalRevenue > 0
        ? ((totalRevenue - previousTotalRevenue) / previousTotalRevenue * 100)
        : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'reservationRevenue': reservationRevenue,
      'tableBookingRevenue': tableBookingRevenue,
      'growthRate': growthRate,
    };
  }

  // Calculate daily breakdown based on timeframe
  List<Map<String, dynamic>> _calculateDailyBreakdown(
    List<ReservationModel> events,
    List<BillModel> bills,
    List<TableBookingModel> tableBookings,
  ) {
    final now = DateTime.now();
    DateTime startDate;
    int daysToShow;

    switch (_selectedTimeframe) {
      case 'weekly':
        final daysFromMonday = now.weekday - 1;
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysFromMonday));
        daysToShow = 7;
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        // Get number of days from start of month to today (inclusive)
        final today = DateTime(now.year, now.month, now.day);
        daysToShow = today.difference(startDate).inDays + 1;
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        daysToShow = 12; // Show 12 months
        break;
      default:
        final daysFromMonday = now.weekday - 1;
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysFromMonday));
        daysToShow = 7;
    }

    final List<Map<String, dynamic>> breakdown = [];

    if (_selectedTimeframe == 'yearly') {
      // For yearly, show months
      for (int i = 0; i < 12; i++) {
        final monthDate = DateTime(now.year, i + 1, 1);
        final monthName = _getMonthName(i + 1);

        // Filter reservations for this month
        double reservationRevenue = 0.0;
        for (final event in events) {
          final eventDate = DateTime(
            event.reservationDate.year,
            event.reservationDate.month,
            event.reservationDate.day,
          );
          if (eventDate.year == monthDate.year &&
              eventDate.month == monthDate.month &&
              event.status != ReservationStatus.cancelled) {
            reservationRevenue += event.estimatedTotalCost > 0
                ? event.estimatedTotalCost
                : event.totalCost;
          }
        }

        // Filter table bookings for this month
        double tableBookingRevenue = 0.0;
        for (final booking in tableBookings) {
          final bookingDate = DateTime(
            booking.bookingDate.year,
            booking.bookingDate.month,
            booking.bookingDate.day,
          );
          if (bookingDate.year == monthDate.year &&
              bookingDate.month == monthDate.month &&
              booking.status != TableBookingStatus.cancelled) {
            double subtotal = 0.0;
            for (final item in booking.menuItems) {
              subtotal += item.totalPrice;
            }
            double serviceCharge = subtotal * 0.1;
            tableBookingRevenue += subtotal + serviceCharge;
          }
        }

        breakdown.add({
          'day': monthName,
          'reservations': reservationRevenue,
          'tableBookings': tableBookingRevenue,
          'total': reservationRevenue + tableBookingRevenue,
        });
      }
    } else {
      // For weekly and monthly, show days
      for (int i = 0; i < daysToShow; i++) {
        final dayDate = startDate.add(Duration(days: i));

        // Skip future dates for monthly view
        if (_selectedTimeframe == 'monthly') {
          final today = DateTime(now.year, now.month, now.day);
          if (dayDate.isAfter(today)) {
            continue; // Skip future days
          }
        }

        String dayName;

        if (_selectedTimeframe == 'weekly') {
          dayName = _getDayName(dayDate.weekday);
        } else {
          // Monthly: show day name and date
          dayName =
              '${_getDayName(dayDate.weekday)} ${dayDate.day}/${dayDate.month}';
        }

        // Filter reservations for this day
        double reservationRevenue = 0.0;
        for (final event in events) {
          final eventDate = DateTime(
            event.reservationDate.year,
            event.reservationDate.month,
            event.reservationDate.day,
          );
          if (eventDate.year == dayDate.year &&
              eventDate.month == dayDate.month &&
              eventDate.day == dayDate.day &&
              event.status != ReservationStatus.cancelled) {
            reservationRevenue += event.estimatedTotalCost > 0
                ? event.estimatedTotalCost
                : event.totalCost;
          }
        }

        // Filter table bookings for this day
        double tableBookingRevenue = 0.0;
        for (final booking in tableBookings) {
          final bookingDate = DateTime(
            booking.bookingDate.year,
            booking.bookingDate.month,
            booking.bookingDate.day,
          );
          if (bookingDate.year == dayDate.year &&
              bookingDate.month == dayDate.month &&
              bookingDate.day == dayDate.day &&
              booking.status != TableBookingStatus.cancelled) {
            double subtotal = 0.0;
            for (final item in booking.menuItems) {
              subtotal += item.totalPrice;
            }
            double serviceCharge = subtotal * 0.1;
            tableBookingRevenue += subtotal + serviceCharge;
          }
        }

        breakdown.add({
          'day': dayName,
          'reservations': reservationRevenue,
          'tableBookings': tableBookingRevenue,
          'total': reservationRevenue + tableBookingRevenue,
        });
      }
    }

    return breakdown;
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  // Calculate performance insights
  Map<String, dynamic> _calculatePerformanceInsights(
    List<ReservationModel> events,
    List<BillModel> bills,
    List<TableBookingModel> tableBookings,
    List<Map<String, dynamic>> dailyBreakdown,
  ) {
    // Find best performing day
    Map<String, dynamic> bestDay = dailyBreakdown.first;
    for (final day in dailyBreakdown) {
      if ((day['total'] as double) > (bestDay['total'] as double)) {
        bestDay = day;
      }
    }

    // Calculate average per day
    final totalRevenue = dailyBreakdown.fold<double>(
      0.0,
      (sum, day) => sum + (day['total'] as double),
    );
    final averagePerDay = dailyBreakdown.isNotEmpty
        ? totalRevenue / dailyBreakdown.length
        : 0.0;

    // Calculate growth rate (same as in revenue data)
    final revenueData = _calculateRevenueData(events, bills, tableBookings);
    final growthRate = revenueData['growthRate'] as double;

    return {
      'bestDay': bestDay['day'] as String,
      'bestDayRevenue': bestDay['total'] as double,
      'averagePerDay': averagePerDay,
      'growthRate': growthRate,
    };
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return NumberFormat('#,##0').format(number);
  }

  String _formatNumberWithCommas(double number) {
    return NumberFormat('#,##0').format(number);
  }
}
