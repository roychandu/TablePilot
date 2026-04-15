// ignore_for_file: deprecated_member_use, empty_catches, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/menu_model.dart';
import '../../models/cart_model.dart';
import '../../models/offer_model.dart';
import '../../services/menu_service.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/offer_service.dart';
import '../../aws/aws_fields.dart';
import '../cart_tab/cart_screen.dart';
import '../admin_tab/add_menu_screen.dart';

class RestaurantMenuScreen extends StatefulWidget {
  const RestaurantMenuScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final MenuService _menuService = MenuService();
  final AuthService _authService = AuthService();
  final CartService _cartService = CartService();
  final OfferService _offerService = OfferService();
  RestaurantMenu? _menu;
  bool _isLoading = true;
  bool _isAdmin = false;
  int _cartItemCount = 0;
  Cart _cart = Cart();
  List<OfferModel> _activeOffers = [];
  StreamSubscription<Cart>? _cartSubscription;
  StreamSubscription<List<OfferModel>>? _offersSubscription;
  String? _lastAddedItemName;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadMenu();
    if (!_isAdmin) {
      _loadCart();
      _subscribeToCart();
      _loadOffers();
      _subscribeToOffers();
    }
  }

  Future<void> _checkAdminStatus() async {
    try {
      final currentUserEmail = _authService.currentUser?.email;
      if (mounted) {
        final isAdmin = currentUserEmail == 'test-admin@gmail.com';
        setState(() {
          _isAdmin = isAdmin;
        });
        if (!isAdmin) {
          _loadCart();
          _subscribeToCart();
        }
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload menu when returning to this screen (e.g., after adding menu items)
    // Only reload if menu was already loaded (not on first build) and not currently loading
    if (_menu != null && !_isLoading) {
      _loadMenu();
    }
    if (!_isAdmin) {
      _loadCart();
    }
  }

  Future<void> _loadCart() async {
    try {
      final cart = await _cartService.getCart();
      if (mounted) {
        setState(() {
          _cart = cart;
          _cartItemCount = cart.totalItems;
        });
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  void _subscribeToCart() {
    // Cancel existing subscription if any
    _cartSubscription?.cancel();
    // Subscribe to cart stream for real-time updates
    _cartSubscription = _cartService.getCartStream().listen((cart) {
      if (mounted) {
        setState(() {
          _cart = cart;
          _cartItemCount = cart.totalItems;
        });
      }
    });
  }

  Future<void> _loadMenu() async {
    try {
      // Always start with the default predefined menu
      final defaultMenu = RestaurantMenu.getDefaultMenu();

      // Try to load menu from Firebase (admin-added items)
      RestaurantMenu firebaseMenu;
      try {
        firebaseMenu = await _menuService.getMenu();
      } catch (e) {
        debugPrint('Error loading menu from Firebase: $e');
        firebaseMenu = RestaurantMenu(categories: []);
      }

      // Merge default menu with Firebase menu (admin-added items)
      final mergedMenu = _mergeMenus(defaultMenu, firebaseMenu);

      if (mounted) {
        setState(() {
          _menu = mergedMenu;
          _isLoading = false;
        });

        debugPrint(
          'Menu merged successfully. Default categories: ${defaultMenu.categories.length}, '
          'Firebase categories: ${firebaseMenu.categories.length}, '
          'Total categories: ${mergedMenu.categories.length}',
        );
        for (final category in mergedMenu.categories) {
          debugPrint(
            '  - ${category.categoryName}: ${category.items.length} items',
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading menu: $e. Using default menu only.');
      // If there's an error, at least show default menu
      if (mounted) {
        setState(() {
          _menu = RestaurantMenu.getDefaultMenu();
          _isLoading = false;
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
      // If no Firebase menu, just return default menu
      return defaultMenu;
    }

    // Create a map of categories by name for quick lookup
    final Map<String, MenuCategory> mergedCategoriesMap = {};

    // First, add all default menu categories
    for (final category in defaultMenu.categories) {
      mergedCategoriesMap[category.categoryName.toUpperCase()] = category;
    }

    // Then, merge or add Firebase menu categories
    for (final firebaseCategory in firebaseMenu.categories) {
      final categoryKey = firebaseCategory.categoryName.toUpperCase();

      if (mergedCategoriesMap.containsKey(categoryKey)) {
        // Category exists in both - merge items (avoid duplicates)
        final existingCategory = mergedCategoriesMap[categoryKey]!;
        final existingItemNames = existingCategory.items
            .map((item) => item.itemName.toUpperCase())
            .toSet();

        // Add Firebase items that don't already exist
        final newItems = firebaseCategory.items
            .where(
              (item) =>
                  !existingItemNames.contains(item.itemName.toUpperCase()),
            )
            .toList();

        // Merge items: existing items first, then new Firebase items
        mergedCategoriesMap[categoryKey] = MenuCategory(
          categoryName: existingCategory.categoryName,
          section: existingCategory.section ?? firebaseCategory.section,
          items: [...existingCategory.items, ...newItems],
        );
      } else {
        // New category from Firebase - add it
        mergedCategoriesMap[categoryKey] = firebaseCategory;
      }
    }

    // Convert back to list, maintaining order: default categories first, then new Firebase categories
    final List<MenuCategory> mergedCategories = [];
    final Set<String> addedCategoryNames = {};

    // Add default categories first (in their original order)
    for (final category in defaultMenu.categories) {
      mergedCategories.add(
        mergedCategoriesMap[category.categoryName.toUpperCase()]!,
      );
      addedCategoryNames.add(category.categoryName.toUpperCase());
    }

    // Add new Firebase categories (that weren't in default menu)
    for (final firebaseCategory in firebaseMenu.categories) {
      final categoryKey = firebaseCategory.categoryName.toUpperCase();
      if (!addedCategoryNames.contains(categoryKey)) {
        mergedCategories.add(mergedCategoriesMap[categoryKey]!);
        addedCategoryNames.add(categoryKey);
      }
    }

    return RestaurantMenu(categories: mergedCategories);
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

  void _subscribeToOffers() {
    _offersSubscription?.cancel();
    _offersSubscription = _offerService.getAllOffersForCustomersStream().listen(
      (offers) {
        if (mounted) {
          final activeOffers = offers
              .where(
                (offer) =>
                    offer.status == OfferStatus.active &&
                    offer.visibleToCustomers,
              )
              .toList();
          setState(() {
            _activeOffers = activeOffers;
          });
        }
      },
    );
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
          offer.categoryNames!.any(
            (name) => name.toLowerCase() == categoryName.toLowerCase(),
          )) {
        return true;
      }
    }

    if (offer.applyTo.contains(OfferApplyTo.specificItems)) {
      if (offer.itemNames != null &&
          offer.itemNames!.any(
            (name) => name.toLowerCase() == item.itemName.toLowerCase(),
          )) {
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

    // For now, apply the first applicable offer (can be enhanced to apply best offer)
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
      case OfferType.buyOneGetOne:
        // BOGO: every 2nd item is free, so calculate average price per item for total calculations
        discountedPrice = item.priceAed / 2;
        break;
      case OfferType.freeItemWithPurchase:
        // Free item with purchase: price remains same
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

  // Get applicable offers for a cart item
  List<OfferModel> _getApplicableOffersForCartItem(CartItem cartItem) {
    return _activeOffers.where((offer) {
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
        if (cartItem.categoryName != null &&
            offer.categoryNames != null &&
            offer.categoryNames!.any(
              (name) =>
                  name.toLowerCase() == cartItem.categoryName!.toLowerCase(),
            )) {
          return true;
        }
      }

      if (offer.applyTo.contains(OfferApplyTo.specificItems)) {
        if (offer.itemNames != null &&
            offer.itemNames!.any(
              (name) => name.toLowerCase() == cartItem.itemName.toLowerCase(),
            )) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  // Calculate discounted price for cart item
  double _calculateDiscountedPriceForCartItem(CartItem cartItem) {
    final applicableOffers = _getApplicableOffersForCartItem(cartItem);
    if (applicableOffers.isEmpty) {
      return cartItem.priceAed;
    }

    final offer = applicableOffers.first;
    double discountedPrice = cartItem.priceAed;

    switch (offer.offerType) {
      case OfferType.percentageDiscount:
        discountedPrice = cartItem.priceAed * (1 - offer.discountValue / 100);
        break;
      case OfferType.fixedAmountOff:
        discountedPrice = (cartItem.priceAed - offer.discountValue).clamp(
          0.0,
          double.infinity,
        );
        break;
      case OfferType.buyOneGetOne:
        discountedPrice = cartItem.priceAed / 2;
        break;
      case OfferType.freeItemWithPurchase:
        discountedPrice = cartItem.priceAed;
        break;
    }

    return discountedPrice;
  }

  // Calculate subtotal including offers (excluding tax)
  double _calculateSubtotalWithOffers() {
    double subtotalWithDiscounts = 0.0;
    for (final item in _cart.items) {
      final discountedPrice = _calculateDiscountedPriceForCartItem(item);
      subtotalWithDiscounts += discountedPrice * item.quantity;
    }

    final couponDiscount = _cart.discount;
    return (subtotalWithDiscounts - couponDiscount).clamp(0.0, double.infinity);
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    _offersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadMenu,
        color: AppColors.primary,
        child: _isLoading
            ? _buildLoadingState()
            : _menu == null
            ? _buildEmptyState()
            : _buildAllCategoriesList(),
      ),
      floatingActionButton: _isAdmin
          ? _buildAddItemFAB()
          : (_cartItemCount > 0 ? _buildCartFAB() : null),
      floatingActionButtonLocation: _isAdmin
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCartFAB() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartScreen()),
          ).then((_) {
            // Refresh cart when returning from cart screen
            _loadCart();
          });
        },
        elevation: 8,
        highlightElevation: 12,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Stack(
          children: [
            const Icon(
              Icons.shopping_cart_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ],
        ),
        label: SizedBox(
          width: MediaQuery.of(context).size.width * 0.65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'View Cart',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  Text(
                    '$_cartItemCount ${_cartItemCount == 1 ? 'item' : 'items'}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 16,
                    color: AppColors.white.withOpacity(0.3),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AED ${_calculateSubtotalWithOffers().toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddItemFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddMenuScreen()),
        ).then((_) {
          // Refresh menu when returning from add menu screen
          _loadMenu();
        });
      },
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add, color: AppColors.white),
      label: Text(
        'Add Item',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Restaurant Menu',
        style: AppTextStyles.h4.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      leading: widget.showBackButton
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      automaticallyImplyLeading: widget.showBackButton,
      backgroundColor: AppColors.cardBackground,
      elevation: 0,
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.border.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Menu...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.border.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                size: 48,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Menu Available',
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again later',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCategoriesList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth > 600;
        final parentPadding = isTablet ? 20.0 : 16.0;
        final margin = isTablet ? 16.0 : 12.0;

        // Calculate card width: 50% of screen width for more compact cards
        final cardWidth = (screenWidth * 0.50).clamp(180.0, 240.0);
        // Derive a tight card height so horizontal list doesn't add extra vertical space
        final cardPadding = (cardWidth * 0.04).clamp(6.0, 12.0);
        final imageHeight = (cardWidth * 0.75).clamp(120.0, 220.0);
        final itemNameFontSize = (cardWidth * 0.065).clamp(11.0, 16.0);
        final priceFontSize = (cardWidth * 0.07).clamp(12.0, 16.0);
        final spacingBetweenText = (cardWidth * 0.03).clamp(6.0, 8.0);
        // Account for line heights (typically 1.2-1.5x font size) and potential price wrapping
        final itemNameLineHeight = itemNameFontSize * 1.2;
        final priceLineHeight = priceFontSize * 1.2;
        // image + top/bottom padding + text with line heights + spacing + buffer for overflow
        final cardHeight =
            imageHeight +
            (cardPadding * 2) +
            itemNameLineHeight +
            spacingBetweenText +
            (priceLineHeight * 1.5) + // Allow for potential wrapping
            16; // Increased buffer to prevent overflow

        return ListView.builder(
          physics:
              const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
          padding: EdgeInsets.only(
            left: 0,
            right: 0,
            top: parentPadding,
            bottom: _cartItemCount > 0 ? 100 : parentPadding,
          ),
          itemCount: _menu!.categories.length,
          itemBuilder: (context, categoryIndex) {
            final category = _menu!.categories[categoryIndex];
            final items = category.items;

            if (items.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Name Header
                Padding(
                  padding: EdgeInsets.only(
                    left: parentPadding,
                    right: parentPadding,
                    bottom: isTablet ? 16 : 12,
                    top: categoryIndex > 0 ? (isTablet ? 24 : 20) : 0,
                  ),
                  child: Text(
                    category.categoryName,
                    style: AppTextStyles.h4.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: isTablet ? 22 : 20,
                    ),
                  ),
                ),
                // Menu Items for this category in a horizontal row - use tight height to avoid extra space
                SizedBox(
                  height: cardHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(
                      left: parentPadding,
                      right: parentPadding,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, itemIndex) {
                      return Container(
                        width: cardWidth,
                        margin: EdgeInsets.only(
                          right: itemIndex < items.length - 1 ? margin : 0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildMenuItemCard(
                            item: items[itemIndex],
                            screenWidth: cardWidth,
                            categoryName: category.categoryName,
                            cardWidth: cardWidth,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMenuItemCard({
    required MenuItem item,
    required double screenWidth,
    required String categoryName,
    required double cardWidth,
  }) {
    // Responsive calculations based on card width
    final cardPadding = (cardWidth * 0.04).clamp(6.0, 12.0);
    final imageHeight = (cardWidth * 0.75).clamp(120.0, 220.0);
    final itemNameFontSize = (cardWidth * 0.065).clamp(11.0, 16.0);
    final priceFontSize = (cardWidth * 0.07).clamp(12.0, 16.0);
    final ratingFontSize = (cardWidth * 0.055).clamp(10.0, 13.0);
    final iconSize = (cardWidth * 0.25).clamp(32.0, 56.0);
    final spacingSmall = (cardWidth * 0.02).clamp(4.0, 6.0);
    final spacingMedium = (cardWidth * 0.03).clamp(6.0, 8.0);
    final badgePaddingH = (cardWidth * 0.04).clamp(6.0, 10.0);
    final badgePaddingV = (cardWidth * 0.02).clamp(3.0, 5.0);
    final badgeFontSize = (cardWidth * 0.05).clamp(8.0, 11.0);
    final badgePosition = (cardWidth * 0.04).clamp(6.0, 10.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image Section with Add Button Overlay
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Stack(
              children: [
                Container(
                  height: imageHeight,
                  width: double.infinity,
                  color: AppColors.background2,
                  child: item.imagePath != null && item.imagePath!.isNotEmpty
                      ? Image.network(
                          item.imagePath!.startsWith('http')
                              ? item.imagePath!
                              : getUrlForUserUploadedImage(item.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.restaurant_menu,
                              size: iconSize,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.restaurant_menu,
                            size: iconSize,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                        ),
                ),
                // Offer Badge (top left)
                if (!_isAdmin &&
                    _getApplicableOffers(item, categoryName).isNotEmpty)
                  Positioned(
                    top: badgePosition,
                    left: badgePosition,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: badgePaddingH,
                        vertical: badgePaddingV,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _getOfferText(item, categoryName) ?? 'OFFER',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: badgeFontSize,
                        ),
                      ),
                    ),
                  ),
                // Quantity Selector or Add Button Overlay (bottom right) - Only show for non-admin users
                if (!_isAdmin)
                  Positioned(
                    bottom: badgePosition,
                    right: badgePosition,
                    child: _buildQuantitySelector(
                      item,
                      cardWidth,
                      categoryName: categoryName,
                    ),
                  ),
              ],
            ),
          ),
          // Content Section - using IntrinsicHeight to prevent extra space
          IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Item Name
                  Text(
                    item.itemName,
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: itemNameFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacingMedium),
                  // Price with offer display
                  _buildPriceWithOffer(item, categoryName, priceFontSize),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceWithOffer(
    MenuItem item,
    String categoryName,
    double baseFontSize,
  ) {
    final applicableOffers = _getApplicableOffers(item, categoryName);
    final hasOffer = applicableOffers.isNotEmpty;
    final discountedPrice = hasOffer
        ? _calculateDiscountedPrice(item, categoryName)
        : item.priceAed;

    // Responsive font sizes for price
    final mainPriceFontSize = baseFontSize;
    final strikethroughFontSize = (baseFontSize * 0.75).clamp(9.0, 12.0);
    final spacing = 6.0; // Fixed spacing for price wrap

    if (hasOffer && discountedPrice < item.priceAed) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: spacing,
        children: [
          Text(
            'AED ${discountedPrice.toStringAsFixed(2)}',
            style: AppTextStyles.h6.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
              fontSize: mainPriceFontSize,
            ),
          ),
          Text(
            'AED ${item.priceAed.toStringAsFixed(2)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
              fontSize: strikethroughFontSize,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    } else {
      return Text(
        'AED ${item.priceAed.toStringAsFixed(2)}',
        style: AppTextStyles.h6.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: mainPriceFontSize,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  Widget _buildQuantitySelector(
    MenuItem item,
    double cardWidth, {
    String? categoryName,
  }) {
    // Responsive button sizes
    final buttonSize = (cardWidth * 0.16).clamp(24.0, 36.0);
    final iconSize = (cardWidth * 0.08).clamp(14.0, 22.0);
    final quantityFontSize = (cardWidth * 0.07).clamp(12.0, 16.0);
    final spacing = (cardWidth * 0.03).clamp(4.0, 8.0);
    // Find item in cart
    final customizationKey = ''; // For now, no customizations
    CartItem? cartItem;
    try {
      cartItem = _cart.items.firstWhere(
        (cartItem) =>
            cartItem.itemName == item.itemName &&
            (cartItem.customizationNotes ?? '') == customizationKey,
      );
    } catch (e) {
      cartItem = null;
    }

    final isInCart = cartItem != null && cartItem.quantity > 0;
    final quantity = cartItem?.quantity ?? 0;

    if (!isInCart) {
      // Show + button when item is not in cart
      return GestureDetector(
        onTap: () async {
          final success = await _cartService.addItemToCart(
            item,
            categoryName: categoryName,
          );
          if (success && mounted) {
            if (_lastAddedItemName != item.itemName) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${item.itemName} added to cart',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 1),
                ),
              );
              _lastAddedItemName = item.itemName;
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to add item to cart',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                ),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.add, color: AppColors.black, size: iconSize),
        ),
      );
    } else {
      // Show quantity selector (- count +) when item is in cart
      return Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minus button
            GestureDetector(
              onTap: () async {
                if (cartItem != null) {
                  bool success;
                  String message;
                  if (quantity > 1) {
                    success = await _cartService.updateItemQuantity(
                      cartItem.itemId,
                      quantity - 1,
                    );
                    message = 'Reduced ${item.itemName} quantity';
                  } else {
                    success = await _cartService.removeItemFromCart(
                      cartItem.itemId,
                    );
                    message = '${item.itemName} removed from cart';
                  }

                  if (success && mounted) {
                    _lastAddedItemName =
                        null; // Clear so adding again shows snackbar
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          message,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        backgroundColor: AppColors.error,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                }
              },
              child: Container(
                width: buttonSize * 0.875,
                height: buttonSize * 0.875,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.remove,
                  color: AppColors.white,
                  size: iconSize * 0.8,
                ),
              ),
            ),
            SizedBox(width: spacing),
            // Quantity
            Text(
              '$quantity',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w700,
                fontSize: quantityFontSize,
              ),
            ),
            SizedBox(width: spacing),
            // Plus button
            GestureDetector(
              onTap: () async {
                if (cartItem != null) {
                  final success = await _cartService.updateItemQuantity(
                    cartItem.itemId,
                    quantity + 1,
                  );
                  if (success && mounted) {
                    if (_lastAddedItemName != item.itemName) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Increased ${item.itemName} quantity',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      _lastAddedItemName = item.itemName;
                    }
                  }
                }
              },
              child: Container(
                width: buttonSize * 0.875,
                height: buttonSize * 0.875,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: AppColors.white,
                  size: iconSize * 0.8,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
