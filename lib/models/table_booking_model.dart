import 'package:flutter/material.dart';
import 'reservation_model.dart';
import '../common_widgets/app_colors.dart';

enum TableBookingStatus { confirmed, seated, cleaning, completed, cancelled }

String tableBookingStatusToString(TableBookingStatus status) {
  switch (status) {
    case TableBookingStatus.confirmed:
      return 'confirmed';
    case TableBookingStatus.seated:
      return 'seated';
    case TableBookingStatus.cleaning:
      return 'cleaning';
    case TableBookingStatus.completed:
      return 'completed';
    case TableBookingStatus.cancelled:
      return 'cancelled';
  }
}

TableBookingStatus stringToTableBookingStatus(String status) {
  switch (status.toLowerCase()) {
    case 'seated':
      return TableBookingStatus.seated;
    case 'cleaning':
      return TableBookingStatus.cleaning;
    case 'completed':
      return TableBookingStatus.completed;
    case 'cancelled':
      return TableBookingStatus.cancelled;
    case 'confirmed':
    default:
      return TableBookingStatus.confirmed;
  }
}

// Get display text for status (matching UI display logic)
String getTableBookingStatusDisplayText(TableBookingStatus status) {
  switch (status) {
    case TableBookingStatus.seated:
      return 'Occupied';
    case TableBookingStatus.confirmed:
      return 'Reserved';
    case TableBookingStatus.cleaning:
      return 'Cleaning';
    case TableBookingStatus.completed:
      return 'Completed';
    case TableBookingStatus.cancelled:
      return 'Available';
  }
}

// Get display color for status (matching UI display logic)
Color getTableBookingStatusDisplayColor(TableBookingStatus status) {
  switch (status) {
    case TableBookingStatus.seated:
      return AppColors.error; // Red for Occupied
    case TableBookingStatus.confirmed:
      return AppColors.warning; // Orange for Reserved
    case TableBookingStatus.cleaning:
      return AppColors.info; // Blue for Cleaning
    case TableBookingStatus.completed:
      return AppColors.success; // Green for Completed
    case TableBookingStatus.cancelled:
      return AppColors.success; // Green for Available
  }
}

class TableBookingModel {
  final String? id;
  final String? guestName; // Optional - not collected in simplified form
  final String? phoneNumber; // Optional - not collected in simplified form
  final String? email; // Optional
  final DateTime bookingDate;
  final TimeOfDay bookingTime;
  final int numberOfGuests;
  final double durationHours; // 1, 1.5, 2, 2.5, 3, 3.5, 4
  final String floor;
  final int? tableNumber; // Table number (1-20)
  final String? specialPreferences;
  final List<ReservationMenuItem> menuItems; // Selected menu items
  final TableBookingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? userId;
  final List<String> assignedStaffIds;

  TableBookingModel({
    this.id,
    this.guestName,
    this.phoneNumber,
    this.email,
    required this.bookingDate,
    required this.bookingTime,
    required this.numberOfGuests,
    required this.durationHours,
    required this.floor,
    this.tableNumber,
    this.specialPreferences,
    this.menuItems = const [],
    this.status = TableBookingStatus.confirmed,
    DateTime? createdAt,
    this.updatedAt,
    this.userId,
    this.assignedStaffIds = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'guestName': guestName,
      'phoneNumber': phoneNumber,
      'email': email,
      'bookingDate': bookingDate.toIso8601String(),
      'bookingTime':
          '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}',
      'numberOfGuests': numberOfGuests,
      'durationHours': durationHours,
      'floor': floor,
      'tableNumber': tableNumber,
      'specialPreferences': specialPreferences,
      'menuItems': menuItems.map((item) => item.toMap()).toList(),
      'status': tableBookingStatusToString(status),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'userId': userId,
      'assignedStaffIds': assignedStaffIds,
    };
  }

  // Create from Map (from Firebase)
  factory TableBookingModel.fromMap(String id, Map<dynamic, dynamic> map) {
    // Parse booking time
    final timeStr = map['bookingTime'] as String? ?? '00:00';
    final timeParts = timeStr.split(':');
    final bookingTime = TimeOfDay(
      hour: int.tryParse(timeParts[0]) ?? 0,
      minute: int.tryParse(timeParts[1]) ?? 0,
    );

    return TableBookingModel(
      id: id,
      guestName: map['guestName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      email: map['email'] as String?,
      bookingDate:
          DateTime.tryParse(map['bookingDate'] as String? ?? '') ??
          DateTime.now(),
      bookingTime: bookingTime,
      numberOfGuests: map['numberOfGuests'] as int? ?? 1,
      durationHours: (map['durationHours'] as num?)?.toDouble() ?? 2.0,
      floor: map['floor'] as String? ?? '',
      tableNumber: map['tableNumber'] as int?,
      specialPreferences: map['specialPreferences'] as String?,
      menuItems:
          (map['menuItems'] as List<dynamic>?)
              ?.map(
                (item) =>
                    ReservationMenuItem.fromMap(item as Map<dynamic, dynamic>),
              )
              .toList() ??
          [],
      status: stringToTableBookingStatus(
        map['status'] as String? ?? 'confirmed',
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
      userId: map['userId'] as String?,
      assignedStaffIds:
          (map['assignedStaffIds'] as List<dynamic>?)?.cast<String>() ??
          [],
    );
  }

  // Copy with method
  TableBookingModel copyWith({
    String? id,
    String? guestName,
    String? phoneNumber,
    String? email,
    DateTime? bookingDate,
    TimeOfDay? bookingTime,
    int? numberOfGuests,
    double? durationHours,
    String? floor,
    int? tableNumber,
    String? specialPreferences,
    List<ReservationMenuItem>? menuItems,
    TableBookingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    List<String>? assignedStaffIds,
  }) {
    return TableBookingModel(
      id: id ?? this.id,
      guestName: guestName ?? this.guestName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      bookingDate: bookingDate ?? this.bookingDate,
      bookingTime: bookingTime ?? this.bookingTime,
      numberOfGuests: numberOfGuests ?? this.numberOfGuests,
      durationHours: durationHours ?? this.durationHours,
      floor: floor ?? this.floor,
      tableNumber: tableNumber ?? this.tableNumber,
      specialPreferences: specialPreferences ?? this.specialPreferences,
      menuItems: menuItems ?? this.menuItems,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      assignedStaffIds: assignedStaffIds ?? this.assignedStaffIds,
    );
  }
}
