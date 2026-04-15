// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/reservation_model.dart';
import '../../models/table_booking_model.dart';
import '../../models/menu_model.dart';
import '../../services/reservation_service.dart';
import '../../services/table_booking_service.dart';
import '../../services/menu_service.dart';
import '../../services/offer_service.dart';
import '../../models/offer_model.dart';
import '../../aws/aws_fields.dart';

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key, required this.event});

  final dynamic
  event; // Accepts ReservationModel, EventModel, or TableBookingModel

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final MenuService _menuService = MenuService();
  final ReservationService _eventService = ReservationService();
  final TableBookingService _tableBookingService = TableBookingService();
  final OfferService _offerService = OfferService();

  // Check if event is a TableBookingModel
  bool get _isTableBooking => widget.event is TableBookingModel;

  // Helper to get event/reservation name
  String get _eventName {
    if (widget.event is ReservationModel) {
      return (widget.event as ReservationModel).reservationName;
    }
    // For other event types that might have eventName
    try {
      return widget.event.eventName ?? 'Reservation';
    } catch (e) {
      return 'Reservation';
    }
  }

  RestaurantMenu? _menu;
  final List<ReservationMenuItem> _selectedItems = [];
  bool _isSubmitting = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<OfferModel> _activeOffers = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _loadOffers();
    _loadExistingMenuItems();
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await _offerService.getActiveOffersForCustomers();
      if (mounted) {
        setState(() {
          _activeOffers = offers;
        });
      }
    } catch (e) {
      debugPrint('Error loading offers: $e');
    }
  }

  // Check if an offer applies to a menu item
  bool _doesOfferApply(OfferModel offer, MenuItem item, String categoryName) {
    if (offer.status != OfferStatus.active || !offer.visibleToCustomers) {
      return false;
    }

    final now = DateTime.now();
    if (now.isBefore(offer.validFrom) || now.isAfter(offer.validUntil)) {
      return false;
    }

    if (offer.applyTo.contains(OfferApplyTo.allItems)) {
      return true;
    }

    if (offer.applyTo.contains(OfferApplyTo.specificCategory)) {
      if (offer.categoryNames != null &&
          offer.categoryNames!.contains(categoryName)) {
        return true;
      }
    }

    if (offer.applyTo.contains(OfferApplyTo.specificItems)) {
      if (offer.itemNames != null && offer.itemNames!.contains(item.itemName)) {
        return true;
      }
    }

    return false;
  }

  // Get applicable offers for a menu item
  List<OfferModel> _getApplicableOffers(MenuItem item, String categoryName) {
    return _activeOffers
        .where((offer) => _doesOfferApply(offer, item, categoryName))
        .toList();
  }

  // Calculate discounted price for an item
  double _calculateDiscountedPrice(MenuItem item, String categoryName) {
    final applicableOffers = _getApplicableOffers(item, categoryName);
    if (applicableOffers.isEmpty) {
      return item.priceAed;
    }

    // For now, apply the first applicable offer
    final offer = applicableOffers.first;
    double discountedPrice = item.priceAed;

    switch (offer.offerType) {
      case OfferType.percentageDiscount:
        discountedPrice = item.priceAed * (1 - offer.discountValue / 100);
        break;
      case OfferType.fixedAmountOff:
        discountedPrice = (item.priceAed - offer.discountValue).clamp(
          0.0,
          double.infinity,
        );
        break;
      default:
        discountedPrice = item.priceAed;
        break;
    }

    return discountedPrice;
  }

  // Get best offer text for display
  String? _getOfferText(MenuItem item, String categoryName) {
    final applicableOffers = _getApplicableOffers(item, categoryName);
    if (applicableOffers.isEmpty) {
      return null;
    }

    final offer = applicableOffers.first;
    switch (offer.offerType) {
      case OfferType.percentageDiscount:
        return '${offer.discountValue.toInt()}% OFF';
      case OfferType.fixedAmountOff:
        return 'AED ${offer.discountValue.toStringAsFixed(0)} OFF';
      case OfferType.buyOneGetOne:
        return 'BOGO';
      case OfferType.freeItemWithPurchase:
        return 'Free Item';
    }
  }

  Future<void> _loadMenu() async {
    try {
      // Start with default menu
      final defaultMenu = RestaurantMenu.getDefaultMenu();

      // Try to load menu from Firebase
      final firebaseMenu = await _menuService.getMenu();

      // Merge them
      final mergedMenu = _mergeMenus(defaultMenu, firebaseMenu);

      if (mounted) {
        setState(() {
          _menu = mergedMenu;
        });
      }
    } catch (e) {
      debugPrint('Error loading menu: $e');
      if (mounted) {
        setState(() {
          _menu = RestaurantMenu.getDefaultMenu();
        });
      }
    }
  }

  // Merge default menu with Firebase menu (admin-added items)
  RestaurantMenu _mergeMenus(
    RestaurantMenu defaultMenu,
    RestaurantMenu firebaseMenu,
  ) {
    if (firebaseMenu.categories.isEmpty) {
      return defaultMenu;
    }

    final Map<String, MenuCategory> mergedCategoriesMap = {};

    // Add all default menu categories
    for (final category in defaultMenu.categories) {
      mergedCategoriesMap[category.categoryName.toUpperCase()] = category;
    }

    // Merge or add Firebase menu categories
    for (final firebaseCategory in firebaseMenu.categories) {
      final categoryKey = firebaseCategory.categoryName.toUpperCase();

      if (mergedCategoriesMap.containsKey(categoryKey)) {
        final existingCategory = mergedCategoriesMap[categoryKey]!;
        final existingItemNames = existingCategory.items
            .map((item) => item.itemName.toUpperCase())
            .toSet();

        final newItems = firebaseCategory.items
            .where(
              (item) =>
                  !existingItemNames.contains(item.itemName.toUpperCase()),
            )
            .toList();

        mergedCategoriesMap[categoryKey] = MenuCategory(
          categoryName: existingCategory.categoryName,
          section: existingCategory.section ?? firebaseCategory.section,
          items: [...existingCategory.items, ...newItems],
        );
      } else {
        mergedCategoriesMap[categoryKey] = firebaseCategory;
      }
    }

    final List<MenuCategory> mergedCategories = [];
    final Set<String> addedCategoryNames = {};

    for (final category in defaultMenu.categories) {
      mergedCategories.add(
        mergedCategoriesMap[category.categoryName.toUpperCase()]!,
      );
      addedCategoryNames.add(category.categoryName.toUpperCase());
    }

    for (final firebaseCategory in firebaseMenu.categories) {
      final categoryKey = firebaseCategory.categoryName.toUpperCase();
      if (!addedCategoryNames.contains(categoryKey)) {
        mergedCategories.add(mergedCategoriesMap[categoryKey]!);
        addedCategoryNames.add(categoryKey);
      }
    }

    return RestaurantMenu(categories: mergedCategories);
  }

  Future<void> _loadExistingMenuItems() async {
    // Load menu items from the event itself
    setState(() {
      _selectedItems.clear();
      _selectedItems.addAll(widget.event.menuItems);
    });
  }

  Future<void> _updateEventMenuItems() async {
    if (_selectedItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one menu item')),
      );
      return;
    }

    if (widget.event.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event ID is missing')));
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });

    // Collect all unique categories from selected items
    final Set<String> categoriesSet = {};
    if (_menu != null && _selectedItems.isNotEmpty) {
      for (final selectedItem in _selectedItems) {
        for (final category in _menu!.categories) {
          final itemExists = category.items.any(
            (item) =>
                item.itemName.trim().toLowerCase() ==
                selectedItem.itemName.trim().toLowerCase(),
          );
          if (itemExists) {
            categoriesSet.add(category.categoryName);
            break;
          }
        }
      }
    }
    // Preserve existing categories if no new ones found (only for reservations/events)
    if (!_isTableBooking &&
        categoriesSet.isEmpty &&
        widget.event.menuCategories != null &&
        widget.event.menuCategories.isNotEmpty) {
      categoriesSet.addAll(widget.event.menuCategories);
    }

    bool success = false;

    if (_isTableBooking) {
      // Update table booking with new menu items
      final tableBooking = widget.event as TableBookingModel;
      final updatedBooking = tableBooking.copyWith(
        menuItems: _selectedItems,
        updatedAt: DateTime.now(),
      );
      success = await _tableBookingService.updateTableBooking(updatedBooking);
    } else {
      // Update event/reservation with new menu items and categories
      final updatedEvent = widget.event.copyWith(
        menuItems: _selectedItems,
        menuCategories: categoriesSet.toList(),
        estimatedTotalCost: _calculateTotalCost(),
      );
      success = await _eventService.updateReservation(updatedEvent);
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu items updated successfully')),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update menu items. Please try again.'),
        ),
      );
    }
  }

  double _calculateTotalCost() {
    double total = 0.0;
    for (final item in _selectedItems) {
      total += item.totalPrice;
    }
    // Add additional services cost (only for reservations/events)
    if (!_isTableBooking && widget.event.additionalServices != null) {
      for (final service in widget.event.additionalServices) {
        if (service.selected) {
          total += service.priceAed;
        }
      }
    }
    return total;
  }

  double _calculateSubtotal() {
    return _selectedItems.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Order',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboardHeight),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event/Booking Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isTableBooking
                                    ? 'Table ${(widget.event as TableBookingModel).tableNumber ?? 'N/A'}'
                                    : _eventName,
                                style: AppTextStyles.h5.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isTableBooking
                                    ? '${widget.event.numberOfGuests} guests • ${(widget.event as TableBookingModel).floor}'
                                    : '${widget.event.numberOfGuests} guests',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Menu Selection
                  Text(
                    'Menu Items',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search items...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textDisabled,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textDisabled,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_menu == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_menu!.categories.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No menu items available',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    _buildMenuItemsList(),
                  // Selected Items Summary
                  if (_selectedItems.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSelectedItemsCard(),
                  ],
                ],
              ),
            ),
          ),
          // Create Order Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _updateEventMenuItems,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Update Menu Items',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemsList() {
    if (_menu == null || _menu!.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _menu!.categories.map((category) {
        final filteredItems = category.items.where((item) {
          if (_searchQuery.isEmpty) return true;
          return item.itemName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              item.description.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
        }).toList();

        if (filteredItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Text(
                category.categoryName,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            // Menu Items in this category
            ...filteredItems.map((item) {
              final discountedPrice = _calculateDiscountedPrice(
                item,
                category.categoryName,
              );
              final offerText = _getOfferText(item, category.categoryName);

              final existingItem = _selectedItems.firstWhere(
                (i) =>
                    i.itemName.trim().toLowerCase() ==
                    item.itemName.trim().toLowerCase(),
                orElse: () =>
                    ReservationMenuItem(itemName: '', quantity: 0, priceAed: 0),
              );
              final quantity = existingItem.itemName.isNotEmpty
                  ? existingItem.quantity
                  : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (item.imagePath != null && item.imagePath!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imagePath!.startsWith('http')
                              ? item.imagePath!
                              : getUrlForUserUploadedImage(item.imagePath!),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: AppColors.surface,
                            child: const Icon(
                              Icons.restaurant_menu,
                              color: AppColors.textDisabled,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    if (item.imagePath != null && item.imagePath!.isNotEmpty)
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'AED ${discountedPrice.toStringAsFixed(0)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: const Color(0xFFFFC107),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (discountedPrice < item.priceAed) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'AED ${item.priceAed.toStringAsFixed(0)}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textDisabled,
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (offerText != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              offerText,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (quantity > 0)
                          Row(
                            children: [
                              _buildQuantityButton(
                                icon: Icons.remove,
                                onPressed: () {
                                  setState(() {
                                    if (quantity > 1) {
                                      final index = _selectedItems.indexWhere(
                                        (i) =>
                                            i.itemName.trim().toLowerCase() ==
                                            item.itemName.trim().toLowerCase(),
                                      );
                                      if (index >= 0) {
                                        _selectedItems[index] =
                                            ReservationMenuItem(
                                              itemName: item.itemName,
                                              quantity: quantity - 1,
                                              priceAed: discountedPrice,
                                            );
                                      }
                                    } else {
                                      _selectedItems.removeWhere(
                                        (i) =>
                                            i.itemName.trim().toLowerCase() ==
                                            item.itemName.trim().toLowerCase(),
                                      );
                                    }
                                  });
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  '$quantity',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildQuantityButton(
                                icon: Icons.add,
                                onPressed: () {
                                  setState(() {
                                    final index = _selectedItems.indexWhere(
                                      (i) =>
                                          i.itemName.trim().toLowerCase() ==
                                          item.itemName.trim().toLowerCase(),
                                    );
                                    if (index >= 0) {
                                      _selectedItems[index] =
                                          ReservationMenuItem(
                                            itemName: item.itemName,
                                            quantity: quantity + 1,
                                            priceAed: discountedPrice,
                                          );
                                    } else {
                                      _selectedItems.add(
                                        ReservationMenuItem(
                                          itemName: item.itemName,
                                          quantity: 1,
                                          priceAed: discountedPrice,
                                        ),
                                      );
                                    }
                                  });
                                },
                              ),
                            ],
                          )
                        else
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedItems.add(
                                  ReservationMenuItem(
                                    itemName: item.itemName,
                                    quantity: 1,
                                    priceAed: discountedPrice,
                                  ),
                                );
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Add'),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        color: AppColors.textPrimary,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSelectedItemsCard() {
    final subtotal = _calculateSubtotal();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._selectedItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.quantity}x ${item.itemName}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'AED ${item.totalPrice.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFFFFC107),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'AED ${subtotal.toStringAsFixed(0)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'AED ${subtotal.toStringAsFixed(0)}',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
