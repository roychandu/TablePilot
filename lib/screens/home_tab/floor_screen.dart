import 'dart:async';
import 'package:flutter/material.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../services/table_service.dart';
import '../../services/table_booking_service.dart';
import '../../services/staff_service.dart';
import '../../models/table_booking_model.dart';
import '../../models/staff_model.dart';
import '../staff_tab/add_staff_screen.dart';

enum _FloorTableStatus { available, booked, seated, cleaning, served }

class _FloorTable {
  const _FloorTable({
    required this.number,
    required this.seats,
    required this.status,
  });

  final int number;
  final int seats;
  final _FloorTableStatus status;
}

/// Floor plan screen modeled on the provided design.
/// Now driven by live table statuses and floor number.
class FloorScreen extends StatefulWidget {
  const FloorScreen({super.key, required this.floorNum});

  final int floorNum;

  @override
  State<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends State<FloorScreen> {
  final TableService _tableService = TableService();
  final TableBookingService _tableBookingService = TableBookingService();
  final StaffService _staffService = StaffService();
  StreamSubscription<List<TableBookingModel>>? _bookingSubscription;

  // Settings
  static const int _tablesPerFloor = 10;

  int _selectedFloor = 1;
  bool _isLoading = true;

  Map<int, TableStatus> _tableStatuses = {};
  List<TableBookingModel> _bookings = [];
  final Map<int, _FloorTableStatus> _manualOverrides = {};
  List<StaffModel> _staff = [];
  final Map<int, StaffModel?> _tableAssignments = {};

  List<_FloorTable> get _tablesForFloor {
    final start = ((_selectedFloor - 1) * _tablesPerFloor) + 1;
    final end = start + _tablesPerFloor - 1;
    final List<_FloorTable> tables = [];
    for (int t = start; t <= end; t++) {
      // Priority: manual overrides (e.g., cleaning) -> active booking -> table status
      final overrideStatus = _manualOverrides[t];
      final bookingStatus = _getBookingStatusForTable(t);
      final resolvedTableStatus =
          bookingStatus ?? _tableStatuses[t] ?? TableStatus.available;
      final resolvedFloorStatus =
          overrideStatus ?? _mapStatus(resolvedTableStatus);
      tables.add(
        _FloorTable(
          number: t,
          seats: _estimateSeats(t),
          status: resolvedFloorStatus,
        ),
      );
    }
    return tables;
  }

  @override
  void initState() {
    super.initState();
    _selectedFloor = widget.floorNum;
    _loadData();
    _bookingSubscription = _tableBookingService.getTableBookingsStream().listen(
      (bookings) {
        if (!mounted) return;
        setState(() {
          _bookings = bookings;
        });
      },
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final statuses = await _tableService.getTables();
      final bookings = await _tableBookingService.getTableBookings();
      final staff = await _staffService.getStaff();
      if (!mounted) return;
      setState(() {
        _tableStatuses = statuses;
        _bookings = bookings;
        _staff = staff;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Get the booking status for a specific table number, or null if no active booking
  TableStatus? _getBookingStatusForTable(int tableNumber) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Find the most relevant booking for this table (today), prefer seated.
    TableBookingModel? activeBooking;

    for (final booking in _bookings) {
      if (booking.tableNumber != tableNumber) continue;
      if (booking.status == TableBookingStatus.cancelled ||
          booking.status == TableBookingStatus.completed) {
        continue;
      }

      // Check if booking is for today
      final bookingDate = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
      );
      if (bookingDate.year != today.year ||
          bookingDate.month != today.month ||
          bookingDate.day != today.day) {
        continue;
      }

      // Prefer seated over confirmed if multiple bookings exist for today
      if (activeBooking == null ||
          booking.status == TableBookingStatus.seated) {
        activeBooking = booking;
      }
    }

    if (activeBooking == null) return null;

    // Map booking status to table status
    if (activeBooking.status == TableBookingStatus.seated) {
      return TableStatus.occupied;
    } else if (activeBooking.status == TableBookingStatus.confirmed) {
      return TableStatus.reserved;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tables = _tablesForFloor;
    final counts = _calculateCounts(tables);
    final totalForFloor = tables.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Floor Plan',
          style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Floor ${widget.floorNum}',
                                    style: AppTextStyles.h4.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tables overview',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  '$totalForFloor / $totalForFloor tables',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusChips(counts),
                  const SizedBox(height: 12),
                  _buildGrid(tables),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    super.dispose();
  }

  Widget _buildStatusChips(Map<_FloorTableStatus, int> counts) {
    final chipData = [
      (_FloorTableStatus.available, 'Available'),
      (_FloorTableStatus.booked, 'Booked'),
      (_FloorTableStatus.seated, 'Seated'),
      (_FloorTableStatus.cleaning, 'Cleaning'),
      (_FloorTableStatus.served, 'Served'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            for (int i = 0; i < chipData.length; i++) ...[
              Builder(
                builder: (context) {
                  final status = chipData[i].$1;
                  final label = chipData[i].$2;
                  final count = counts[status] ?? 0;
                  final color = _statusColor(status);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      '$label ($count)',
                      style: AppTextStyles.bodySmall.copyWith(color: color),
                    ),
                  );
                },
              ),
              if (i != chipData.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<_FloorTable> tables) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.of(context).size;
        final screenWidth = mediaSize.width;
        final cardHeight = mediaSize.height / 3;
        const spacing = 12.0;

        // Split tables into 2 rows
        final midPoint = (tables.length / 2).ceil();
        final firstRowTables = tables.sublist(0, midPoint);
        final secondRowTables = tables.sublist(midPoint);

        // Calculate card width based on full available width (no side padding)
        const horizontalPadding = 0.0;
        final availableWidth = screenWidth - horizontalPadding;
        // Each card should take half of the available width
        final cardWidth = availableWidth / 2;

        return Padding(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // First row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: firstRowTables.asMap().entries.map((entry) {
                      final index = entry.key;
                      final table = entry.value;
                      final showDivider = index != firstRowTables.length - 1;
                      return SizedBox(
                        width: cardWidth,
                        child: _buildTableCard(
                          table,
                          cardWidth,
                          cardHeight,
                          showDivider,
                          isFirst: index == 0,
                          isLast: index == firstRowTables.length - 1,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: spacing),
              // Second row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: secondRowTables.asMap().entries.map((entry) {
                      final index = entry.key;
                      final table = entry.value;
                      final showDivider = index != secondRowTables.length - 1;
                      return SizedBox(
                        width: cardWidth,
                        child: _buildTableCard(
                          table,
                          cardWidth,
                          cardHeight,
                          showDivider,
                          isFirst: index == 0,
                          isLast: index == secondRowTables.length - 1,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableCard(
    _FloorTable table,
    double cardWidth,
    double cardHeight,
    bool showDivider, {
    required bool isFirst,
    required bool isLast,
  }) {
    final statusLabel = _statusLabel(table.status);
    final statusColor = _statusColor(table.status);
    final tableLabel = 'T${table.number.toString().padLeft(2, '0')}';

    return SizedBox(
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => _showTableActions(table),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D3051),
                borderRadius: BorderRadius.only(
                  topLeft: isFirst ? const Radius.circular(16) : Radius.zero,
                  bottomLeft: isFirst ? const Radius.circular(16) : Radius.zero,
                  topRight: isLast ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBadge(text: statusLabel, color: statusColor),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111321),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(cardWidth),
                          topRight: Radius.circular(cardWidth),
                          bottomLeft: const Radius.circular(18),
                          bottomRight: const Radius.circular(18),
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7D8EE3),
                                      Color(0xFF3D4786),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.18),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    tableLabel,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Seats: ${table.seats}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Decorative bricks across the full card area (overlay, non-interactive)
          Positioned.fill(
            child: IgnorePointer(child: Stack(children: _menuBricks())),
          ),
          if (showDivider)
            Positioned(
              right: -3,
              top: 0,
              bottom: 0,
              child: _DashedDivider(color: Colors.white),
            ),
        ],
      ),
    );
  }

  List<Widget> _menuBricks() {
    return [
      const Positioned(top: 18, left: 20, child: _MenuBrick(width: 42)),
      const Positioned(top: 70, right: 30, child: _MenuBrick(width: 34)),
      const Positioned(bottom: 32, left: 36, child: _MenuBrick(width: 30)),
      const Positioned(top: 120, left: 60, child: _MenuBrick(width: 26)),
      const Positioned(top: 32, right: 90, child: _MenuBrick(width: 24)),
      const Positioned(bottom: 70, right: 24, child: _MenuBrick(width: 28)),
      const Positioned(bottom: 120, left: 110, child: _MenuBrick(width: 22)),
      const Positioned(top: 45, left: 85, child: _MenuBrick(width: 20)),
      const Positioned(top: 95, right: 55, child: _MenuBrick(width: 32)),
      const Positioned(bottom: 95, left: 50, child: _MenuBrick(width: 25)),
      const Positioned(top: 150, right: 70, child: _MenuBrick(width: 23)),
      const Positioned(bottom: 50, right: 50, child: _MenuBrick(width: 27)),
      const Positioned(top: 55, left: 45, child: _MenuBrick(width: 19)),
      const Positioned(bottom: 85, left: 75, child: _MenuBrick(width: 31)),
      const Positioned(top: 135, left: 95, child: _MenuBrick(width: 21)),
      const Positioned(bottom: 110, right: 40, child: _MenuBrick(width: 29)),
    ];
  }

  Map<_FloorTableStatus, int> _calculateCounts(List<_FloorTable> tables) {
    final counts = <_FloorTableStatus, int>{};
    for (final status in _FloorTableStatus.values) {
      counts[status] = 0;
    }
    for (final table in tables) {
      counts[table.status] = (counts[table.status] ?? 0) + 1;
    }
    return counts;
  }

  Color _statusColor(_FloorTableStatus status) {
    switch (status) {
      case _FloorTableStatus.available:
        return AppColors.primary; // green
      case _FloorTableStatus.booked:
        return AppColors.info; // blue
      case _FloorTableStatus.seated:
        return AppColors.secondary; // yellow/orange
      case _FloorTableStatus.cleaning:
        return AppColors.highlight; // red
      case _FloorTableStatus.served:
        return const Color(0xFFCF3E81); // magenta similar to design
    }
  }

  void _showTableActions(_FloorTable table) {
    final bookings = _getBookingsForTable(table.number);
    final statusLabel = _statusLabel(table.status);
    final isCleaningOverride =
        _manualOverrides[table.number] == _FloorTableStatus.cleaning;
    final assignedStaff = _tableAssignments[table.number];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Table T${table.number}',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text(
                      statusLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: _statusColor(table.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${table.seats} seats',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAssignStaffSheet(table.number);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Assign Staff',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Show "Mark Cleaning" only when table is available or served, or already in cleaning mode
                  if (table.status == _FloorTableStatus.available ||
                      table.status == _FloorTableStatus.served ||
                      isCleaningOverride) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            if (isCleaningOverride) {
                              _manualOverrides.remove(table.number);
                            } else {
                              _manualOverrides[table.number] =
                                  _FloorTableStatus.cleaning;
                            }
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isCleaningOverride
                                    ? 'Marked T${table.number} as clean'
                                    : 'Marked T${table.number} as cleaning',
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isCleaningOverride
                                ? AppColors.success
                                : AppColors.highlight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          isCleaningOverride ? 'Clean Done' : 'Mark Cleaning',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isCleaningOverride
                                ? AppColors.success
                                : AppColors.highlight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (assignedStaff != null) ...[
                Text(
                  'Assigned Staff',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  assignedStaff.fullName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (bookings.isNotEmpty)
                Text(
                  'Booked Time Slots',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  'No booked slots for today',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 8),
              ...bookings.map(
                (booking) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatBookingDateTime(booking),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              booking.guestName ?? 'Guest',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        booking.status.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  void _showAssignStaffSheet(int tableNumber) {
    // Capture navigator and scaffoldMessenger before showing bottom sheet
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        if (_staff.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No staff available',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please add staff to assign them to tables.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    // Pop the bottom sheet using its own context
                    Navigator.pop(bottomSheetContext);

                    // Navigate using the widget's navigator
                    final created = await navigator.push<bool>(
                      MaterialPageRoute(builder: (_) => const AddStaffScreen()),
                    );

                    if (created == true && mounted) {
                      // Refresh staff list after adding
                      await _loadData();
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Staff added successfully'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Add New Staff',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Assign Staff to T$tableNumber',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _staff.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, index) {
                    final staff = _staff[index];
                    final isSelected =
                        _tableAssignments[tableNumber]?.id == staff.id;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        staff.fullName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        staff.category.isNotEmpty ? staff.category : 'Staff',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.success)
                          : null,
                      onTap: () {
                        setState(() {
                          _tableAssignments[tableNumber] = staff;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Assigned ${staff.fullName} to T$tableNumber',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _tableAssignments.remove(tableNumber);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed assignment for T$tableNumber'),
                    ),
                  );
                },
                child: Text(
                  'Clear Assignment',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(_FloorTableStatus status) {
    switch (status) {
      case _FloorTableStatus.available:
        return 'Available';
      case _FloorTableStatus.booked:
        return 'Booked';
      case _FloorTableStatus.seated:
        return 'Seated';
      case _FloorTableStatus.cleaning:
        return 'Cleaning';
      case _FloorTableStatus.served:
        return 'Served';
    }
  }

  List<TableBookingModel> _getBookingsForTable(int tableNumber) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final slots =
        _bookings.where((b) {
          if (b.tableNumber != tableNumber) return false;
          if (b.status == TableBookingStatus.cancelled) return false;
          final bookingDateTime = DateTime(
            b.bookingDate.year,
            b.bookingDate.month,
            b.bookingDate.day,
            b.bookingTime.hour,
            b.bookingTime.minute,
          );
          return bookingDateTime.isAfter(startOfDay) &&
              bookingDateTime.isBefore(endOfDay);
        }).toList()..sort((a, b) {
          final aDate = DateTime(
            a.bookingDate.year,
            a.bookingDate.month,
            a.bookingDate.day,
            a.bookingTime.hour,
            a.bookingTime.minute,
          );
          final bDate = DateTime(
            b.bookingDate.year,
            b.bookingDate.month,
            b.bookingDate.day,
            b.bookingTime.hour,
            b.bookingTime.minute,
          );
          return aDate.compareTo(bDate);
        });

    return slots;
  }

  String _formatBookingDateTime(TableBookingModel booking) {
    final dateStr =
        '${booking.bookingDate.day.toString().padLeft(2, '0')}/${booking.bookingDate.month.toString().padLeft(2, '0')}/${booking.bookingDate.year}';
    final timeStr =
        '${booking.bookingTime.hour.toString().padLeft(2, '0')}:${booking.bookingTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr • $timeStr';
  }

  // Simple seat estimation fallback (since table data does not carry seats yet)
  int _estimateSeats(int tableNumber) {
    // Use the same pattern as add_table_booking_screen:
    // positions 1-3: 2 seats, 4-6: 4 seats, 7-8: 6 seats, 9-10: 8 seats (per floor)
    final positionInFloor = ((tableNumber - 1) % _tablesPerFloor) + 1;
    if (positionInFloor >= 1 && positionInFloor <= 3) return 2;
    if (positionInFloor >= 4 && positionInFloor <= 6) return 4;
    if (positionInFloor >= 7 && positionInFloor <= 8) return 6;
    return 8; // positions 9-10
  }

  _FloorTableStatus _mapStatus(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return _FloorTableStatus.available;
      case TableStatus.reserved:
        return _FloorTableStatus.booked;
      case TableStatus.occupied:
        return _FloorTableStatus.seated;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;

  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashHeight = 8.0;
          const dashSpace = 6.0;
          final rawCount = (constraints.maxHeight / (dashHeight + dashSpace))
              .floor();
          final count = rawCount > 0 ? rawCount : 1;

          return Column(
            children: List.generate(
              count,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == (count - 1) ? 0 : dashSpace,
                ),
                child: Container(
                  width: 2,
                  height: dashHeight,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuBrick extends StatelessWidget {
  final double width;

  const _MenuBrick({this.width = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
