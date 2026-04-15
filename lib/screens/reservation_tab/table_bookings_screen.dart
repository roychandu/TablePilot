// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/table_booking_model.dart';
import '../../models/reservation_model.dart';
import '../../services/table_booking_service.dart';
import '../../services/reservation_service.dart';
import 'add_order_screen.dart';
import 'add_table_booking_screen.dart';
import 'table_detail_screen.dart';

class TableBookingsScreen extends StatefulWidget {
  final Widget Function(double)? viewSelectionButtons;
  final bool skipScaffold;

  const TableBookingsScreen({
    super.key,
    this.viewSelectionButtons,
    this.skipScaffold = false,
  });

  @override
  State<TableBookingsScreen> createState() => _TableBookingsScreenState();
}

class _TableBookingsScreenState extends State<TableBookingsScreen> {
  final TableBookingService _tableBookingService = TableBookingService();
  final ReservationService _reservationService = ReservationService();

  Map<String, dynamic> _calculateTableStatuses(
    List<TableBookingModel> bookings,
    List<ReservationModel> reservations,
  ) {
    const maxTable = 20;
    final allTableNumbers = List.generate(maxTable, (index) => index + 1);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    int available = 0;
    int reserved = 0;
    int occupied = 0;
    int cleaning = 0;

    // Track which tables have active bookings
    final Map<int, TableBookingStatus> tableStatuses = {};
    // Track tables reserved via reservations (within 30 minutes before reservation time)
    final Set<int> reservedTableNumbers = {};

    // Check reservations - show as "Reserved" 30 minutes before reservation time
    for (final reservation in reservations) {
      if (reservation.tableNumber != null &&
          reservation.status != ReservationStatus.cancelled &&
          reservation.status != ReservationStatus.completed) {
        final reservationStartTime = reservation.startTime;

        // Calculate 30 minutes before reservation time
        final thirtyMinutesBefore = reservationStartTime.subtract(
          const Duration(minutes: 30),
        );

        // Show as "Reserved" if current time is between 30 minutes before and reservation time
        if (!now.isBefore(thirtyMinutesBefore) &&
            now.isBefore(reservationStartTime)) {
          reservedTableNumbers.add(reservation.tableNumber!);
        }
      }
    }

    for (final booking in bookings) {
      if (booking.tableNumber == null ||
          booking.status == TableBookingStatus.cancelled ||
          booking.status == TableBookingStatus.completed) {
        continue;
      }

      final bookingDateTime = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
        booking.bookingTime.hour,
        booking.bookingTime.minute,
      );

      // Only consider bookings for today or future
      if (bookingDateTime.isBefore(todayStart)) {
        continue;
      }

      final tableNum = booking.tableNumber!;

      // Skip if table is already reserved via reservation (reservations take priority)
      if (reservedTableNumbers.contains(tableNum)) {
        continue;
      }

      // If table has multiple bookings, prioritize by status
      if (!tableStatuses.containsKey(tableNum) ||
          booking.status == TableBookingStatus.seated) {
        tableStatuses[tableNum] = booking.status;
      }
    }

    // Count tables by status
    for (final tableNum in allTableNumbers) {
      // Check if reserved via reservation first (takes priority)
      if (reservedTableNumbers.contains(tableNum)) {
        reserved++;
      } else {
        final status = tableStatuses[tableNum];

        if (status == null) {
          available++;
        } else if (status == TableBookingStatus.confirmed) {
          reserved++;
        } else if (status == TableBookingStatus.seated) {
          occupied++;
        } else if (status == TableBookingStatus.cleaning) {
          cleaning++;
        } else {
          available++;
        }
      }
    }

    return {
      'available': available,
      'reserved': reserved,
      'occupied': occupied,
      'cleaning': cleaning,
    };
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    final verticalSpacing = isTablet ? 24.0 : 16.0;

