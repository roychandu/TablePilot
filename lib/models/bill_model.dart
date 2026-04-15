class BillModel {
  final String? billId;
  final String orderId;
  final double subtotal;
  final double serviceCharge;
  final double? discountAmount;
  final String? discountType; // 'percentage' or 'flat'
  final double finalTotal;
  final double? tipAmount;
  final String paymentStatus; // 'paid', 'pending', 'cancelled'
  final DateTime paidAt;
  final DateTime createdAt;
  final String? userId;

  BillModel({
    this.billId,
    required this.orderId,
    required this.subtotal,
    required this.serviceCharge,
    this.discountAmount,
    this.discountType,
    required this.finalTotal,
    this.tipAmount,
    this.paymentStatus = 'paid',
    DateTime? paidAt,
    DateTime? createdAt,
    this.userId,
  })  : paidAt = paidAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'subtotal': subtotal,
      'serviceCharge': serviceCharge,
      'discountAmount': discountAmount,
      'discountType': discountType,
      'finalTotal': finalTotal,
      'tipAmount': tipAmount,
      'paymentStatus': paymentStatus,
      'paidAt': paidAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
    };
  }

  factory BillModel.fromMap(String billId, Map<dynamic, dynamic> map) {
    return BillModel(
      billId: billId,
      orderId: map['orderId'] as String? ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (map['serviceCharge'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble(),
      discountType: map['discountType'] as String?,
      finalTotal: (map['finalTotal'] as num?)?.toDouble() ?? 0.0,
      tipAmount: (map['tipAmount'] as num?)?.toDouble(),
      paymentStatus: map['paymentStatus'] as String? ?? 'paid',
      paidAt: map['paidAt'] != null
          ? DateTime.parse(map['paidAt'] as String)
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      userId: map['userId'] as String?,
    );
  }

  BillModel copyWith({
    String? billId,
    String? orderId,
    double? subtotal,
    double? serviceCharge,
    double? discountAmount,
    String? discountType,
    double? finalTotal,
    double? tipAmount,
    String? paymentStatus,
    DateTime? paidAt,
    DateTime? createdAt,
    String? userId,
  }) {
    return BillModel(
      billId: billId ?? this.billId,
      orderId: orderId ?? this.orderId,
      subtotal: subtotal ?? this.subtotal,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      discountAmount: discountAmount ?? this.discountAmount,
      discountType: discountType ?? this.discountType,
      finalTotal: finalTotal ?? this.finalTotal,
      tipAmount: tipAmount ?? this.tipAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }
}

