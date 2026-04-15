// ignore_for_file: empty_catches

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

enum TableStatus { available, occupied, reserved }

class TableService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Convert string to TableStatus
  TableStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
        return TableStatus.occupied;
      case 'reserved':
        return TableStatus.reserved;
      case 'available':
      default:
        return TableStatus.available;
    }
  }

  // Convert TableStatus to string
  String _statusToString(TableStatus status) {
    switch (status) {
      case TableStatus.occupied:
        return 'occupied';
      case TableStatus.reserved:
        return 'reserved';
      case TableStatus.available:
        return 'available';
    }
  }

  // Get current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Get tables stream for real-time updates
  Stream<Map<int, TableStatus>> getTablesStream() {
    if (_userId == null) {
      return Stream.value({});
    }

    return _database.child('users').child(_userId!).child('tables').onValue.map(
      (event) {
        final data = event.snapshot.value;
        if (data == null) {
          return <int, TableStatus>{};
        }

        final Map<int, TableStatus> tables = {};
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              final tableNumber = int.tryParse(key.toString());
              final statusStr = value['status']?.toString() ?? 'available';
              if (tableNumber != null) {
                tables[tableNumber] = _statusFromString(statusStr);
              }
            }
          });
        }
        return tables;
      },
    );
  }

  // Get all tables
  Future<Map<int, TableStatus>> getTables() async {
    if (_userId == null) {
      return {};
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(_userId!)
          .child('tables')
          .get();

      if (!snapshot.exists) {
        return {};
      }

      final data = snapshot.value;
      if (data == null) {
        return {};
      }

      final Map<int, TableStatus> tables = {};
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final tableNumber = int.tryParse(key.toString());
            final statusStr = value['status']?.toString() ?? 'available';
            if (tableNumber != null) {
              tables[tableNumber] = _statusFromString(statusStr);
            }
          }
        });
      }
      return tables;
    } catch (e) {
      return {};
    }
  }

  // Get total number of tables
  Future<int> getTotalTables() async {
    if (_userId == null) {
      return 0;
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(_userId!)
          .child('settings')
          .child('totalTables')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        return int.tryParse(snapshot.value.toString()) ?? 12;
      }
      return 12; // Default
    } catch (e) {
      return 12; // Default
    }
  }

  // Update table status
  Future<bool> updateTableStatus({
    required int tableNumber,
    required TableStatus status,
  }) async {
    if (_userId == null) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(_userId!)
          .child('tables')
          .child(tableNumber.toString())
          .set({
            'status': _statusToString(status),
            'updatedAt': DateTime.now().toIso8601String(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Initialize tables (create default tables if they don't exist)
  Future<void> initializeTables({int totalTables = 12}) async {
    if (_userId == null) {
      return;
    }

    try {
      // Save total tables count
      await _database
          .child('users')
          .child(_userId!)
          .child('settings')
          .child('totalTables')
          .set(totalTables);

      // Check if tables already exist
      final snapshot = await _database
          .child('users')
          .child(_userId!)
          .child('tables')
          .get();

      if (!snapshot.exists) {
        // Create default tables (all available)
        final Map<String, dynamic> tables = {};
        for (int i = 1; i <= totalTables; i++) {
          tables[i.toString()] = {
            'status': 'available',
            'createdAt': DateTime.now().toIso8601String(),
          };
        }
        await _database
            .child('users')
            .child(_userId!)
            .child('tables')
            .set(tables);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Set total number of tables
  Future<bool> setTotalTables(int totalTables) async {
    if (_userId == null) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(_userId!)
          .child('settings')
          .child('totalTables')
          .set(totalTables);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<int, List<TimeOfDay>>> getTodayBookings() async {
    final userId = _userId;
    if (userId == null) {
      return {};
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(userId)
          .child('orders')
          .get();

      if (!snapshot.exists) {
        return {};
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final Map<int, List<TimeOfDay>> bookings = {};

      if (snapshot.value is Map) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final tableNumber = value['tableNumber'] as int?;
            final status = value['status']?.toString();
            final reservationTimeStr = value['reservationTime']?.toString();

            if (tableNumber == null || reservationTimeStr == null) {
              return;
            }

            final reservationTime = DateTime.tryParse(reservationTimeStr);
            if (reservationTime == null) {
              return;
            }

            if (reservationTime.isBefore(todayStart) ||
                reservationTime.isAfter(todayEnd)) {
              return;
            }

            if (status == 'completed' || status == 'cancelled') {
              return;
            }

            bookings
                .putIfAbsent(tableNumber, () => [])
                .add(
                  TimeOfDay(
                    hour: reservationTime.hour,
                    minute: reservationTime.minute,
                  ),
                );
          }
        });
      }

      return bookings;
    } catch (e) {
      return {};
    }
  }
}
