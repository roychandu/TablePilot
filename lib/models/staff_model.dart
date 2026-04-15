class StaffModel {
  final String? id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String category;
  final String shift;
  final double salaryAed;
  final int experienceYears;
  final DateTime startDate;
  final String? photoUrl;
  final bool inFloor;

  StaffModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.category,
    required this.shift,
    required this.salaryAed,
    required this.experienceYears,
    required this.startDate,
    this.photoUrl,
    this.inFloor = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'category': category,
      'shift': shift,
      'salaryAed': salaryAed,
      'experienceYears': experienceYears,
      'startDate': startDate.toIso8601String(),
      'photoUrl': photoUrl,
      'inFloor': inFloor,
    };
  }

  factory StaffModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return StaffModel(
      id: id,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      category: map['category'] as String? ?? '',
      shift: map['shift'] as String? ?? '',
      salaryAed: (map['salaryAed'] as num?)?.toDouble() ?? 0.0,
      experienceYears: map['experienceYears'] as int? ?? 0,
      startDate:
          DateTime.tryParse(map['startDate'] as String? ?? '') ??
          DateTime.now(),
      photoUrl: map['photoUrl'] as String?,
      inFloor: map['inFloor'] as bool? ?? false,
    );
  }
}
