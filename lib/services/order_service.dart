// ignore_for_file: empty_catches

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import 'orders_result.dart';

class OrderService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Get current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Create a new order
  Future<String?> createOrder(OrderModel order) async {
    if (_userId == null) {
      return null;
    }

    try {
      final orderRef = _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .push();

      // Initialize KOT count history with initial item count
      final initialKOTHistory = order.items.isNotEmpty
          ? [order.items.length]
          : null;

      final orderWithUserId = order.copyWith(
        userId: _userId,
        orderId: orderRef.key,
        kotCountHistory: initialKOTHistory,
      );

      await orderRef.set(orderWithUserId.toMap());
      return orderRef.key;
    } catch (e) {
      return null;
    }
  }

  // Get order by ID
  Future<OrderModel?> getOrder(String orderId) async {
    if (_userId == null) {
      return null;
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .child(orderId)
          .get();

      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      return OrderModel.fromMap(orderId, data);
    } catch (e) {
      return null;
    }
  }

  // Get all orders stream (real-time updates)
  Stream<List<OrderModel>> getOrdersStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _database.child('users').child(_userId!).child('orders').onValue.map(
      (event) {
        final data = event.snapshot.value;
        if (data == null) {
          return <OrderModel>[];
        }

        final List<OrderModel> orders = [];
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                orders.add(OrderModel.fromMap(key.toString(), value));
              } catch (e) {
                // Skip invalid orders
              }
            }
          });
        }
        return orders;
      },
    );
  }

  // Get all orders
  Future<List<OrderModel>> getOrders() async {
    if (_userId == null) {
      return [];
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .get();

      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.value;
      if (data == null) {
        return [];
      }

      final List<OrderModel> orders = [];
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              orders.add(OrderModel.fromMap(key.toString(), value));
            } catch (e) {
              // Skip invalid orders
            }
          }
        });
      }
      return orders;
    } catch (e) {
      return [];
    }
  }

  // Get active orders for a table
  Future<List<OrderModel>> getActiveOrdersForTable(int tableNumber) async {
    final allOrders = await getOrders();
    return allOrders.where((order) {
      return order.tableNumber == tableNumber &&
          (order.status == OrderStatus.pending ||
              order.status == OrderStatus.active);
    }).toList();
  }

  // Update order status
  Future<bool> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    if (_userId == null) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .child(orderId)
          .update({
            'status': statusToString(status),
            'updatedAt': DateTime.now().toIso8601String(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update order
  Future<bool> updateOrder(OrderModel order) async {
    if (_userId == null || order.orderId == null) {
      return false;
    }

    try {
      // Get existing order to check KOT count history
      final existingOrder = await getOrder(order.orderId!);
      List<int>? updatedKOTHistory;

      if (existingOrder != null) {
        final existingHistory = existingOrder.kotCountHistory;
        final existingItemCount = existingOrder.items.length;
        final newItemCount = order.items.length;

        if (existingHistory != null && existingHistory.isNotEmpty) {
          // Order has existing history
          if (newItemCount > existingItemCount) {
            // Items were added - append new count to history
            updatedKOTHistory = List<int>.from(existingHistory)
              ..add(newItemCount);
          } else if (newItemCount < existingItemCount) {
            // Items were removed - reset history
            updatedKOTHistory = newItemCount > 0 ? [newItemCount] : null;
          } else {
            // Item count unchanged - keep existing history
            updatedKOTHistory = existingHistory;
          }
        } else {
          // No existing history - initialize with current count
          updatedKOTHistory = newItemCount > 0 ? [newItemCount] : null;
        }
      } else {
        // Order doesn't exist yet - initialize with current count
        updatedKOTHistory = order.items.isNotEmpty
            ? [order.items.length]
            : null;
      }

      final updatedOrder = order.copyWith(
        updatedAt: DateTime.now(),
        kotCountHistory: updatedKOTHistory,
      );

      await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .child(order.orderId!)
          .update(updatedOrder.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete order
  Future<bool> deleteOrder(String orderId) async {
    if (_userId == null) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .child(orderId)
          .remove();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get orders by status
  Future<List<OrderModel>> getOrdersByStatus(OrderStatus status) async {
    final allOrders = await getOrders();
    return allOrders.where((order) => order.status == status).toList();
  }

  // Get orders by date range
  Future<List<OrderModel>> getOrdersByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final allOrders = await getOrders();
    return allOrders.where((order) {
      return order.createdAt.isAfter(startDate) &&
          order.createdAt.isBefore(endDate);
    }).toList();
  }

  // Get orders with reservations for today
  Future<List<OrderModel>> getTodaysReservations() async {
    final allOrders = await getOrders();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return allOrders.where((order) {
      // Check if reservation time is today
      final reservationDate = DateTime(
        order.reservationTime.year,
        order.reservationTime.month,
        order.reservationTime.day,
      );

      // Also check status - exclude cancelled and completed orders
      final isActive =
          order.status != OrderStatus.cancelled &&
          order.status != OrderStatus.completed;

      return reservationDate.isAtSameMomentAs(todayStart) && isActive;
    }).toList();
  }

  // Get booked time slots for today (optionally for a specific table)
  Future<List<TimeOfDay>> getBookedTimeSlots({int? tableNumber}) async {
    final reservations = await getTodaysReservations();
    final bookedSlots = <TimeOfDay>[];

    for (final order in reservations) {
      // If tableNumber is provided, only check reservations for that table
      if (tableNumber != null && order.tableNumber != tableNumber) {
        continue;
      }

      final reservationTime = order.reservationTime;
      bookedSlots.add(
        TimeOfDay(hour: reservationTime.hour, minute: reservationTime.minute),
      );
    }

    return bookedSlots;
  }

  // Check if a time slot is available for today
  Future<bool> isTimeSlotAvailable(
    TimeOfDay timeSlot, {
    int? tableNumber,
    String? excludeOrderId,
  }) async {
    final bookedSlots = await getBookedTimeSlots(tableNumber: tableNumber);

    // Check if any booked slot matches this time slot (considering 30-minute buffer)
    for (final bookedSlot in bookedSlots) {
      // If checking availability for an existing order, exclude that order
      if (excludeOrderId != null) {
        final reservations = await getTodaysReservations();
        final hasMatchingOrder = reservations.any(
          (order) =>
              order.orderId == excludeOrderId &&
              order.reservationTime.hour == bookedSlot.hour &&
              order.reservationTime.minute == bookedSlot.minute,
        );
        if (hasMatchingOrder) {
          continue;
        }
      }

      // Check if times are within 30 minutes of each other (to prevent overlapping reservations)
      final timeSlotMinutes = timeSlot.hour * 60 + timeSlot.minute;
      final bookedMinutes = bookedSlot.hour * 60 + bookedSlot.minute;
      final timeDifference = (timeSlotMinutes - bookedMinutes).abs();

      if (timeDifference < 30) {
        return false; // Slot is booked or too close to another reservation
      }
    }

    return true; // Slot is available
  }

  // Get all orders from all non-admin users (for admin view) - Future version
  Future<List<OrderModel>> getAllNonAdminOrders() async {
    final result = await getAllNonAdminOrdersWithNames();
    return result.orders;
  }

  // Optimized method to get orders and names in one go
  Future<OrdersWithNames> getAllNonAdminOrdersWithNames() async {
    try {
      // Single DB call to get all users
      final usersSnapshot = await _database.child('users').get();

      if (!usersSnapshot.exists || usersSnapshot.value == null) {
        return OrdersWithNames([], {});
      }

      final users = usersSnapshot.value as Map<dynamic, dynamic>;
      final List<OrderModel> allOrders = [];
      final Map<String, String> names = {};

      for (final entry in users.entries) {
        final userId = entry.key as String;
        final userData = entry.value;

        if (userData is! Map) continue;

        // Check if admin
        bool isAdmin = false;
        final profile = userData['profile'];
        if (profile is Map) {
          final email = profile['email'];
          if (email == 'test-admin@gmail.com') {
            isAdmin = true;
          } else {
            // Capture name
            final name = profile['name'];
            if (name != null) {
              names[userId] = name.toString();
            }
          }
        }

        if (isAdmin) continue;

        // Process orders
        final ordersData = userData['orders'];
        if (ordersData is Map) {
          ordersData.forEach((orderId, orderValue) {
            if (orderValue is Map) {
              try {
                final order = OrderModel.fromMap(
                  orderId.toString(),
                  orderValue,
                );
                // Ensure userId is set on the order object from the parent key
                // if it wasn't saved correctly in the order itself
                if (order.userId == null || order.userId != userId) {
                  allOrders.add(order.copyWith(userId: userId));
                } else {
                  allOrders.add(order);
                }
              } catch (e) {
                // Skip invalid
              }
            }
          });
        }
      }

      return OrdersWithNames(allOrders, names);
    } catch (e) {
      debugPrint('Error fetching all orders: $e');
      return OrdersWithNames([], {});
    }
  }

  // Update order status for a specific user (for admin use)
  Future<bool> updateOrderStatusForUser({
    required String userId,
    required String orderId,
    required OrderStatus status,
  }) async {
    if (_userId == null) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(userId)
          .child('orders')
          .child(orderId)
          .update({
            'status': statusToString(status),
            'updatedAt': DateTime.now().toIso8601String(),
          });
      return true;
    } catch (e) {
      debugPrint('Error updating order status for user: $e');
      return false;
    }
  }

  // Get user name by userId
  Future<String?> getUserName(String userId) async {
    try {
      final snapshot = await _database
          .child('users')
          .child(userId)
          .child('profile')
          .child('name')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        return snapshot.value.toString();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user name for $userId: $e');
      return null;
    }
  }

  // Get user names for multiple userIds
  Future<Map<String, String>> getUserNames(List<String> userIds) async {
    // Remove duplicates
    final uniqueUserIds = userIds.toSet().toList();

    // Fetch names in parallel
    final results = await Future.wait(
      uniqueUserIds.map((userId) async {
        final name = await getUserName(userId);
        return MapEntry(userId, name);
      }),
    );

    // Build map from results
    final Map<String, String> userNamesMap = {};
    for (final entry in results) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        userNamesMap[entry.key] = entry.value!;
      }
    }

    return userNamesMap;
  }
}
