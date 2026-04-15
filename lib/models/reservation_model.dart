class ReservationMenuItem {
  final String itemName;
  final int quantity;
  final double priceAed;

  ReservationMenuItem({
    required this.itemName,
    required this.quantity,
    required this.priceAed,
  });

  Map<String, dynamic> toMap() {
    return {'itemName': itemName, 'quantity': quantity, 'priceAed': priceAed};
  }

  factory ReservationMenuItem.fromMap(Map<dynamic, dynamic> map) {
    return ReservationMenuItem(
      itemName: map['itemName'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      priceAed: (map['priceAed'] as num?)?.toDouble() ?? 0.0,
    );
  }

  double get totalPrice => priceAed * quantity;

  // Compatibility with EventMenuItem
  factory ReservationMenuItem.fromEventMenuItem(dynamic item) {
    if (item is ReservationMenuItem) return item;
    // If it's EventMenuItem, convert it
    return ReservationMenuItem(
      itemName: item.itemName,
      quantity: item.quantity,
      priceAed: item.priceAed,
    );
  }
}

class AdditionalService {
  final String name;
  final double priceAed;
  final bool selected;

  AdditionalService({
    required this.name,
    required this.priceAed,
    this.selected = false,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'priceAed': priceAed, 'selected': selected};
  }

  factory AdditionalService.fromMap(Map<dynamic, dynamic> map) {
    return AdditionalService(
      name: map['name'] as String? ?? '',
      priceAed: (map['priceAed'] as num?)?.toDouble() ?? 0.0,
      selected: map['selected'] as bool? ?? false,
    );
  }

  AdditionalService copyWith({bool? selected}) {
    return AdditionalService(
      name: name,
      priceAed: priceAed,
      selected: selected ?? this.selected,
    );
  }
}

enum ReservationType {
  corporateEvent,
  wedding,
  birthdayParty,
  anniversary,
  conference,
  galaDinner,
  other,
}

enum ReservationStatus { upcoming, completed, cancelled, rejected }

enum PaymentMethod { cash, card }

String reservationTypeToString(ReservationType type) {
  switch (type) {
    case ReservationType.corporateEvent:
      return 'Corporate Event';
    case ReservationType.wedding:
      return 'Wedding';
    case ReservationType.birthdayParty:
      return 'Birthday Party';
    case ReservationType.anniversary:
      return 'Anniversary';
    case ReservationType.conference:
      return 'Conference';
    case ReservationType.galaDinner:
      return 'Gala Dinner';
    case ReservationType.other:
      return 'Other';
  }
}

ReservationType stringToReservationType(String type) {
  switch (type.toLowerCase()) {
    case 'corporate event':
      return ReservationType.corporateEvent;
    case 'wedding':
      return ReservationType.wedding;
    case 'birthday party':
      return ReservationType.birthdayParty;
    case 'anniversary':
      return ReservationType.anniversary;
    case 'conference':
      return ReservationType.conference;
    case 'gala dinner':
      return ReservationType.galaDinner;
    case 'other':
      return ReservationType.other;
    default:
      return ReservationType.other;
  }
}

class ReservationModel {
  final String? id;
  // Required fields (collected in add_reservation_screen.dart)
  final String reservationName;
  final String contactPerson;
  final String email;
  final String phone;
  final DateTime reservationDate;
  final DateTime startTime;
  final int numberOfGuests;
  final String specialDietaryRequirements;

  // Optional fields (NOT collected in add_reservation_screen.dart - defaults provided)
  final ReservationType reservationType;
  final int requiredTables;
  final int? tableNumber; // Table number if reservation is for a specific table
  final bool parkingRequired;
  final List<String> menuCategories;
  final List<ReservationMenuItem> menuItems;
  final String decorPackage;
  final List<AdditionalService> additionalServices;
  final List<String> assignedStaffIds;
  final PaymentMethod paymentMethod;
  final double estimatedTotalCost;
  final ReservationStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReservationModel({
    this.id,
    // Required fields (collected in form)
    required this.reservationName,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.reservationDate,
    required this.startTime,
    required this.numberOfGuests,
    required this.specialDietaryRequirements,
    // Optional fields (NOT collected in form - all have defaults)
    this.reservationType = ReservationType.other,
    this.requiredTables = 1,
    this.tableNumber,
    this.parkingRequired = false,
    this.menuCategories = const [],
    this.menuItems = const [],
    this.decorPackage = '',
    this.additionalServices = const [],
    this.assignedStaffIds = const [],
    this.paymentMethod = PaymentMethod.cash,
    this.estimatedTotalCost = 0.0,
    this.status = ReservationStatus.upcoming,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Calculate total cost
  double get totalCost {
    double total = 0.0;
    // Add menu items cost
    for (final item in menuItems) {
      total += item.totalPrice;
    }
    // Add additional services cost
    for (final service in additionalServices) {
      if (service.selected) {
        total += service.priceAed;
      }
    }
    return total;
  }

  Map<String, dynamic> toMap() {
    return {
      'eventName':
          reservationName, // Keep 'eventName' for database compatibility
      'eventType': reservationTypeToString(reservationType),
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'eventDate': reservationDate
          .toIso8601String(), // Keep 'eventDate' for compatibility
      'startTime': startTime.toIso8601String(),
      'numberOfGuests': numberOfGuests,
      'requiredTables': requiredTables,
      'tableNumber': tableNumber,
      'parkingRequired': parkingRequired,
      'menuCategories': menuCategories,
      'menuItems': menuItems.map((item) => item.toMap()).toList(),
      'specialDietaryRequirements': specialDietaryRequirements,
      'decorPackage': decorPackage,
      'additionalServices': additionalServices
          .map((service) => service.toMap())
          .toList(),
      'assignedStaffIds': assignedStaffIds,
      'paymentMethod': paymentMethodToString(paymentMethod),
      'estimatedTotalCost': estimatedTotalCost,
      'status': reservationStatusToString(status),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ReservationModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final menuItemsList = map['menuItems'] as List<dynamic>? ?? [];
    final menuItems = menuItemsList
        .map(
          (item) => ReservationMenuItem.fromMap(item as Map<dynamic, dynamic>),
        )
        .toList();

    final servicesList = map['additionalServices'] as List<dynamic>? ?? [];
    final additionalServices = servicesList
        .map(
          (service) =>
              AdditionalService.fromMap(service as Map<dynamic, dynamic>),
        )
        .toList();

    final staffIdsList = map['assignedStaffIds'] as List<dynamic>? ?? [];
    final assignedStaffIds = staffIdsList.map((id) => id.toString()).toList();

    return ReservationModel(
      id: id,
      // Required fields
      reservationName:
          map['eventName'] as String? ??
          map['reservationName'] as String? ??
          '', // Read from 'eventName' for compatibility
      contactPerson: map['contactPerson'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      reservationDate:
          DateTime.tryParse(
            map['eventDate'] as String? ??
                map['reservationDate'] as String? ??
                '',
          ) ?? // Read from 'eventDate' for compatibility
          DateTime.now(),
      startTime:
          DateTime.tryParse(map['startTime'] as String? ?? '') ??
          DateTime.now(),
      numberOfGuests: map['numberOfGuests'] as int? ?? 0,
      specialDietaryRequirements:
          map['specialDietaryRequirements'] as String? ?? '',
      // Optional fields with defaults
      reservationType: stringToReservationType(
        map['eventType'] as String? ?? '',
      ),
      requiredTables:
          map['requiredTables'] as int? ??
          int.tryParse(map['requiredTables']?.toString() ?? '') ??
          1,
      tableNumber: map['tableNumber'] as int?,
      parkingRequired: map['parkingRequired'] as bool? ?? false,
      menuCategories:
          (map['menuCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (map['menuCategory'] != null
              ? [map['menuCategory'].toString()]
              : []), // Support legacy single category field
      menuItems: menuItems,
      decorPackage: map['decorPackage'] as String? ?? '',
      additionalServices: additionalServices,
      assignedStaffIds: assignedStaffIds,
      paymentMethod: stringToPaymentMethod(
        map['paymentMethod'] as String? ?? 'cash',
      ),
      estimatedTotalCost:
          (map['estimatedTotalCost'] as num?)?.toDouble() ?? 0.0,
      status: stringToReservationStatus(map['status'] as String? ?? 'upcoming'),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
    );
  }

  ReservationModel copyWith({
    String? id,
    String? reservationName,
    String? contactPerson,
    String? email,
    String? phone,
    DateTime? reservationDate,
    DateTime? startTime,
    int? numberOfGuests,
    String? specialDietaryRequirements,
    // Optional fields
    ReservationType? reservationType,
    int? requiredTables,
    int? tableNumber,
    bool? parkingRequired,
    List<String>? menuCategories,
    List<ReservationMenuItem>? menuItems,
    String? decorPackage,
    List<AdditionalService>? additionalServices,
    List<String>? assignedStaffIds,
    PaymentMethod? paymentMethod,
    double? estimatedTotalCost,
    ReservationStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      reservationName: reservationName ?? this.reservationName,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      reservationDate: reservationDate ?? this.reservationDate,
      startTime: startTime ?? this.startTime,
      numberOfGuests: numberOfGuests ?? this.numberOfGuests,
      specialDietaryRequirements:
          specialDietaryRequirements ?? this.specialDietaryRequirements,
      // Optional fields
      reservationType: reservationType ?? this.reservationType,
      requiredTables: requiredTables ?? this.requiredTables,
      tableNumber: tableNumber ?? this.tableNumber,
      parkingRequired: parkingRequired ?? this.parkingRequired,
      menuCategories: menuCategories ?? this.menuCategories,
      menuItems: menuItems ?? this.menuItems,
      decorPackage: decorPackage ?? this.decorPackage,
      additionalServices: additionalServices ?? this.additionalServices,
      assignedStaffIds: assignedStaffIds ?? this.assignedStaffIds,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      estimatedTotalCost: estimatedTotalCost ?? this.estimatedTotalCost,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to EventModel for backward compatibility
  Map<String, dynamic> toEventModelMap() {
    return {
      'eventName': reservationName,
      'eventType': reservationTypeToString(reservationType),
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'eventDate': reservationDate.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'numberOfGuests': numberOfGuests,
      'requiredTables': requiredTables,
      'tableNumber': tableNumber,
      'parkingRequired': parkingRequired,
      'menuCategories': menuCategories,
      'menuItems': menuItems.map((item) => item.toMap()).toList(),
      'specialDietaryRequirements': specialDietaryRequirements,
      'decorPackage': decorPackage,
      'additionalServices': additionalServices
          .map((service) => service.toMap())
          .toList(),
      'assignedStaffIds': assignedStaffIds,
      'paymentMethod': paymentMethodToString(paymentMethod),
      'estimatedTotalCost': estimatedTotalCost,
      'status': reservationStatusToString(status),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

// Helper functions for enum conversions

String reservationStatusToString(ReservationStatus status) {
  switch (status) {
    case ReservationStatus.upcoming:
      return 'upcoming';
    case ReservationStatus.completed:
      return 'completed';
    case ReservationStatus.cancelled:
      return 'cancelled';
    case ReservationStatus.rejected:
      return 'rejected';
  }
}

ReservationStatus stringToReservationStatus(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return ReservationStatus.completed;
    case 'cancelled':
      return ReservationStatus.cancelled;
    case 'rejected':
      return ReservationStatus.rejected;
    case 'upcoming':
    default:
      return ReservationStatus.upcoming;
  }
}

// Get approval status display text (Pending/Confirmed/Rejected/Cancelled)
String getApprovalStatusText(ReservationStatus status) {
  switch (status) {
    case ReservationStatus.upcoming:
      return 'Pending';
    case ReservationStatus.completed:
      return 'Confirmed';
    case ReservationStatus.cancelled:
      return 'Cancelled';
    case ReservationStatus.rejected:
      return 'Rejected';
  }
}

// Check if reservation is pending approval
bool isReservationPending(ReservationStatus status) {
  return status == ReservationStatus.upcoming;
}

// Check if reservation is confirmed
bool isReservationConfirmed(ReservationStatus status) {
  return status == ReservationStatus.completed;
}

// Check if reservation is rejected
bool isReservationRejected(ReservationStatus status) {
  return status == ReservationStatus.rejected;
}

// Check if reservation is cancelled
bool isReservationCancelled(ReservationStatus status) {
  return status == ReservationStatus.cancelled;
}

String paymentMethodToString(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return 'cash';
    case PaymentMethod.card:
      return 'card';
  }
}

PaymentMethod stringToPaymentMethod(String method) {
  switch (method.toLowerCase()) {
    case 'card':
      return PaymentMethod.card;
    case 'cash':
    default:
      return PaymentMethod.cash;
  }
}

// Compatibility functions with EventModel
@Deprecated('Use ReservationType instead')
typedef EventType = ReservationType;

@Deprecated('Use ReservationStatus instead')
typedef EventStatus = ReservationStatus;

@Deprecated('Use ReservationMenuItem instead')
typedef EventMenuItem = ReservationMenuItem;

// Helper to convert EventType to ReservationType
ReservationType eventTypeToReservationType(dynamic type) {
  if (type is ReservationType) return type;
  // Handle EventType enum values
  final typeString = type.toString();
  if (typeString.contains('corporateEvent'))
    return ReservationType.corporateEvent;
  if (typeString.contains('wedding')) return ReservationType.wedding;
  if (typeString.contains('birthdayParty'))
    return ReservationType.birthdayParty;
  if (typeString.contains('anniversary')) return ReservationType.anniversary;
  if (typeString.contains('conference')) return ReservationType.conference;
  if (typeString.contains('galaDinner')) return ReservationType.galaDinner;
  return ReservationType.other;
}

// Helper to convert EventStatus to ReservationStatus
ReservationStatus eventStatusToReservationStatus(dynamic status) {
  if (status is ReservationStatus) return status;
  final statusString = status.toString();
  if (statusString.contains('completed')) return ReservationStatus.completed;
  if (statusString.contains('cancelled')) return ReservationStatus.cancelled;
  return ReservationStatus.upcoming;
}
