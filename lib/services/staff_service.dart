import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/staff_model.dart';

class StaffService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  DatabaseReference? get _staffRef {
    final uid = _userId;
    if (uid == null) return null;
    return _database.child('users').child(uid).child('staff');
  }

  Future<String?> createStaff(StaffModel staff) async {
    final ref = _staffRef;
    if (ref == null) return null;

    try {
      final newRef = ref.push();
      await newRef.set(staff.toMap());
      return newRef.key;
    } catch (_) {
      return null;
    }
  }

  Stream<List<StaffModel>> getStaffStream() {
    final ref = _staffRef;
    if (ref == null) {
      return Stream.value(const []);
    }

    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) {
        return <StaffModel>[];
      }
      final List<StaffModel> staffList = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            staffList.add(StaffModel.fromMap(key.toString(), value));
          } catch (_) {}
        }
      });
      return staffList;
    });
  }

  Future<List<StaffModel>> getStaff() async {
    final ref = _staffRef;
    if (ref == null) return [];

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) return [];
      final data = snapshot.value;
      if (data == null || data is! Map) return [];

      final List<StaffModel> staffList = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            staffList.add(StaffModel.fromMap(key.toString(), value));
          } catch (_) {}
        }
      });
      return staffList;
    } catch (_) {
      return [];
    }
  }

  Future<bool> updateStaff(StaffModel staff) async {
    final ref = _staffRef;
    if (ref == null || staff.id == null) return false;

    try {
      await ref.child(staff.id!).update(staff.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateInFloor(String staffId, bool inFloor) async {
    final ref = _staffRef;
    if (ref == null) return false;

    try {
      await ref.child(staffId).update({'inFloor': inFloor});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStaff(String staffId) async {
    final ref = _staffRef;
    if (ref == null) return false;

    try {
      await ref.child(staffId).remove();
      return true;
    } catch (_) {
      return false;
    }
  }
}