    final content = StreamBuilder<List<TableBookingModel>>(
      stream: _tableBookingService.getTableBookingsStream(),
      builder: (context, bookingsSnapshot) {
        // Use empty list if no data yet - show UI immediately
        final bookings = bookingsSnapshot.data ?? [];

        // Filter to only today's and upcoming bookings (exclude past bookings)
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        final filteredBookings = bookings.where((booking) {
          final bookingDateOnly = DateTime(
            booking.bookingDate.year,
            booking.bookingDate.month,
            booking.bookingDate.day,
          );
          // Include bookings for today or future dates (exclude past dates)
          return !bookingDateOnly.isBefore(todayStart);
        }).toList();

        // Sort bookings by date and time (upcoming first)
        final sortedBookings = filteredBookings
          ..sort((a, b) {
            final aDateTime = DateTime(
              a.bookingDate.year,
              a.bookingDate.month,
              a.bookingDate.day,
              a.bookingTime.hour,
              a.bookingTime.minute,
            );
            final bDateTime = DateTime(
              b.bookingDate.year,
              b.bookingDate.month,
              b.bookingDate.day,
              b.bookingTime.hour,
              b.bookingTime.minute,
            );
            return aDateTime.compareTo(bDateTime);
          });

        // Get reservations to check for recent reservations (within 30 minutes)
        return StreamBuilder<List<ReservationModel>>(
          stream: _reservationService.getReservationsStream(),
          builder: (context, reservationsSnapshot) {
            final reservations = reservationsSnapshot.data ?? [];
            final tableStatuses = _calculateTableStatuses(
              bookings,
              reservations,
            );

            return RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 500));
              },
              color: AppColors.primary,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalSpacing,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Table Status Cards
                          _buildTableStatusCards(tableStatuses, screenWidth),
                          SizedBox(height: verticalSpacing),
                          // Table Grid
                          _buildTableGrid(bookings, reservations, screenWidth),
                          SizedBox(height: verticalSpacing * 1.5),
                          // Table Bookings Header
                          if (sortedBookings.isNotEmpty)
                            Text(
                              'Table Bookings',
                              style: AppTextStyles.h5.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isTablet ? 20 : 18,
                              ),
                            ),
                          if (sortedBookings.isNotEmpty)
                            SizedBox(height: verticalSpacing * 0.75),
                          // All Bookings
                          if (sortedBookings.isEmpty)
                            _buildEmptyState(screenWidth)
                          else
                            ...sortedBookings.map(
                              (booking) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: isTablet ? 16 : 12,
                                ),
                                child: _buildBookingCard(
                                  booking,
                                  screenWidth,
                                  isTablet,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (widget.skipScaffold) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: content),
    );
  }

  Widget _buildTableStatusCards(
    Map<String, dynamic> statuses,
    double screenWidth,
  ) {
    final isTablet = screenWidth > 600;
    final spacing = isTablet ? 16.0 : 12.0;

    final statusItems = [
      {
        'value': '${statuses['available']}',
        'label': 'Available',
        'color': AppColors.success, // Green
      },
      {
        'value': '${statuses['reserved']}',
        'label': 'Reserved',
        'color': AppColors.warning, // Orange
      },
      {
        'value': '${statuses['occupied']}',
        'label': 'Occupied',
        'color': AppColors.warning, // Orange
      },
      {
        'value': '${statuses['cleaning']}',
        'label': 'Cleaning',
        'color': AppColors.info, // Blue
      },
    ];

    return Container(
      padding: EdgeInsets.all(spacing),
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
        children: statusItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < statusItems.length - 1 ? spacing : 0,
              ),
              child: _buildStatusCard(
                value: item['value'] as String,
                label: item['label'] as String,
                color: item['color'] as Color,
                screenWidth: screenWidth,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusCard({
    required String value,
    required String label,
    required Color color,
    required double screenWidth,
  }) {
    final isTablet = screenWidth > 600;
    final cardHeight = isTablet ? 100.0 : 90.0;
    final padding = isTablet
        ? const EdgeInsets.symmetric(vertical: 16, horizontal: 8)
        : const EdgeInsets.symmetric(vertical: 14, horizontal: 6);
    final valueFontSize = isTablet ? 28.0 : 24.0;
    final labelFontSize = isTablet ? 13.0 : 12.0;

    return Container(
      height: cardHeight,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTextStyles.h4.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: valueFontSize,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
    TableBookingModel booking,
    double screenWidth,
    bool isTablet,
  ) {
    final formattedDate =
        '${booking.bookingDate.day.toString().padLeft(2, '0')}/${booking.bookingDate.month.toString().padLeft(2, '0')}/${booking.bookingDate.year}';

    // Format time in 12-hour format with AM/PM
    final hour = booking.bookingTime.hour;
    final minute = booking.bookingTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final formattedTime =
        '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';

    // Get display name - use guest name if available, otherwise show table number
    final displayName = booking.guestName?.isNotEmpty == true
        ? booking.guestName!
        : (booking.tableNumber != null
              ? 'Table T${booking.tableNumber}'
              : 'Table Booking');

    // Calculate menu items count and total quantity
    final menuItemsCount = booking.menuItems.length;
    final totalMenuQuantity = booking.menuItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    // Status color and text - using model helper functions
    final statusColor = getTableBookingStatusDisplayColor(booking.status);
    final statusText = getTableBookingStatusDisplayText(booking.status);

    final isCancelled = booking.status == TableBookingStatus.cancelled;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TableDetailScreen(booking: booking),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCancelled
                  ? AppColors.cardBackground.withOpacity(0.6)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: isCancelled
                  ? Border.all(color: AppColors.error, width: 2)
                  : null,
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
                // Header: Guest Name/Table and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: isCancelled
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              decoration: isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!isCancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Details in 2 columns
                Row(
                  children: [
                    // Left Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.calendar,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  formattedDate,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isCancelled
                                        ? AppColors.textSecondary.withOpacity(
                                            0.6,
                                          )
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Guests
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.person_2,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${booking.numberOfGuests} ${booking.numberOfGuests == 1 ? 'guest' : 'guests'}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isCancelled
                                        ? AppColors.textSecondary.withOpacity(
                                            0.6,
                                          )
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Right Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.clock,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  formattedTime,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isCancelled
                                        ? AppColors.textSecondary.withOpacity(
                                            0.6,
                                          )
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Menu Items
                          if (menuItemsCount > 0)
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.square_list,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$menuItemsCount ${menuItemsCount == 1 ? 'item' : 'items'}${totalMenuQuantity > menuItemsCount ? ' ($totalMenuQuantity)' : ''}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isCancelled
                                          ? AppColors.textSecondary.withOpacity(
                                              0.6,
                                            )
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Phone, Email
                if ((booking.phoneNumber != null &&
                        booking.phoneNumber!.isNotEmpty) ||
                    (booking.email != null && booking.email!.isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (booking.phoneNumber != null &&
                          booking.phoneNumber!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.phone,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                booking.phoneNumber!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (booking.email != null && booking.email!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.mail,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                booking.email!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
                // Special Preferences
                if (booking.specialPreferences != null &&
                    booking.specialPreferences!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.info,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.specialPreferences!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Cancel Badge (positioned in top-right corner)
          if (isCancelled)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, color: AppColors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'CANCELLED',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

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

  Widget _buildTableGrid(
    List<TableBookingModel> bookings,
    List<ReservationModel> reservations,
    double screenWidth,
  ) {
    // Limit to first 20 tables (T1–T20)
    const maxTable = 20;
    final allTableNumbers = List.generate(maxTable, (index) => index + 1);

    // Get tables that have bookings (for today or future)
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final bookedTableNumbers = <int>{};
    final reservedTableNumbers =
        <int>{}; // Tables reserved via reservations within 30 minutes

    // Check bookings
    for (final booking in bookings) {
      if (booking.tableNumber != null &&
          booking.status != TableBookingStatus.cancelled &&
          booking.status != TableBookingStatus.completed) {
        final bookingDateTime = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
          booking.bookingTime.hour,
          booking.bookingTime.minute,
        );
        // Include bookings for today or future
        if (bookingDateTime.isAfter(todayStart) ||
            bookingDateTime.isAtSameMomentAs(todayStart)) {
          bookedTableNumbers.add(booking.tableNumber!);
        }
      }
    }

    // Check reservations - show as "Reserved" 30 minutes before reservation time
    for (final reservation in reservations) {
      if (reservation.tableNumber != null &&
          reservation.status != ReservationStatus.cancelled &&
          reservation.status != ReservationStatus.completed) {
        // startTime is already a complete DateTime
        final reservationStartTime = reservation.startTime;

        // Calculate 30 minutes before reservation time
        final thirtyMinutesBefore = reservationStartTime.subtract(
          const Duration(minutes: 30),
        );

        // Show as "Reserved" if current time is between 30 minutes before and reservation time
        // Include the exact moment of 30 minutes before, exclude reservation start time
        if (!now.isBefore(thirtyMinutesBefore) &&
            now.isBefore(reservationStartTime)) {
          reservedTableNumbers.add(reservation.tableNumber!);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Tables',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth > 600 ? 20 : 18,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: allTableNumbers.length,
          itemBuilder: (context, index) {
            final tableNumber = allTableNumbers[index];
            final seatCount = _getSeatCount(tableNumber);
            final hasBooking = bookedTableNumbers.contains(tableNumber);
            final isReserved = reservedTableNumbers.contains(tableNumber);

            return _buildTableCard(
              tableNumber: tableNumber,
              seatCount: seatCount,
              hasBooking: hasBooking,
              isReserved: isReserved,
            );
          },
        ),
      ],
    );
  }

  Widget _buildTableCard({
    required int tableNumber,
    required int seatCount,
    required bool hasBooking,
    required bool isReserved,
  }) {
    // Determine display color and border based on status
    // Priority: Reserved (within 30 min) > Booking
    final displayColor = isReserved
        ? AppColors.warning
        : (hasBooking ? AppColors.info : AppColors.textPrimary);
    final borderColor = isReserved
        ? AppColors.warning
        : (hasBooking ? AppColors.info : AppColors.border);
    final backgroundColor = isReserved
        ? AppColors.warning.withOpacity(0.2)
        : (hasBooking
              ? AppColors.info.withOpacity(0.2)
              : AppColors.cardBackground);

    return InkWell(
      onTap: () {
        if (hasBooking || isReserved) {
          // Show table details bottom sheet for tables with bookings or reservations
          _showTableDetailsBottomSheet(tableNumber, seatCount);
        } else {
          // Directly show booking screen for unselected tables
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                AddTableBookingScreen(tableNumber: tableNumber),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: (hasBooking || isReserved) ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'T$tableNumber',
              style: AppTextStyles.bodyLarge.copyWith(
                color: displayColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '$seatCount seats',
              style: AppTextStyles.bodySmall.copyWith(
                color: displayColor,
                fontSize: 11,
              ),
            ),
            if (isReserved)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Reserved',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else if (hasBooking)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.info,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTableDetailsBottomSheet(
    int tableNumber,
    int seatCount,
  ) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Check for reservations first (within 30 minutes before reservation time)
    final reservations = await _reservationService.getReservationsByTable(
      tableNumber,
    );
    ReservationModel? activeReservation;

    for (final reservation in reservations) {
      if (reservation.status != ReservationStatus.cancelled &&
          reservation.status != ReservationStatus.completed) {
        final reservationStartTime = reservation.startTime;
        final thirtyMinutesBefore = reservationStartTime.subtract(
          const Duration(minutes: 30),
        );

        // Show as "Reserved" if current time is between 30 minutes before and reservation time
        if (!now.isBefore(thirtyMinutesBefore) &&
            now.isBefore(reservationStartTime)) {
          activeReservation = reservation;
          break;
        }
      }
    }

    // Get booking for this table (if no active reservation)
    TableBookingModel? activeBooking;
    if (activeReservation == null) {
      final bookings = await _tableBookingService.getBookingsByTable(
        tableNumber,
      );

      // Find active booking for today or future
      for (final booking in bookings) {
        if (booking.status != TableBookingStatus.cancelled &&
            booking.status != TableBookingStatus.completed) {
          final bookingDateTime = DateTime(
            booking.bookingDate.year,
            booking.bookingDate.month,
            booking.bookingDate.day,
            booking.bookingTime.hour,
            booking.bookingTime.minute,
          );
          if (bookingDateTime.isAfter(todayStart) ||
              bookingDateTime.isAtSameMomentAs(todayStart)) {
            activeBooking = booking;
            break;
          }
        }
      }
    }

    // Determine status and display info
    String statusText;
    Color statusColor;
    bool isReservation = activeReservation != null;

    if (isReservation) {
      statusText = 'Reserved';
      statusColor = AppColors.warning; // Orange for Reserved
    } else if (activeBooking != null) {
      statusText = getTableBookingStatusDisplayText(activeBooking.status);
      statusColor = getTableBookingStatusDisplayColor(activeBooking.status);
    } else {
      statusText = 'Available';
      statusColor = AppColors.success; // Green for Available
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TableDetailsBottomSheet(
        tableNumber: tableNumber,
        seatCount: seatCount,
        initialActiveBooking: activeBooking,
        initialActiveReservation: activeReservation,
        initialStatusText: statusText,
        initialStatusColor: statusColor,
        initialIsReservation: isReservation,
        tableBookingService: _tableBookingService,
        reservationService: _reservationService,
        onStatusChange: (booking) => _showStatusSelectionDialog(booking),
      ),
    );
  }

  Future<void> _showStatusSelectionDialog(TableBookingModel booking) async {
    if (booking.id == null) return;

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
              // Cleaning option (not shown if already cleaning)
              if (booking.status != TableBookingStatus.cleaning) ...[
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
      await _updateBookingStatus(booking, selectedStatus);
    }
  }

  Future<void> _updateBookingStatus(
    TableBookingModel booking,
    TableBookingStatus newStatus,
  ) async {
    if (booking.id == null) return;

    try {
      final updatedBooking = booking.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      final success = await _tableBookingService.updateTableBooking(
        updatedBooking,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Status updated to ${getTableBookingStatusDisplayText(newStatus)}',
              ),
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
    }
  }

  Widget _buildEmptyState(double screenWidth) {
    final isTablet = screenWidth > 600;
    final padding = isTablet ? 60.0 : 40.0;
    final iconSize = isTablet ? 80.0 : 64.0;
    final titleFontSize = isTablet ? 22.0 : 18.0;
    final bodyFontSize = isTablet ? 17.0 : 15.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/no_active.png',
            width: 220,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.restaurant,
              size: iconSize,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            'No table bookings yet',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            'Tap on a table to create your first booking',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: bodyFontSize,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TableDetailsBottomSheet extends StatefulWidget {
  final int tableNumber;
  final int seatCount;
  final TableBookingModel? initialActiveBooking;
  final ReservationModel? initialActiveReservation;
  final String initialStatusText;
  final Color initialStatusColor;
  final bool initialIsReservation;
  final TableBookingService tableBookingService;
  final ReservationService reservationService;
  final Function(TableBookingModel) onStatusChange;

  const _TableDetailsBottomSheet({
    required this.tableNumber,
    required this.seatCount,
    required this.initialActiveBooking,
    required this.initialActiveReservation,
    required this.initialStatusText,
    required this.initialStatusColor,
    required this.initialIsReservation,
    required this.tableBookingService,
    required this.reservationService,
    required this.onStatusChange,
  });

  @override
  State<_TableDetailsBottomSheet> createState() =>
      _TableDetailsBottomSheetState();
}

class _TableDetailsBottomSheetState extends State<_TableDetailsBottomSheet> {
  late TableBookingModel? _activeBooking;
  late ReservationModel? _activeReservation;
  late List<ReservationMenuItem> _menuItems;
  late String _statusText;
  late Color _statusColor;
  late bool _isReservation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _activeBooking = widget.initialActiveBooking;
    _activeReservation = widget.initialActiveReservation;
    _statusText = widget.initialStatusText;
    _statusColor = widget.initialStatusColor;
    _isReservation = widget.initialIsReservation;
    _menuItems =
        _activeReservation?.menuItems ??
        _activeBooking?.menuItems ??
        <ReservationMenuItem>[];
  }

  Future<void> _refreshBookingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh reservation data
      if (_isReservation && _activeReservation?.id != null) {
        final reservations = await widget.reservationService
            .getReservationsByTable(widget.tableNumber);
        for (final reservation in reservations) {
          if (reservation.id == _activeReservation?.id) {
            _activeReservation = reservation;
            break;
          }
        }
      }

      // Refresh booking data
      if (!_isReservation && _activeBooking?.id != null) {
        final bookings = await widget.tableBookingService.getBookingsByTable(
          widget.tableNumber,
        );
        for (final booking in bookings) {
          if (booking.id == _activeBooking?.id) {
            _activeBooking = booking;
            break;
          }
        }
      }

      // Update menu items
      _menuItems =
          _activeReservation?.menuItems ??
          _activeBooking?.menuItems ??
          <ReservationMenuItem>[];

      // Update status
      if (_isReservation && _activeReservation != null) {
        _statusText = 'Reserved';
        _statusColor = AppColors.warning;
      } else if (_activeBooking != null) {
        _statusText = getTableBookingStatusDisplayText(_activeBooking!.status);
        _statusColor = getTableBookingStatusDisplayColor(
          _activeBooking!.status,
        );
      }
    } catch (e) {
      debugPrint('Error refreshing booking data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatReservationTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Table Details',
                    style: AppTextStyles.h4.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border),
          // Content
          Flexible(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Table ${widget.tableNumber}',
                                          style: AppTextStyles.h5.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Capacity: ${widget.seatCount} ${widget.seatCount == 1 ? 'Seat' : 'Seats'}',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Status
                              Row(
                                children: [
                                  Text(
                                    'Status:',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _statusText,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: _statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Reservation/Booking Details Section
                        if (_isReservation && _activeReservation != null) ...[
                          // Reservation Details Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reservation Details',
                                  style: AppTextStyles.h6.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Reservation Name
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.calendar,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_activeReservation!.reservationDate.day.toString().padLeft(2, '0')}/${_activeReservation!.reservationDate.month.toString().padLeft(2, '0')}/${_activeReservation!.reservationDate.year}',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Contact Person
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.person,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _activeReservation!.contactPerson,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Phone
                                if (_activeReservation!.phone.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.phone,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _activeReservation!.phone,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (_activeReservation!.phone.isNotEmpty)
                                  const SizedBox(height: 8),
                                // Email
                                if (_activeReservation!.email.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.mail,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _activeReservation!.email,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (_activeReservation!.email.isNotEmpty)
                                  const SizedBox(height: 8),
                                // Start Time
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.clock,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _formatReservationTime(
                                          _activeReservation!.startTime,
                                        ),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Number of Guests
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.person_2,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${_activeReservation!.numberOfGuests} ${_activeReservation!.numberOfGuests == 1 ? 'guest' : 'guests'}',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Order Section
                        Text(
                          'Order',
                          style: AppTextStyles.h6.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_menuItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'No menu items selected',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: _menuItems.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.itemName,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                      ),
                                      if (item.quantity > 1)
                                        Text(
                                          'x${item.quantity}',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 20),
                        // Action Buttons
                        if (!_isReservation) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    if (_activeBooking != null) {
                                      widget.onStatusChange(_activeBooking!);
                                    } else {
                                      // Show create booking screen
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) =>
                                            AddTableBookingScreen(
                                              tableNumber: widget.tableNumber,
                                            ),
                                      );
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppColors.border),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Change Status',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      (_activeBooking != null &&
                                          _activeBooking!.status ==
                                              TableBookingStatus.cleaning)
                                      ? null
                                      : () async {
                                          if (_activeBooking != null) {
                                            // Navigate to AddOrderScreen
                                            final created =
                                                await Navigator.push<bool>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        AddOrderScreen(
                                                          event: _activeBooking,
                                                        ),
                                                  ),
                                                );
                                            // Refresh booking data after order is updated
                                            if (created == true && mounted) {
                                              await _refreshBookingData();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Menu items updated successfully',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.success,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color:
                                          (_activeBooking != null &&
                                              _activeBooking!.status ==
                                                  TableBookingStatus.cleaning)
                                          ? AppColors.border.withOpacity(0.5)
                                          : AppColors.border,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    disabledForegroundColor: AppColors
                                        .textSecondary
                                        .withOpacity(0.5),
                                  ),
                                  child: Text(
                                    'Add Order',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color:
                                          (_activeBooking != null &&
                                              _activeBooking!.status ==
                                                  TableBookingStatus.cleaning)
                                          ? AppColors.textSecondary.withOpacity(
                                              0.5,
                                            )
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
