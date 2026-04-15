class CartItem {
  final String itemId; // Unique identifier for the cart item
  final String itemName;
  final String description;
  final double priceAed;
  final String? imagePath;
  final int quantity;
  final String?
  customizationNotes; // Custom notes like "Extra spicy, No onion, Add marinated egg"
  final String? categoryName; // Category name for offer application

  CartItem({
    required this.itemId,
    required this.itemName,
    required this.description,
    required this.priceAed,
    this.imagePath,
    this.quantity = 1,
    this.customizationNotes,
    this.categoryName,
  });

  // Calculate total price for this item
  double get totalPrice => priceAed * quantity;

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'description': description,
      'priceAed': priceAed,
      'imagePath': imagePath,
      'quantity': quantity,
      'customizationNotes': customizationNotes,
      'categoryName': categoryName,
    };
  }

  // Create from Map
  factory CartItem.fromMap(Map<dynamic, dynamic> map) {
    return CartItem(
      itemId: map['itemId'] as String? ?? '',
      itemName: map['itemName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      priceAed: (map['priceAed'] as num?)?.toDouble() ?? 0.0,
      imagePath: map['imagePath'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      customizationNotes: map['customizationNotes'] as String?,
      categoryName: map['categoryName'] as String?,
    );
  }

  // Copy with method
  CartItem copyWith({
    String? itemId,
    String? itemName,
    String? description,
    double? priceAed,
    String? imagePath,
    int? quantity,
    String? customizationNotes,
    String? categoryName,
  }) {
    return CartItem(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      priceAed: priceAed ?? this.priceAed,
      imagePath: imagePath ?? this.imagePath,
      quantity: quantity ?? this.quantity,
      customizationNotes: customizationNotes ?? this.customizationNotes,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}

class Cart {
  final List<CartItem> items;
  final String? appliedCouponCode;
  final double? discountAmount;
  final double taxRate; // Percentage (e.g., 5.0 for 5%)
  final double serviceChargeRate; // Percentage (e.g., 10.0 for 10%)

  Cart({
    this.items = const [],
    this.appliedCouponCode,
    this.discountAmount,
    this.taxRate = 5.0,
    this.serviceChargeRate = 10.0,
  });

  // Calculate subtotal (sum of all item prices)
  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Calculate discount amount
  double get discount {
    return discountAmount ?? 0.0;
  }

  // Calculate tax (on subtotal after discount)
  double get tax {
    final taxableAmount = subtotal - discount;
    return (taxableAmount * taxRate / 100).clamp(0.0, double.infinity);
  }

  // Calculate grand total
  double get grandTotal {
    final taxableAmount = subtotal - discount;
    return (taxableAmount + tax).clamp(0.0, double.infinity);
  }

  // Get total item count
  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  // Check if cart is empty
  bool get isEmpty => items.isEmpty;

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
      'appliedCouponCode': appliedCouponCode,
      'discountAmount': discountAmount,
      'taxRate': taxRate,
      'serviceChargeRate': serviceChargeRate,
    };
  }

  // Create from Map
  factory Cart.fromMap(Map<dynamic, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    final items = itemsList
        .map((item) => CartItem.fromMap(item as Map<dynamic, dynamic>))
        .toList();

    return Cart(
      items: items,
      appliedCouponCode: map['appliedCouponCode'] as String?,
      discountAmount: (map['discountAmount'] as num?)?.toDouble(),
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 5.0,
      serviceChargeRate: (map['serviceChargeRate'] as num?)?.toDouble() ?? 10.0,
    );
  }

  // Copy with method
  Cart copyWith({
    List<CartItem>? items,
    String? appliedCouponCode,
    double? discountAmount,
    double? taxRate,
    double? serviceChargeRate,
  }) {
    return Cart(
      items: items ?? this.items,
      appliedCouponCode: appliedCouponCode ?? this.appliedCouponCode,
      discountAmount: discountAmount ?? this.discountAmount,
      taxRate: taxRate ?? this.taxRate,
      serviceChargeRate: serviceChargeRate ?? this.serviceChargeRate,
    );
  }
}
