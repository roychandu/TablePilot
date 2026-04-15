enum OfferType {
  percentageDiscount,
  fixedAmountOff,
  buyOneGetOne,
  freeItemWithPurchase,
}

enum OfferStatus {
  active,
  scheduled,
  expired,
}

enum OfferApplyTo {
  allItems,
  specificCategory,
  specificItems,
  reservations,
}

class OfferModel {
  final String? id;
  final String title;
  final String description;
  final OfferType offerType;
  final double discountValue; // Percentage or fixed amount
  final List<OfferApplyTo> applyTo;
  final List<String>? categoryNames; // If applyTo includes specificCategory
  final List<String>? itemNames; // If applyTo includes specificItems
  final DateTime validFrom;
  final DateTime validUntil;
  final String? termsAndConditions;
  final String? bannerImageUrl; // 16:9 ratio image
  final double? minimumOrderValue;
  final int? usageLimit; // e.g., 'First 50 customers'
  final bool visibleToCustomers;
  final OfferStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OfferModel({
    this.id,
    required this.title,
    required this.description,
    required this.offerType,
    required this.discountValue,
    required this.applyTo,
    this.categoryNames,
    this.itemNames,
    required this.validFrom,
    required this.validUntil,
    this.termsAndConditions,
    this.bannerImageUrl,
    this.minimumOrderValue,
    this.usageLimit,
    this.visibleToCustomers = true,
    OfferStatus? status,
    DateTime? createdAt,
    this.updatedAt,
  })  : status = status ?? calculateStatus(validFrom, validUntil),
        createdAt = createdAt ?? DateTime.now();

  // Calculate status based on dates
  static OfferStatus calculateStatus(DateTime validFrom, DateTime validUntil) {
    final now = DateTime.now();
    if (now.isBefore(validFrom)) {
      return OfferStatus.scheduled;
    } else if (now.isAfter(validUntil)) {
      return OfferStatus.expired;
    } else {
      return OfferStatus.active;
    }
  }

  // Update status based on current time
  OfferModel updateStatus() {
    final newStatus = calculateStatus(validFrom, validUntil);
    return copyWith(status: newStatus);
  }

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'offerType': offerTypeToString(offerType),
      'discountValue': discountValue,
      'applyTo': applyTo.map((e) => offerApplyToToString(e)).toList(),
      'categoryNames': categoryNames,
      'itemNames': itemNames,
      'validFrom': validFrom.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'termsAndConditions': termsAndConditions,
      'bannerImageUrl': bannerImageUrl,
      'minimumOrderValue': minimumOrderValue,
      'usageLimit': usageLimit,
      'visibleToCustomers': visibleToCustomers,
      'status': offerStatusToString(status),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create from Map (from Firebase)
  factory OfferModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final applyToList = map['applyTo'] as List<dynamic>? ?? [];
    final applyTo = applyToList
        .map((e) => stringToOfferApplyTo(e.toString()))
        .toList();

    final categoryNamesList = map['categoryNames'] as List<dynamic>?;
    final itemNamesList = map['itemNames'] as List<dynamic>?;

    final validFrom = DateTime.tryParse(map['validFrom'] as String? ?? '') ??
        DateTime.now();
    final validUntil = DateTime.tryParse(map['validUntil'] as String? ?? '') ??
        DateTime.now().add(const Duration(days: 7));

