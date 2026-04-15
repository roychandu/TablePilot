// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/reservation_model.dart';
import '../../services/reservation_service.dart';

class CalendarViewScreen extends StatefulWidget {
  final Widget Function(double) viewSelectionButtons;

  const CalendarViewScreen({super.key, required this.viewSelectionButtons});

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  final ReservationService _eventService = ReservationService();
  DateTime _selectedDate = DateTime.now();
  String _selectedTimeframe = 'day'; // 'day', 'week', or 'month'

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final verticalSpacing = isTablet ? 24.0 : 16.0;
    final horizontalPadding = isTablet ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'Calendar',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ReservationModel>>(
          stream: _eventService.getReservationsStream(),
          builder: (context, eventsSnapshot) {
            // Show loading indicator while initial data is being fetched
            if (eventsSnapshot.connectionState == ConnectionState.waiting &&
                !eventsSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }

            final events = eventsSnapshot.data ?? [];
            final eventItems = _getEventsForDate(events, _selectedDate);
            final calendarStats = _calculateCalendarStatistics(events);

            return RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 400));
              },
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalSpacing,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Navigation
                    _buildDateNavigation(screenWidth),
                    SizedBox(height: verticalSpacing),
                    // Timeframe Selection Buttons
                    _buildTimeframeButtons(screenWidth),
                    SizedBox(height: verticalSpacing),
                    // Summary Cards
                    _buildCalendarSummaryCards(calendarStats, screenWidth),
                    SizedBox(height: verticalSpacing),
                    // Timeline
                    _buildTimelineView(eventItems, screenWidth, isTablet),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateNavigation(double screenWidth) {
    final isTablet = screenWidth > 600;
    final formattedDate = _formatDate(_selectedDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              if (_selectedTimeframe == 'day') {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              } else if (_selectedTimeframe == 'week') {
                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
              } else {
                // month
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month - 1,
                  _selectedDate.day,
                );
              }
            });
          },
          icon: Icon(
            CupertinoIcons.chevron_left,
            color: AppColors.textSecondary,
            size: isTablet ? 24 : 20,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          formattedDate,
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 20 : 18,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () {
            setState(() {
              if (_selectedTimeframe == 'day') {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              } else if (_selectedTimeframe == 'week') {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              } else {
                // month
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month + 1,
                  _selectedDate.day,
                );
              }
            });
          },
          icon: Icon(
            CupertinoIcons.chevron_right,
            color: AppColors.textSecondary,
            size: isTablet ? 24 : 20,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeframeButtons(double screenWidth) {
    final isTablet = screenWidth > 600;
    final spacing = isTablet ? 16.0 : 12.0;

    return Row(
      children: [
        Expanded(
          child: _buildTimeframeButton(
            label: 'Day',
            isSelected: _selectedTimeframe == 'day',
            onTap: () => setState(() => _selectedTimeframe = 'day'),
            screenWidth: screenWidth,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildTimeframeButton(
            label: 'Week',
            isSelected: _selectedTimeframe == 'week',
            onTap: () => setState(() => _selectedTimeframe = 'week'),
            screenWidth: screenWidth,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildTimeframeButton(
            label: 'Month',
            isSelected: _selectedTimeframe == 'month',
            onTap: () => setState(() => _selectedTimeframe = 'month'),
            screenWidth: screenWidth,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeframeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required double screenWidth,
  }) {
    final isTablet = screenWidth > 600;
    final padding = isTablet
        ? const EdgeInsets.symmetric(vertical: 14, horizontal: 20)
        : const EdgeInsets.symmetric(vertical: 12, horizontal: 16);
    final fontSize = isTablet ? 16.0 : 15.0;
    // Use success color for selected timeframe
    final selectedColor = AppColors.success;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withOpacity(0.2)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : AppColors.border,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? selectedColor : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarSummaryCards(
    Map<String, dynamic> stats,
    double screenWidth,
  ) {
    final isTablet = screenWidth > 600;
    final spacing = isTablet ? 16.0 : 12.0;

    return Row(
      children: [
        Expanded(
          child: _buildCalendarSummaryCard(
            value: '${stats['reservations']}',
            label: 'Reservations',
            color: AppColors.info,
            screenWidth: screenWidth,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildCalendarSummaryCard(
            value: '${stats['events']}',
            label: 'Events',
            color: AppColors.warning,
            screenWidth: screenWidth,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildCalendarSummaryCard(
            value: '${stats['walkIns']}',
            label: 'Walk-ins',
            color: AppColors.success,
            screenWidth: screenWidth,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarSummaryCard({
    required String value,
    required String label,
    required Color color,
    required double screenWidth,
  }) {
    final isTablet = screenWidth > 600;
    final cardHeight = isTablet ? 100.0 : 90.0;
    final padding = isTablet
        ? const EdgeInsets.symmetric(vertical: 16, horizontal: 12)
        : const EdgeInsets.symmetric(vertical: 14, horizontal: 10);
    final valueFontSize = isTablet ? 24.0 : 20.0;
    final labelFontSize = isTablet ? 12.0 : 11.0;

    return Container(
      height: cardHeight,
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.h5.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: valueFontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isTablet ? 8 : 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: labelFontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(
    List<EventItem> eventItems,
    double screenWidth,
    bool isTablet,
  ) {
    // Generate time slots from 9:30 AM to 9:30 PM in 1-hour intervals
    final timeSlots = <TimeOfDay>[];
    for (int hour = 9; hour <= 21; hour++) {
      timeSlots.add(TimeOfDay(hour: hour, minute: 30));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: timeSlots.map((timeSlot) {
        // Find event that matches this time slot (within 1 hour range)
        EventItem? matchedEvent;
        for (final eventItem in eventItems) {
          final eventTime = eventItem.time;
          final slotTime = timeSlot;

          // Calculate time difference in minutes
          final eventMinutes = eventTime.hour * 60 + eventTime.minute;
          final slotMinutes = slotTime.hour * 60 + slotTime.minute;
          final timeDiff = (eventMinutes - slotMinutes).abs();

          // Match if event is within 30 minutes of the time slot
          if (timeDiff <= 30) {
            matchedEvent = eventItem;
            break;
          }
        }

        return _buildTimelineRow(
          timeSlot,
          matchedEvent ?? EventItem.empty(),
          screenWidth,
          isTablet,
        );
      }).toList(),
    );
  }

  Widget _buildTimelineRow(
    TimeOfDay time,
    EventItem eventItem,
    double screenWidth,
    bool isTablet,
  ) {
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final hasEvent = eventItem.name.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time label
          SizedBox(
            width: isTablet ? 60 : 50,
            child: Text(
              timeStr,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: isTablet ? 13 : 12,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          // Event card or empty state
          Expanded(
            child: hasEvent
                ? _buildEventCard(eventItem, screenWidth, isTablet)
                : _buildEmptyEventSlot(screenWidth, isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    EventItem eventItem,
    double screenWidth,
    bool isTablet,
  ) {
    final isCompleted = eventItem.status.toLowerCase() == 'completed';
    final cardColor = isCompleted ? AppColors.success : AppColors.info;
    final statusColor = isCompleted
        ? AppColors.success.withOpacity(0.9)
        : AppColors.info.withOpacity(0.9);

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  eventItem.name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 18 : 16,
                  ),
                ),
              ),
              Text(
                eventItem.status,
                style: AppTextStyles.bodySmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 13 : 12,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 10 : 8),
          // Guests and Location
          Row(
            children: [
              Icon(
                CupertinoIcons.person_2,
                size: isTablet ? 16 : 14,
                color: cardColor,
              ),
              SizedBox(width: isTablet ? 8 : 6),
              Text(
                '${eventItem.guests}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: cardColor,
                  fontSize: isTablet ? 14 : 12,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Icon(
                CupertinoIcons.location,
                size: isTablet ? 16 : 14,
                color: cardColor,
              ),
              SizedBox(width: isTablet ? 8 : 6),
              Expanded(
                child: Text(
                  eventItem.location,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cardColor,
                    fontSize: isTablet ? 14 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyEventSlot(double screenWidth, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isTablet ? 12 : 10,
        horizontal: isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Text(
        'No events',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
          fontSize: isTablet ? 13 : 12,
        ),
      ),
    );
  }

  // Helper Methods
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  List<EventItem> _getEventsForDate(
    List<ReservationModel> reservations,
    DateTime date,
  ) {
    final eventItems = <EventItem>[];
    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));

    for (final reservation in reservations) {
      // Check if reservation is on the selected date
      // Compare both reservationDate and startTime to ensure accurate date matching
      final reservationDateTime = DateTime(
        reservation.reservationDate.year,
        reservation.reservationDate.month,
        reservation.reservationDate.day,
        reservation.startTime.hour,
        reservation.startTime.minute,
      );

      if (reservationDateTime.isAfter(dateStart) &&
          reservationDateTime.isBefore(dateEnd)) {
        // Determine status
        String status = 'upcoming';
        if (reservation.status == ReservationStatus.completed) {
          status = 'completed';
        } else if (reservation.status == ReservationStatus.cancelled) {
          status = 'cancelled';
        } else {
          status = 'upcoming';
        }

        eventItems.add(
          EventItem(
            name: reservation.reservationName,
            time: TimeOfDay.fromDateTime(reservation.startTime),
            guests: reservation.numberOfGuests,
            location: reservation.tableNumber != null ? 'Table ${reservation.tableNumber}' : '',
            status: status,
          ),
        );
      }
    }

    // Sort events by time
    eventItems.sort((a, b) {
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });

    return eventItems;
  }

  Map<String, dynamic> _calculateCalendarStatistics(
    List<ReservationModel> reservations,
  ) {
    int upcomingEvents = 0;
    int completedEvents = 0;

    for (final reservation in reservations) {
      if (reservation.reservationDate.year == _selectedDate.year &&
          reservation.reservationDate.month == _selectedDate.month &&
          reservation.reservationDate.day == _selectedDate.day) {
        if (reservation.status == ReservationStatus.upcoming) {
          upcomingEvents++;
        } else if (reservation.status == ReservationStatus.completed) {
          completedEvents++;
        }
      }
    }

    return {
      'reservations': upcomingEvents,
      'events': upcomingEvents + completedEvents,
      'walkIns': completedEvents,
    };
  }
}

// Helper class for event items
class EventItem {
  final String name;
  final TimeOfDay time;
  final int guests;
  final String location;
  final String status;

  EventItem({
    required this.name,
    required this.time,
    required this.guests,
    required this.location,
    required this.status,
  });

  factory EventItem.empty() {
    return EventItem(
      name: '',
      time: const TimeOfDay(hour: 0, minute: 0),
      guests: 0,
      location: '',
      status: '',
    );
  }
}
