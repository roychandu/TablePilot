class OrderItem {
  final String itemName;
  final int quantity;
  final double priceAed;

  OrderItem({
    required this.itemName,
    required this.quantity,
    required this.priceAed,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'quantity': quantity,
      'priceAed': priceAed,
    };
  }

  factory OrderItem.fromMap(Map<dynamic, dynamic> map) {
    return OrderItem(
      itemName: map['itemName'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      priceAed: (map['priceAed'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderModel {
  final String? orderId;
  final int tableNumber;
  final int numberOfGuests;
  final List<String> guestNames;
  final DateTime reservationTime;
  final OrderStatus status;
  final List<OrderItem> items;
  final double subtotal;
  final double serviceCharge;
  final double total;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? userId;
  final List<int>? kotCountHistory; // Track item count history for KOT grouping

  OrderModel({
    this.orderId,
    required this.tableNumber,
    required this.numberOfGuests,
    required this.guestNames,
    required this.reservationTime,
    this.status = OrderStatus.pending,
    this.items = const [],
    this.subtotal = 0.0,
    this.serviceCharge = 0.0,
    this.total = 0.0,
    DateTime? createdAt,
    this.updatedAt,
    this.userId,
    this.kotCountHistory,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'tableNumber': tableNumber,
      'numberOfGuests': numberOfGuests,
      'guestNames': guestNames,
      'reservationTime': reservationTime.toIso8601String(),
      'status': statusToString(status),
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'serviceCharge': serviceCharge,
      'total': total,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'userId': userId,
      'kotCountHistory': kotCountHistory,
    };
  }

  // Create from Map (from Firebase)
  factory OrderModel.fromMap(String orderId, Map<dynamic, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    final items = itemsList
        .map((item) => OrderItem.fromMap(item as Map<dynamic, dynamic>))
        .toList();

    // Parse KOT count history
    List<int>? kotHistory;
    if (map['kotCountHistory'] != null) {
      final historyList = map['kotCountHistory'] as List<dynamic>?;
      if (historyList != null) {
        kotHistory = historyList.map((e) => e as int).toList();
      }
    }

    return OrderModel(
      orderId: orderId,
      tableNumber: map['tableNumber'] as int? ?? 0,
      numberOfGuests: map['numberOfGuests'] as int? ?? 0,
      guestNames: List<String>.from(map['guestNames'] ?? []),
      reservationTime: DateTime.parse(map['reservationTime'] as String),
      status: stringToStatus(map['status'] as String? ?? 'pending'),
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (map['serviceCharge'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      userId: map['userId'] as String?,
      kotCountHistory: kotHistory,
    );
  }

  // Copy with method
  OrderModel copyWith({
    String? orderId,
    int? tableNumber,
    int? numberOfGuests,
    List<String>? guestNames,
    DateTime? reservationTime,
    OrderStatus? status,
    List<OrderItem>? items,
    double? subtotal,
    double? serviceCharge,
    double? total,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    List<int>? kotCountHistory,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      tableNumber: tableNumber ?? this.tableNumber,
      numberOfGuests: numberOfGuests ?? this.numberOfGuests,
      guestNames: guestNames ?? this.guestNames,
      reservationTime: reservationTime ?? this.reservationTime,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      kotCountHistory: kotCountHistory ?? this.kotCountHistory,
    );
  }
}

enum OrderStatus {
  pending,
  active,
  preparing,
  ready,
  served,
  completed,
  cancelled,
}

String statusToString(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'pending';
    case OrderStatus.active:
      return 'active';
    case OrderStatus.preparing:
      return 'preparing';
    case OrderStatus.ready:
      return 'ready';
    case OrderStatus.served:
      return 'served';
    case OrderStatus.completed:
      return 'completed';
    case OrderStatus.cancelled:
      return 'cancelled';
  }
}

OrderStatus stringToStatus(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return OrderStatus.active;
    case 'preparing':
      return OrderStatus.preparing;
    case 'ready':
      return OrderStatus.ready;
    case 'served':
      return OrderStatus.served;
    case 'completed':
      return OrderStatus.completed;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'pending':
    default:
      return OrderStatus.pending;
  }
}