    return OfferModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      offerType: stringToOfferType(map['offerType'] as String? ?? ''),
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0.0,
      applyTo: applyTo,
      categoryNames: categoryNamesList?.map((e) => e.toString()).toList(),
      itemNames: itemNamesList?.map((e) => e.toString()).toList(),
      validFrom: validFrom,
      validUntil: validUntil,
      termsAndConditions: map['termsAndConditions'] as String?,
      bannerImageUrl: map['bannerImageUrl'] as String?,
      minimumOrderValue: (map['minimumOrderValue'] as num?)?.toDouble(),
      usageLimit: map['usageLimit'] as int?,
      visibleToCustomers: map['visibleToCustomers'] as bool? ?? true,
      status: stringToOfferStatus(map['status'] as String? ?? ''),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
    );
  }

  // Copy with method
  OfferModel copyWith({
    String? id,
    String? title,
    String? description,
    OfferType? offerType,
    double? discountValue,
    List<OfferApplyTo>? applyTo,
    List<String>? categoryNames,
    List<String>? itemNames,
    DateTime? validFrom,
    DateTime? validUntil,
    String? termsAndConditions,
    String? bannerImageUrl,
    double? minimumOrderValue,
    int? usageLimit,
    bool? visibleToCustomers,
    OfferStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfferModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      offerType: offerType ?? this.offerType,
      discountValue: discountValue ?? this.discountValue,
      applyTo: applyTo ?? this.applyTo,
      categoryNames: categoryNames ?? this.categoryNames,
      itemNames: itemNames ?? this.itemNames,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      minimumOrderValue: minimumOrderValue ?? this.minimumOrderValue,
      usageLimit: usageLimit ?? this.usageLimit,
      visibleToCustomers: visibleToCustomers ?? this.visibleToCustomers,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Helper functions for enum conversions
String offerTypeToString(OfferType type) {
  switch (type) {
    case OfferType.percentageDiscount:
      return 'percentageDiscount';
    case OfferType.fixedAmountOff:
      return 'fixedAmountOff';
    case OfferType.buyOneGetOne:
      return 'buyOneGetOne';
    case OfferType.freeItemWithPurchase:
      return 'freeItemWithPurchase';
  }
}

OfferType stringToOfferType(String type) {
  switch (type.toLowerCase()) {
    case 'fixedamountoff':
    case 'fixed_amount_off':
      return OfferType.fixedAmountOff;
    case 'buyonegetone':
    case 'buy_one_get_one':
    case 'bogo':
      return OfferType.buyOneGetOne;
    case 'freeitemwithpurchase':
    case 'free_item_with_purchase':
      return OfferType.freeItemWithPurchase;
    case 'percentagediscount':
    case 'percentage_discount':
    default:
      return OfferType.percentageDiscount;
  }
}

String offerStatusToString(OfferStatus status) {
  switch (status) {
    case OfferStatus.active:
      return 'active';
    case OfferStatus.scheduled:
      return 'scheduled';
    case OfferStatus.expired:
      return 'expired';
  }
}

OfferStatus stringToOfferStatus(String status) {
  switch (status.toLowerCase()) {
    case 'scheduled':
      return OfferStatus.scheduled;
    case 'expired':
      return OfferStatus.expired;
    case 'active':
    default:
      return OfferStatus.active;
  }
}

String offerApplyToToString(OfferApplyTo applyTo) {
  switch (applyTo) {
    case OfferApplyTo.allItems:
      return 'allItems';
    case OfferApplyTo.specificCategory:
      return 'specificCategory';
    case OfferApplyTo.specificItems:
      return 'specificItems';
    case OfferApplyTo.reservations:
      return 'reservations';
  }
}

OfferApplyTo stringToOfferApplyTo(String applyTo) {
  switch (applyTo.toLowerCase()) {
    case 'specificcategory':
    case 'specific_category':
      return OfferApplyTo.specificCategory;
    case 'specificitems':
    case 'specific_items':
      return OfferApplyTo.specificItems;
    case 'reservations':
      return OfferApplyTo.reservations;
    case 'allitems':
    case 'all_items':
    default:
      return OfferApplyTo.allItems;
  }
}

// Display helpers
String getOfferTypeDisplayText(OfferType type) {
  switch (type) {
    case OfferType.percentageDiscount:
      return 'Percentage Discount';
    case OfferType.fixedAmountOff:
      return 'Fixed Amount Off';
    case OfferType.buyOneGetOne:
      return 'Buy One Get One';
    case OfferType.freeItemWithPurchase:
      return 'Free Item with Purchase';
  }
}

String getOfferStatusDisplayText(OfferStatus status) {
  switch (status) {
    case OfferStatus.active:
      return 'Active';
    case OfferStatus.scheduled:
      return 'Scheduled';
    case OfferStatus.expired:
      return 'Expired';
  }
}

