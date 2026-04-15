// ignore_for_file: empty_catches

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/bill_model.dart';

class BillService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Get current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Create bill
  Future<String?> createBill(BillModel bill) async {
    if (_userId == null || bill.orderId.isEmpty) {
      return null;
    }

    try {
      final billRef = _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .child(bill.orderId)
          .child('bills')
          .push();

      final billWithUserId = bill.copyWith(
        userId: _userId,
        billId: billRef.key,
      );

      await billRef.set(billWithUserId.toMap());
      return billRef.key;
    } catch (e) {
      return null;
    }
  }

  // Get bill by ID (requires orderId since bills are nested under orders)
  Future<BillModel?> getBill(String billId, String orderId) async {
    if (_userId == null || orderId.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .child(orderId)
          .child('bills')
          .child(billId)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return BillModel.fromMap(billId, data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get bill by order ID
  Future<BillModel?> getBillByOrderId(String orderId) async {
    if (_userId == null || orderId.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .child(orderId)
          .child('bills')
          .limitToFirst(1)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final entry = data.entries.first;
        return BillModel.fromMap(entry.key as String, entry.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get all bills (scans all orders for bills)
  Future<List<BillModel>> getAllBills() async {
    if (_userId == null) {
      return [];
    }

    try {
      final ordersSnapshot = await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .get();

      if (!ordersSnapshot.exists || ordersSnapshot.value == null) {
        return [];
      }

      final List<BillModel> allBills = [];
      final ordersData = ordersSnapshot.value as Map<dynamic, dynamic>;

      for (final orderEntry in ordersData.entries) {
        final orderData = orderEntry.value as Map<dynamic, dynamic>;
        if (orderData.containsKey('bills')) {
          final billsData = orderData['bills'] as Map<dynamic, dynamic>;
          for (final billEntry in billsData.entries) {
            try {
              allBills.add(BillModel.fromMap(
                billEntry.key as String,
                billEntry.value as Map<dynamic, dynamic>,
              ));
            } catch (e) {
              // Skip invalid bills
            }
          }
        }
      }

      return allBills;
    } catch (e) {
      return [];
    }
  }

  // Update bill
  Future<bool> updateBill(BillModel bill) async {
    if (_userId == null || bill.billId == null || bill.orderId.isEmpty) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .child(bill.orderId)
          .child('bills')
          .child(bill.billId!)
          .update(bill.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete bill (requires orderId since bills are nested under orders)
  Future<bool> deleteBill(String billId, String orderId) async {
    if (_userId == null || orderId.isEmpty) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(_userId!)
          .child('orders')
          .child(orderId)
          .child('bills')
          .child(billId)
          .remove();
      return true;
    } catch (e) {
      return false;
    }
  }
}

