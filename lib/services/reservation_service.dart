import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/reservation_model.dart';

class ReservationService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  DatabaseReference? get _reservationsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _database.child('users').child(uid).child('reservations');
  }

  Future<String?> createReservation(ReservationModel reservation) async {
    final ref = _reservationsRef;
    if (ref == null) return null;

    try {
      final newRef = ref.push();
      // Trust the estimatedTotalCost coming from the UI if provided,
      // otherwise fall back to computing it from the model.
      final reservationWithCost = reservation.copyWith(
        id: newRef.key,
        estimatedTotalCost: reservation.estimatedTotalCost != 0.0
            ? reservation.estimatedTotalCost
            : reservation.totalCost,
      );
      await newRef.set(reservationWithCost.toMap());
      return newRef.key;
    } catch (_) {
      return null;
    }
  }

  Stream<List<ReservationModel>> getReservationsStream() {
    final ref = _reservationsRef;
    if (ref == null) {
      return Stream<List<ReservationModel>>.value(const []).asBroadcastStream();
    }

    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) {
        return <ReservationModel>[];
      }
      final List<ReservationModel> reservationsList = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            reservationsList.add(
              ReservationModel.fromMap(key.toString(), value),
            );
          } catch (_) {}
        }
      });
      return reservationsList;
    }).asBroadcastStream();
  }

  Future<List<ReservationModel>> getReservations() async {
    final ref = _reservationsRef;
    if (ref == null) return [];

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) return [];
      final data = snapshot.value;
      if (data == null || data is! Map) return [];

      final List<ReservationModel> reservationsList = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            reservationsList.add(
              ReservationModel.fromMap(key.toString(), value),
            );
          } catch (_) {}
        }
      });
      return reservationsList;
    } catch (_) {
      return [];
    }
  }

  Future<ReservationModel?> getReservation(String reservationId) async {
    final ref = _reservationsRef;
    if (ref == null) return null;

    try {
      final snapshot = await ref.child(reservationId).get();
      if (!snapshot.exists) return null;

      final data = snapshot.value as Map<dynamic, dynamic>;
      return ReservationModel.fromMap(reservationId, data);
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateReservation(ReservationModel reservation) async {
    final ref = _reservationsRef;
    if (ref == null || reservation.id == null) return false;

    try {
      // Preserve all reservation properties including status.
      // Prefer the estimatedTotalCost coming from the caller; if it's zero,
      // fall back to computing it from the current reservation data.
      final reservationWithCost = reservation.copyWith(
        estimatedTotalCost: reservation.estimatedTotalCost != 0.0
            ? reservation.estimatedTotalCost
            : reservation.totalCost,
        updatedAt: DateTime.now(),
      );
      final reservationMap = reservationWithCost.toMap();
      await ref.child(reservation.id!).update(reservationMap);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteReservation(String reservationId) async {
    final ref = _reservationsRef;
    if (ref == null) return false;

    try {
      await ref.child(reservationId).remove();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateReservationStatus({
    required String reservationId,
    required ReservationStatus status,
  }) async {
    final ref = _reservationsRef;
    if (ref == null) return false;

    try {
      await ref.child(reservationId).update({
        'status': reservationStatusToString(status),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // Get upcoming reservations
  Future<List<ReservationModel>> getUpcomingReservations() async {
    final allReservations = await getReservations();
    final now = DateTime.now();
    return allReservations.where((reservation) {
      return reservation.status == ReservationStatus.upcoming &&
          reservation.reservationDate.isAfter(now);
    }).toList();
  }

  // Get completed reservations
  Future<List<ReservationModel>> getCompletedReservations() async {
    final allReservations = await getReservations();
    return allReservations
        .where(
          (reservation) => reservation.status == ReservationStatus.completed,
        )
        .toList();
  }

  // Get statistics
  Future<Map<String, dynamic>> getReservationStatistics() async {
    final allReservations = await getReservations();
    final now = DateTime.now();

    final upcomingCount = allReservations.where((reservation) {
      return reservation.status == ReservationStatus.upcoming &&
          reservation.reservationDate.isAfter(now);
    }).length;

    final totalGuests = allReservations.fold<int>(
      0,
      (sum, reservation) => sum + reservation.numberOfGuests,
    );

    final totalRevenue = allReservations.fold<double>(
      0.0,
      (sum, reservation) => sum + reservation.estimatedTotalCost,
    );

    return {
      'upcomingReservations': upcomingCount,
      'totalGuests': totalGuests,
      'totalRevenue': totalRevenue,
    };
  }

  // Get reservations by table number
  Future<List<ReservationModel>> getReservationsByTable(int tableNumber) async {
    final allReservations = await getReservations();
    return allReservations.where((reservation) {
      return reservation.tableNumber == tableNumber &&
          reservation.status != ReservationStatus.cancelled;
    }).toList();
  }

  // Get reservations by date and table
  Future<List<ReservationModel>> getReservationsByDateAndTable({
    required DateTime date,
    required int tableNumber,
  }) async {
    final allReservations = await getReservations();
    final dateOnly = DateTime(date.year, date.month, date.day);

    return allReservations.where((reservation) {
      final reservationDate = DateTime(
        reservation.reservationDate.year,
        reservation.reservationDate.month,
        reservation.reservationDate.day,
      );
      final matchesDate = reservationDate.isAtSameMomentAs(dateOnly);
      final matchesTable = reservation.tableNumber == tableNumber;
      final isActive =
          reservation.status != ReservationStatus.cancelled &&
          reservation.status != ReservationStatus.completed;

      return matchesDate && matchesTable && isActive;
    }).toList();
  }

  // Get all reservations from all users (for admin)
  Future<List<ReservationModel>> getAllReservationsForAdmin() async {
    try {
      final usersSnapshot = await _database.child('users').get();
      if (!usersSnapshot.exists || usersSnapshot.value == null) {
        return [];
      }

      final List<ReservationModel> allReservations = [];
      final usersData = usersSnapshot.value as Map<dynamic, dynamic>;

      for (final userEntry in usersData.entries) {
        final userData = userEntry.value;
        if (userData is Map && userData.containsKey('reservations')) {
          final reservationsData = userData['reservations'];
          if (reservationsData is Map) {
            for (final reservationEntry in reservationsData.entries) {
              try {
                final reservation = ReservationModel.fromMap(
                  reservationEntry.key.toString(),
                  reservationEntry.value as Map<dynamic, dynamic>,
                );
                allReservations.add(reservation);
              } catch (_) {
                // Skip invalid reservations
              }
            }
          }
        }
      }

      return allReservations;
    } catch (_) {
      return [];
    }
  }

  // Stream all reservations from all users (for admin)
  Stream<List<ReservationModel>> getAllReservationsStreamForAdmin() {
    try {
      return _database.child('users').onValue.map((event) {
        final data = event.snapshot.value;
        if (data == null || data is! Map) {
          return <ReservationModel>[];
        }

        final List<ReservationModel> allReservations = [];
        final usersData = data;

        for (final userEntry in usersData.entries) {
          final userData = userEntry.value;
          if (userData is Map && userData.containsKey('reservations')) {
            final reservationsData = userData['reservations'];
            if (reservationsData is Map) {
              for (final reservationEntry in reservationsData.entries) {
                try {
                  final reservation = ReservationModel.fromMap(
                    reservationEntry.key.toString(),
                    reservationEntry.value as Map<dynamic, dynamic>,
                  );
                  allReservations.add(reservation);
                } catch (_) {
                  // Skip invalid reservations
                }
              }
            }
          }
        }

        return allReservations;
      }).asBroadcastStream();
    } catch (_) {
      return Stream<List<ReservationModel>>.value(const []).asBroadcastStream();
    }
  }

  // Update reservation status for any user (admin use)
  // Used for approving/rejecting reservations
  Future<bool> updateReservationStatusForAdmin({
    required String userId,
    required String reservationId,
    required ReservationStatus status,
  }) async {
    try {
      await _database
          .child('users')
          .child(userId)
          .child('reservations')
          .child(reservationId)
          .update({
            'status': reservationStatusToString(status),
            'updatedAt': DateTime.now().toIso8601String(),
          });
      return true;
    } catch (_) {
      return false;
    }
  }

  // Confirm a reservation (admin action)
  // Sets status to completed (Confirmed)
  Future<bool> confirmReservation({
    required String reservationId,
    required String userId,
  }) async {
    return await updateReservationStatusForAdmin(
      userId: userId,
      reservationId: reservationId,
      status: ReservationStatus.completed,
    );
  }

  // Reject a reservation (admin action)
  // Sets status to cancelled (Rejected)
  Future<bool> rejectReservation({
    required String reservationId,
    required String userId,
  }) async {
    return await updateReservationStatusForAdmin(
      userId: userId,
      reservationId: reservationId,
      status: ReservationStatus.rejected,
    );
  }

  // Get pending reservations count (for admin dashboard)
  // Returns count of reservations with upcoming status (Pending)
  Future<int> getPendingReservationsCount() async {
    try {
      final reservations = await getAllReservationsForAdmin();
      return reservations
          .where((r) => r.status == ReservationStatus.upcoming)
          .length;
    } catch (_) {
      return 0;
    }
  }
}
