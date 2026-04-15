// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/reservation_model.dart';
import '../../services/reservation_service.dart';

class ReservationRequestScreen extends StatefulWidget {
  const ReservationRequestScreen({super.key});

  @override
  State<ReservationRequestScreen> createState() =>
      _ReservationRequestScreenState();
}

class _ReservationRequestScreenState extends State<ReservationRequestScreen>
    with SingleTickerProviderStateMixin {
  final ReservationService _reservationService = ReservationService();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  late TabController _tabController;
  List<ReservationWithUser> _pendingReservations = [];
  List<ReservationWithUser> _confirmedReservations = [];
  List<ReservationWithUser> _rejectedReservations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final usersSnapshot = await _database.child('users').get();
      if (!usersSnapshot.exists || usersSnapshot.value == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final List<ReservationWithUser> allReservations = [];
      final usersData = usersSnapshot.value as Map<dynamic, dynamic>;

      for (final userEntry in usersData.entries) {
        final userId = userEntry.key.toString();
        final userData = userEntry.value;
        if (userData is Map && userData.containsKey('reservations')) {
          final reservationsData =
              userData['reservations'] as Map<dynamic, dynamic>?;
          if (reservationsData != null) {
            for (final reservationEntry in reservationsData.entries) {
              try {
                final reservation = ReservationModel.fromMap(
                  reservationEntry.key.toString(),
                  reservationEntry.value as Map<dynamic, dynamic>,
                );
                allReservations.add(
                  ReservationWithUser(reservation: reservation, userId: userId),
                );
              } catch (_) {
                // Skip invalid reservations
              }
            }
          }
        }
      }

      // Sort by date (newest first)
      allReservations.sort((a, b) {
        return b.reservation.reservationDate.compareTo(
          a.reservation.reservationDate,
        );
      });

      if (mounted) {
        setState(() {
          _pendingReservations = allReservations
              .where((r) => r.reservation.status == ReservationStatus.upcoming)
              .toList();
          _confirmedReservations = allReservations
              .where((r) => r.reservation.status == ReservationStatus.completed)
              .toList();
          _rejectedReservations = allReservations
              .where(
                (r) =>
                    r.reservation.status == ReservationStatus.cancelled ||
                    r.reservation.status == ReservationStatus.rejected,
              )
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateReservationStatus(
    ReservationWithUser reservationWithUser,
    ReservationStatus newStatus,
  ) async {
    try {
      final success = await _reservationService.updateReservationStatusForAdmin(
        userId: reservationWithUser.userId,
        reservationId: reservationWithUser.reservation.id!,
        status: newStatus,
      );

      if (success && mounted) {
        _showSnackBar(
          'Reservation ${_getStatusText(newStatus).toLowerCase()} successfully',
          backgroundColor: AppColors.success,
        );
        await _loadReservations();
      } else if (mounted) {
        _showSnackBar(
          'Failed to update reservation status',
          backgroundColor: AppColors.error,
        );
      }
    } catch (e) {
      debugPrint('Error updating reservation status: $e');
      if (mounted) {
        _showSnackBar(
          'Error updating reservation status',
          backgroundColor: AppColors.error,
        );
      }
    }
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = AppColors.error,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getStatusText(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.upcoming:
        return 'Pending';
      case ReservationStatus.completed:
        return 'Confirmed';
      case ReservationStatus.rejected:
        return 'Rejected';
      case ReservationStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getStatusColor(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.upcoming:
        return AppColors.warning;
      case ReservationStatus.completed:
        return AppColors.success;
      case ReservationStatus.rejected:
      case ReservationStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Reservation Requests',
          style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Rejected'),
          ],
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadReservations,
              color: AppColors.primary,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReservationsList(_pendingReservations),
                  _buildReservationsList(_confirmedReservations),
                  _buildReservationsList(_rejectedReservations),
                ],
              ),
            ),
    );
  }

  Widget _buildReservationsList(List<ReservationWithUser> reservations) {
    if (reservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No reservations found',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        return _buildReservationCard(reservations[index]);
      },
    );
  }

  Widget _buildReservationCard(ReservationWithUser reservationWithUser) {
    final reservation = reservationWithUser.reservation;
    final status = reservation.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        reservation.reservationName,
                        style: AppTextStyles.title.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Reservation Date: ',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDate(reservation.reservationDate),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Reservation details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Two-column layout: Left (Contact Person, Email, Phone) | Right (Number of Guests, Time)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.person,
                            'Contact Person',
                            reservation.contactPerson,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.email,
                            'Email',
                            reservation.email,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.phone,
                            'Phone',
                            reservation.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.people,
                            'Number of Guests',
                            '${reservation.numberOfGuests}',
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.access_time,
                            'Time',
                            _formatTime(reservation.startTime),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Additional fields below (full width)
                if (reservation.tableNumber != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.table_restaurant,
                    'Table Number',
                    'Table ${reservation.tableNumber}',
                  ),
                ],
                if (reservation.estimatedTotalCost > 0) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.attach_money,
                    'Estimated Cost',
                    'AED ${reservation.estimatedTotalCost.toStringAsFixed(2)}',
                  ),
                ],
                if (reservation.specialDietaryRequirements.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.restaurant,
                    'Dietary Requirements',
                    reservation.specialDietaryRequirements,
                  ),
                ],
              ],
            ),
          ),

          // Action buttons (only for pending reservations)
          if (status == ReservationStatus.upcoming)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateReservationStatus(
                        reservationWithUser,
                        ReservationStatus.completed,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateReservationStatus(
                        reservationWithUser,
                        ReservationStatus.rejected,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// Helper class to store reservation with its user ID
class ReservationWithUser {
  final ReservationModel reservation;
  final String userId;

  ReservationWithUser({required this.reservation, required this.userId});
}
