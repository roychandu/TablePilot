// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/reservation_model.dart';
import '../../services/reservation_service.dart';
import '../../services/auth_service.dart';
import 'table_bookings_screen.dart';
import 'add_reservation_screen.dart';
import 'calendar_view_screen.dart';
import 'reservation_detail_screen.dart';

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({super.key, this.initialView});

  final String? initialView; // 'list' or 'calendar'

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen>
    with SingleTickerProviderStateMixin {
  final ReservationService _eventService = ReservationService();
  final AuthService _authService = AuthService();
  late TabController _tabController;
  bool _hasReservations = false;
  bool _isAdmin = false;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Check admin status first (set _isAdmin directly to ensure it's available for TabController)
    final currentUserEmail = _authService.currentUser?.email;
    _isAdmin = currentUserEmail == 'test-admin@gmail.com';
    // Admin needs 2 tabs, non-admin needs no tabs (shows reservation booking directly)
    final tabCount = _isAdmin ? 2 : 1;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      } else {
        setState(() {}); // Update UI when tab changes
      }
    });
    _checkAdminStatus(); // Call this to update UI if needed
    if (widget.initialView == 'calendar') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: AppColors.background,
              body: CalendarViewScreen(
                viewSelectionButtons: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update admin status when screen is revisited
    _checkAdminStatus();
    // Recreate TabController if admin status changed
    final tabCount = _isAdmin ? 2 : 1;
    if (_tabController.length != tabCount) {
      _tabController.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
      _tabController.addListener(() {
        if (_tabController.index != _currentTabIndex) {
          setState(() {
            _currentTabIndex = _tabController.index;
          });
        } else {
          setState(() {}); // Update UI when tab changes
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkAdminStatus() {
    final currentUserEmail = _authService.currentUser?.email;
    final isAdmin = currentUserEmail == 'test-admin@gmail.com';
    if (_isAdmin != isAdmin) {
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      } else {
        _isAdmin = isAdmin;
      }
    }
  }

  @override
  void didUpdateWidget(ReservationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a parent requests the calendar view, open it via icon flow
    if (widget.initialView == 'calendar' &&
        widget.initialView != oldWidget.initialView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: AppColors.background,
              body: CalendarViewScreen(
                viewSelectionButtons: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      });
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
      floatingActionButton: _isAdmin
          ? (_currentTabIndex == 1 && _hasReservations
                ? FloatingActionButton(
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddReservationScreen(),
                        ),
                      );
                      if (created == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reservation created successfully'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.add, color: AppColors.white),
                  )
                : null)
          : (_hasReservations
                ? FloatingActionButton(
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddReservationScreen(),
                        ),
                      );
                      if (created == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reservation created successfully'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.add, color: AppColors.white),
                  )
                : null),
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          _isAdmin ? 'Table Booking' : 'Request Reservation',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: _isAdmin
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: AppTextStyles.bodyMedium,
                tabs: const [
                  Tab(text: 'Table Booking'),
                  Tab(text: 'Reservation Booking'),
                ],
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.calendar),
            color: AppColors.textPrimary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: AppColors.background,
                    body: CalendarViewScreen(
                      viewSelectionButtons: (_) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isAdmin
            ? TabBarView(
                controller: _tabController,
                children: [
                  // Table Booking Tab
                  const _TableBookingTabContent(),
                  // Reservation Booking Tab
                  StreamBuilder<List<ReservationModel>>(
                    stream: _eventService.getReservationsStream(),
                    builder: (context, snapshot) {
                      // Show loading indicator while data is being fetched
                      if (!snapshot.hasData) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(verticalSpacing),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }

                      // Use empty list if no data yet - show UI immediately
                      final events = snapshot.data ?? [];

                      // Filter to only today's and upcoming reservations (exclude past reservations)
                      final now = DateTime.now();
                      final todayStart = DateTime(now.year, now.month, now.day);

                      final filteredReservations = events.where((reservation) {
                        final reservationDateOnly = DateTime(
                          reservation.reservationDate.year,
                          reservation.reservationDate.month,
                          reservation.reservationDate.day,
                        );
                        // Include reservations for today or future dates (exclude past dates)
                        return !reservationDateOnly.isBefore(todayStart);
                      }).toList();

                      // Combine all reservations (upcoming and completed)
                      final allReservations = filteredReservations
                        ..sort((a, b) {
                          // Sort by date and time (upcoming first, then by date)
                          if (a.status == ReservationStatus.upcoming &&
                              b.status == ReservationStatus.completed) {
                            return -1; // Upcoming comes before completed
                          }
                          if (a.status == ReservationStatus.completed &&
                              b.status == ReservationStatus.upcoming) {
                            return 1; // Completed comes after upcoming
                          }
                          // If same status, sort by date and time
                          final dateCompare = a.reservationDate.compareTo(
                            b.reservationDate,
                          );
                          if (dateCompare != 0) return dateCompare;
                          return a.startTime.compareTo(b.startTime);
                        });

                      // Update FAB visibility based on reservations
                      if (_hasReservations != allReservations.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _hasReservations = allReservations.isNotEmpty;
                            });
                          }
                        });
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
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
                                    // All Reservations
                                    if (allReservations.isEmpty)
                                      _buildEmptyState(screenWidth)
                                    else
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: isTablet ? 3 : 2,
                                              crossAxisSpacing: 16,
                                              mainAxisSpacing: 16,
                                              childAspectRatio: 0.58,
                                            ),
                                        itemCount: allReservations.length,
                                        itemBuilder: (context, index) {
                                          final reservation =
                                              allReservations[index];
                                          return _buildEventCard(
                                            reservation,
                                            showCompletedBadge:
                                                reservation.status ==
                                                ReservationStatus.completed,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              )
            : StreamBuilder<List<ReservationModel>>(
                stream: _eventService.getReservationsStream(),
                builder: (context, snapshot) {
                  // Show loading indicator while data is being fetched
                  if (!snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(verticalSpacing),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }

                  // Use empty list if no data yet - show UI immediately
                  final events = snapshot.data ?? [];

                  // Filter to only today's and upcoming reservations (exclude past reservations)
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);

                  final filteredReservations = events.where((reservation) {
                    final reservationDateOnly = DateTime(
                      reservation.reservationDate.year,
                      reservation.reservationDate.month,
                      reservation.reservationDate.day,
                    );
                    // Include reservations for today or future dates (exclude past dates)
                    return !reservationDateOnly.isBefore(todayStart);
                  }).toList();

                  // Combine all reservations (upcoming and completed)
                  final allReservations = filteredReservations
                    ..sort((a, b) {
                      // Sort by date and time (upcoming first, then by date)
                      if (a.status == ReservationStatus.upcoming &&
                          b.status == ReservationStatus.completed) {
                        return -1; // Upcoming comes before completed
                      }
                      if (a.status == ReservationStatus.completed &&
                          b.status == ReservationStatus.upcoming) {
                        return 1; // Completed comes after upcoming
                      }
                      // If same status, sort by date and time
                      final dateCompare = a.reservationDate.compareTo(
                        b.reservationDate,
                      );
                      if (dateCompare != 0) return dateCompare;
                      return a.startTime.compareTo(b.startTime);
                    });

                  // Update FAB visibility based on reservations
                  if (_hasReservations != allReservations.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _hasReservations = allReservations.isNotEmpty;
                        });
                      }
                    });
                  }

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
                                // Scheduled Reservations Header
                                if (allReservations.isNotEmpty)
                                  SizedBox(height: verticalSpacing * 0.75),
                                // All Reservations
                                if (allReservations.isEmpty)
                                  _buildEmptyState(screenWidth)
                                else
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: isTablet ? 3 : 2,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 0.52,
                                        ),
                                    itemCount: allReservations.length,
                                    itemBuilder: (context, index) {
                                      final reservation =
                                          allReservations[index];
                                      return _buildEventCard(
                                        reservation,
                                        showCompletedBadge:
                                            reservation.status ==
                                            ReservationStatus.completed,
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _deleteReservation(ReservationModel reservation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Reservation',
          style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this reservation? This action cannot be undone.',
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
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && reservation.id != null) {
      final success = await _eventService.deleteReservation(reservation.id!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation deleted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildEventCard(
    ReservationModel reservation, {
    bool showCompletedBadge = false,
  }) {
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
    final formattedDate =
        '${reservation.reservationDate.day} ${months[reservation.reservationDate.month - 1]} ${reservation.reservationDate.year}';
    final formattedTime =
        '${reservation.startTime.hour.toString().padLeft(2, '0')}:${reservation.startTime.minute.toString().padLeft(2, '0')}';

    final isPending = reservation.status == ReservationStatus.upcoming;
    final isConfirmed =
        reservation.status == ReservationStatus.completed || showCompletedBadge;
    final isRejected = reservation.status == ReservationStatus.rejected;
    final isCancelled = reservation.status == ReservationStatus.cancelled;

    Color statusColor;
    Color statusBgColor;
    String statusText;
    IconData statusIcon;

    if (isPending) {
      statusColor = const Color(0xFFFF9800);
      statusBgColor = const Color(0xFF42372E);
      statusText = 'Pending';
      statusIcon = Icons.pending_outlined;
    } else if (isConfirmed) {
      statusColor = const Color(0xFF4CAF50);
      statusBgColor = const Color(0xFF1E3A33);
      statusText = 'Accepted';
      statusIcon = Icons.check_circle_outline;
    } else if (isRejected) {
      statusColor = const Color(0xFFF44336);
      statusBgColor = const Color(0xFF3F2B30);
      statusText = 'Rejected';
      statusIcon = Icons.close;
    } else {
      statusColor = AppColors.textSecondary;
      statusBgColor = AppColors.surface;
      statusText = 'Cancelled';
      statusIcon = Icons.cancel_outlined;
    }

    return InkWell(
      onTap: () async {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ReservationDetailScreen(event: reservation),
          ),
        );
        if (updated == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reservation updated successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      borderRadius: const BorderRadius.vertical(top: Radius.circular(100)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(100)),
          image: const DecorationImage(
            image: AssetImage('assets/restro-background.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(100)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            // Subtle dark overlay to ensure text contrast if the image is too bright
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Circle with Table Number
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: AssetImage('assets/cir-background.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      reservation.tableNumber != null
                          ? 'T${reservation.tableNumber!.toString().padLeft(2, '0')}'
                          : 'NA',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Info Rows
                _buildIconLabel(Icons.calendar_today, formattedDate),
                const SizedBox(height: 10),
                _buildIconLabel(Icons.access_time, formattedTime),
                const SizedBox(height: 10),
                _buildIconLabel(
                  Icons.table_restaurant,
                  'Table ${reservation.tableNumber ?? "N/A"}',
                ),
                const SizedBox(height: 10),
                _buildIconLabel(
                  Icons.people_outline,
                  '${reservation.numberOfGuests} Guests',
                ),
                const SizedBox(height: 20),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.15),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          statusText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCancelled || isRejected) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _deleteReservation(reservation),
                    icon: const Icon(
                      CupertinoIcons.delete,
                      size: 16,
                      color: Colors.white60,
                    ),
                    label: Text(
                      'Delete',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconLabel(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
              CupertinoIcons.calendar,
              size: iconSize,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            'No Upcoming Reservations',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            'Create your first reservation to get started',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: bodyFontSize,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 24 : 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddReservationScreen(),
                  ),
                );
                if (created == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reservation created successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 18 : 16,
                  horizontal: isTablet ? 24 : 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Create Reservation',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 18.0 : 16.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Table Booking Tab Content (extracted body from TableBookingsScreen)
class _TableBookingTabContent extends StatelessWidget {
  const _TableBookingTabContent();

  @override
  Widget build(BuildContext context) {
    return const TableBookingsScreen(skipScaffold: true);
  }
}
