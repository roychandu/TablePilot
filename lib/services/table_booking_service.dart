// ignore_for_file: empty_catches

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/table_booking_model.dart';

class TableBookingService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  DatabaseReference? get _bookingsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _database.child('users').child(uid).child('tableBookings');
  }

  // Create a new table booking
  Future<String?> createTableBooking(TableBookingModel booking) async {
    final ref = _bookingsRef;
    if (ref == null) return null;

    // Validate that table number is provided (required for simplified form)
    if (booking.tableNumber == null) {
      return null;
    }

    try {
      final newRef = ref.push();
      final bookingWithUserId = booking.copyWith(
        id: newRef.key,
        userId: _userId,
      );
      await newRef.set(bookingWithUserId.toMap());
      return newRef.key;
    } catch (_) {
      return null;
    }
  }

  // Get all table bookings stream (real-time updates)
  Stream<List<TableBookingModel>> getTableBookingsStream() {
    final ref = _bookingsRef;
    if (ref == null) {
      return Stream<List<TableBookingModel>>.value(
        const [],
      ).asBroadcastStream();
    }

    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) {
        return <TableBookingModel>[];
      }
      final List<TableBookingModel> bookingsList = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            bookingsList.add(TableBookingModel.fromMap(key.toString(), value));
          } catch (_) {}
        }
      });
      return bookingsList;
    }).asBroadcastStream();
  }

  // Get all table bookings
  Future<List<TableBookingModel>> getTableBookings() async {
    final ref = _bookingsRef;
    if (ref == null) return [];

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) return [];
      final data = snapshot.value;
      if (data == null || data is! Map) return [];

      final List<TableBookingModel> bookingsList = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            bookingsList.add(TableBookingModel.fromMap(key.toString(), value));
          } catch (_) {}
        }
      });
      return bookingsList;
    } catch (_) {
      return [];
    }
  }

  // Get table booking by ID
  Future<TableBookingModel?> getTableBooking(String bookingId) async {
    final ref = _bookingsRef;
    if (ref == null) return null;

    try {
      final snapshot = await ref.child(bookingId).get();
      if (!snapshot.exists) return null;

      final data = snapshot.value as Map<dynamic, dynamic>;
      return TableBookingModel.fromMap(bookingId, data);
    } catch (_) {
      return null;
    }
  }

  // Update table booking
  Future<bool> updateTableBooking(TableBookingModel booking) async {
    final ref = _bookingsRef;
    if (ref == null || booking.id == null) return false;

    try {
      final bookingWithUpdate = booking.copyWith(updatedAt: DateTime.now());
      await ref.child(booking.id!).update(bookingWithUpdate.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  // Delete table booking
  Future<bool> deleteTableBooking(String bookingId) async {
    final ref = _bookingsRef;
    if (ref == null) return false;

    try {
      await ref.child(bookingId).remove();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Update table booking status
  Future<bool> updateTableBookingStatus({
    required String bookingId,
    required TableBookingStatus status,
  }) async {
    final ref = _bookingsRef;
    if (ref == null) return false;

    try {
      await ref.child(bookingId).update({
        'status': tableBookingStatusToString(status),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // Get today's bookings
  Future<List<TableBookingModel>> getTodayBookings() async {
    final allBookings = await getTableBookings();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return allBookings.where((booking) {
      final bookingDateTime = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
        booking.bookingTime.hour,
        booking.bookingTime.minute,
      );
      return bookingDateTime.isAfter(todayStart) &&
          bookingDateTime.isBefore(todayEnd) &&
          booking.status != TableBookingStatus.cancelled;
    }).toList();
  }

  // Get currently seated bookings
  Future<List<TableBookingModel>> getCurrentlySeatedBookings() async {
    final allBookings = await getTableBookings();
    return allBookings
        .where((booking) => booking.status == TableBookingStatus.seated)
        .toList();
  }

  // Get bookings by table number
  Future<List<TableBookingModel>> getBookingsByTable(int tableNumber) async {
    final allBookings = await getTableBookings();
    return allBookings
        .where((booking) => booking.tableNumber == tableNumber)
        .toList();
  }

  // Get bookings by date and table number
  Future<List<TableBookingModel>> getBookingsByDateAndTable({
    required DateTime date,
    required int tableNumber,
  }) async {
    final allBookings = await getTableBookings();
    final dateOnly = DateTime(date.year, date.month, date.day);

    return allBookings.where((booking) {
      final bookingDateOnly = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
      );
      return bookingDateOnly.isAtSameMomentAs(dateOnly) &&
          booking.tableNumber == tableNumber &&
          booking.status != TableBookingStatus.cancelled;
    }).toList();
  }

  // Get active bookings for a table (excludes cancelled and completed)
  Future<List<TableBookingModel>> getActiveBookingsByTable(
    int tableNumber,
  ) async {
    final allBookings = await getTableBookings();
    final now = DateTime.now();

    return allBookings.where((booking) {
      if (booking.tableNumber != tableNumber) return false;
      if (booking.status == TableBookingStatus.cancelled) return false;

      // Only include future bookings or bookings for today
      final bookingDateTime = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
        booking.bookingTime.hour,
        booking.bookingTime.minute,
      );

      return bookingDateTime.isAfter(
            now.subtract(const Duration(minutes: 1)),
          ) ||
          bookingDateTime.isAtSameMomentAs(
            DateTime(now.year, now.month, now.day),
          );
    }).toList();
  }

  // Check if table has any active bookings
  Future<bool> hasActiveBookings(int tableNumber) async {
    final activeBookings = await getActiveBookingsByTable(tableNumber);
    return activeBookings.isNotEmpty;
  }

  // Get table status based on bookings
  Future<TableBookingStatus?> getTableStatus(int tableNumber) async {
    final activeBookings = await getActiveBookingsByTable(tableNumber);
    if (activeBookings.isEmpty) return null;

    // Prioritize seated status, then confirmed
    for (final booking in activeBookings) {
      if (booking.status == TableBookingStatus.seated) {
        return TableBookingStatus.seated;
      }
    }
    for (final booking in activeBookings) {
      if (booking.status == TableBookingStatus.confirmed) {
        return TableBookingStatus.confirmed;
      }
    }
    return activeBookings.first.status;
  }
}
