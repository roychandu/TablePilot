// ignore_for_file: deprecated_member_use, empty_catches, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/cart_model.dart';
import '../../models/offer_model.dart';
import '../../models/order_model.dart';
import '../../services/cart_service.dart';
import '../../services/offer_service.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../aws/aws_fields.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final OfferService _offerService = OfferService();
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  Cart _cart = Cart();
  bool _isLoading = true;
  bool _isSendingOrder = false;
  List<OfferModel> _activeOffers = [];
  StreamSubscription<Cart>? _cartSubscription;
  StreamSubscription<List<OfferModel>>? _offersSubscription;

  @override
  void initState() {
    super.initState();
    _loadCart();
    _loadOffers();
    _subscribeToCartChanges();
    _subscribeToOffers();
  }

  void _subscribeToCartChanges() {
    _cartSubscription = _cartService.getCartStream().listen((cart) {
      if (mounted) {
        setState(() {
          _cart = cart;
        });
      }
    });
  }

  Future<void> _loadCart() async {
    try {
      final cart = await _cartService.getCart();
      if (mounted) {
        setState(() {
          _cart = cart;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(
    String itemId,
    int quantity,
    String itemName, {
    bool isIncrease = true,
  }) async {
    final success = await _cartService.updateItemQuantity(itemId, quantity);
    await _loadCart();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isIncrease
                ? 'Increased $itemName quantity'
                : 'Reduced $itemName quantity',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
          ),
          backgroundColor: isIncrease ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _removeItem(String itemId, String itemName) async {
    final success = await _cartService.removeItemFromCart(itemId);
    await _loadCart();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$itemName removed from cart',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear Cart',
          style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove all items from your cart?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cartService.clearCart();
      await _loadCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cart cleared',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _removeCoupon() async {
    await _cartService.removeCoupon();
    await _loadCart();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coupon removed',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
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

  // Check if an offer applies to a cart item
  bool _doesOfferApplyToCartItem(OfferModel offer, CartItem cartItem) {
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
  }

  // Get applicable offers for a cart item
  List<OfferModel> _getApplicableOffersForCartItem(CartItem cartItem) {
    return _activeOffers
        .where((offer) => _doesOfferApplyToCartItem(offer, cartItem))
        .toList();
  }

  // Calculate discounted price for cart item
  double _calculateDiscountedPriceForCartItem(CartItem cartItem) {
    final applicableOffers = _getApplicableOffersForCartItem(cartItem);
    if (applicableOffers.isEmpty) {
      return cartItem.priceAed;
    }

    // Apply first applicable offer (can be enhanced to apply best offer)
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
        // BOGO: every 2nd item is free, so calculate average price
        discountedPrice = cartItem.priceAed / 2;
        break;
      case OfferType.freeItemWithPurchase:
        // Free item with purchase: price remains same
        discountedPrice = cartItem.priceAed;
        break;
    }

    return discountedPrice;
  }

  // Calculate total discount amount
  double _calculateTotalDiscount() {
    double totalDiscount = 0.0;
    for (final item in _cart.items) {
      final originalPrice = item.priceAed * item.quantity;
      final discountedPrice =
          _calculateDiscountedPriceForCartItem(item) * item.quantity;
      totalDiscount += (originalPrice - discountedPrice).clamp(
        0.0,
        double.infinity,
      );
    }
    return totalDiscount;
  }

  // Calculate subtotal with discounts
  double _calculateSubtotalWithDiscounts() {
    double subtotal = 0.0;
    for (final item in _cart.items) {
      final discountedPrice = _calculateDiscountedPriceForCartItem(item);
      subtotal += discountedPrice * item.quantity;
    }
    return subtotal;
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cart.isEmpty
          ? _buildEmptyCart()
          : RefreshIndicator(
              onRefresh: _loadCart,
              color: AppColors.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Cart Items
                    ..._cart.items.map((item) => _buildCartItem(item)),
                    const SizedBox(height: 16),
                    // Discount Applied Section
                    if (_cart.appliedCouponCode != null)
                      _buildDiscountSection(),
                    const SizedBox(height: 16),
                    // Bill Summary
                    _buildBillSummary(),
                    const SizedBox(height: 16),
                    // Payment Information
                    _buildPaymentInfo(),
                    const SizedBox(height: 16),
                    // Priority Order Description
                    _buildPriorityOrderDescription(),
                    const SizedBox(height: 16),
                    // Send to Kitchen Button
                    _buildSendToKitchenButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.cardBackground,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'My Cart (${_cart.totalItems})',
        style: AppTextStyles.h4.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      actions: [
        if (!_cart.isEmpty)
          TextButton(
            onPressed: _clearCart,
            child: Text(
              'Clear All',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to get started',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemPriceWithOffer(CartItem item) {
    final applicableOffers = _getApplicableOffersForCartItem(item);
    final hasOffer = applicableOffers.isNotEmpty;
    final discountedPrice = _calculateDiscountedPriceForCartItem(item);
    final originalTotal = item.priceAed * item.quantity;
    final discountedTotal = discountedPrice * item.quantity;

    if (hasOffer && discountedPrice < item.priceAed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AED ${discountedTotal.toStringAsFixed(2)}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'AED ${originalTotal.toStringAsFixed(2)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    } else {
      return Text(
        'AED ${originalTotal.toStringAsFixed(2)}',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w700,
        ),
      );
    }
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Image (square)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 90,
              height: 90,
              color: AppColors.border,
              child: item.imagePath != null && item.imagePath!.isNotEmpty
                  ? Image.network(
                      item.imagePath!.startsWith('http')
                          ? item.imagePath!
                          : getUrlForUserUploadedImage(item.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.restaurant,
                        size: 32,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Icon(
                      Icons.restaurant,
                      size: 32,
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Name and Price Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.itemName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildItemPriceWithOffer(item),
                  ],
                ),
                // Description/Customization Notes
                if ((item.customizationNotes != null &&
                        item.customizationNotes!.isNotEmpty) ||
                    (item.description.isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.customizationNotes ?? item.description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                // Quantity Selector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (item.quantity > 1) {
                          _updateQuantity(
                            item.itemId,
                            item.quantity - 1,
                            item.itemName,
                            isIncrease: false,
                          );
                        } else {
                          _removeItem(item.itemId, item.itemName);
                        }
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.remove,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${item.quantity}',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        _updateQuantity(
                          item.itemId,
                          item.quantity + 1,
                          item.itemName,
                          isIncrease: true,
                        );
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_offer,
              color: AppColors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_cart.appliedCouponCode!.toUpperCase()} applied',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You saved AED ${_cart.discount.toStringAsFixed(2)} on this order',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _removeCoupon,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Remove',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTax(double subtotal) {
    final couponDiscount = _cart.appliedCouponCode != null
        ? _cart.discount
        : 0.0;
    final taxableAmount = (subtotal - couponDiscount).clamp(
      0.0,
      double.infinity,
    );
    return (taxableAmount * _cart.taxRate / 100).clamp(0.0, double.infinity);
  }

  Widget _buildBillSummary() {
    final subtotalWithDiscounts = _calculateSubtotalWithDiscounts();
    final totalOfferDiscount = _calculateTotalDiscount();
    final subtotalOriginal = _cart.subtotal;
    final couponDiscount = _cart.appliedCouponCode != null
        ? _cart.discount
        : 0.0;
    final tax = _calculateTax(subtotalWithDiscounts);
    final grandTotal = (subtotalWithDiscounts - couponDiscount + tax).clamp(
      0.0,
      double.infinity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BILL SUMMARY',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _buildBillRow(
                'Subtotal',
                'AED ${subtotalOriginal.toStringAsFixed(2)}',
                valueColor: AppColors.warning,
              ),
              if (totalOfferDiscount > 0) ...[
                const SizedBox(height: 8),
                _buildBillRow(
                  'Store Discount',
                  '-AED ${totalOfferDiscount.toStringAsFixed(2)}',
                  valueColor: AppColors.success,
                ),
              ],
              if (couponDiscount > 0) ...[
                const SizedBox(height: 8),
                _buildBillRow(
                  'Coupon Discount',
                  '-AED ${couponDiscount.toStringAsFixed(2)}',
                  valueColor: AppColors.success,
                ),
              ],
              const SizedBox(height: 8),
              _buildBillRow(
                'Taxes & Charges',
                'AED ${tax.toStringAsFixed(2)}',
                valueColor: AppColors.warning,
              ),
              const Divider(color: AppColors.border, height: 24),
              _buildBillRow(
                'Grand Total',
                'AED ${grandTotal.toStringAsFixed(2)}',
                valueColor: AppColors.warning,
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBillRow(
    String label,
    String value, {
    Color? valueColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                )
              : AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
        ),
        Text(
          value,
          style: isTotal
              ? AppTextStyles.bodyLarge.copyWith(
                  color: valueColor ?? AppColors.warning,
                  fontWeight: FontWeight.w700,
                )
              : AppTextStyles.bodyMedium.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.info_outline, color: AppColors.info, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment at Counter',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You will not be charged rightnow payment will be collected at counter upon arrival',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityOrderDescription() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.priority_high,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Priority Order',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your order will be prioritized when you come to the restaurant and pay at the counter. Prepare your order in advance for faster service!',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendToKitchenButton() {
    final subtotalWithDiscounts = _calculateSubtotalWithDiscounts();
    final couponDiscount = _cart.appliedCouponCode != null
        ? _cart.discount
        : 0.0;
    final tax = _calculateTax(subtotalWithDiscounts);
    final grandTotal = (subtotalWithDiscounts - couponDiscount + tax).clamp(
      0.0,
      double.infinity,
    );

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSendingOrder || _cart.isEmpty
            ? null
            : () => _sendOrderToKitchen(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.disabled,
        ),
        child: _isSendingOrder
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.restaurant_menu,
                    color: AppColors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Send to Kitchen',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(AED ${grandTotal.toStringAsFixed(0)})',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _sendOrderToKitchen() async {
    if (_cart.isEmpty) {
      return;
    }

    setState(() {
      _isSendingOrder = true;
    });

    try {
      // Get current user name
      String? userName;
      try {
        final userData = await _authService.getUserData();
        userName = userData['name'] as String?;
      } catch (e) {
        debugPrint('Error getting user name: $e');
      }

      // Calculate totals first (matching cart bill summary)
      final subtotalWithDiscounts = _calculateSubtotalWithDiscounts();
      final couponDiscount = _cart.appliedCouponCode != null
          ? _cart.discount
          : 0.0;
      final tax = _calculateTax(subtotalWithDiscounts);
      final serviceCharge = 0.0; // No service charge for takeaway orders
      // Grand total = subtotal (after offer discounts) - coupon discount + tax
      final grandTotal = (subtotalWithDiscounts - couponDiscount + tax).clamp(
        0.0,
        double.infinity,
      );

      // Convert cart items to order items (use discounted price if offers apply)
      // Note: The sum of these items should match subtotalWithDiscounts
      final orderItems = _cart.items.map((cartItem) {
        final discountedPrice = _calculateDiscountedPriceForCartItem(cartItem);
        return OrderItem(
          itemName: cartItem.itemName,
          quantity: cartItem.quantity,
          priceAed: discountedPrice,
        );
      }).toList();

      // Verify subtotal matches sum of order items
      final calculatedSubtotal = orderItems.fold<double>(
        0.0,
        (sum, item) => sum + (item.priceAed * item.quantity),
      );

      // Create order model
      final order = OrderModel(
        tableNumber: 0, // 0 indicates takeaway order (not a table reservation)
        numberOfGuests: 1, // Default for takeaway
        guestNames: userName != null && userName.isNotEmpty
            ? [userName]
            : ['Customer'],
        reservationTime:
            DateTime.now(), // Current time for takeaway (pickup time)
        status: OrderStatus.pending,
        items: orderItems,
        subtotal:
            calculatedSubtotal, // Use calculated subtotal to ensure accuracy
        serviceCharge: serviceCharge,
        total: grandTotal, // Final total including tax and discounts
      );

      // Create order in Firebase
      final orderId = await _orderService.createOrder(order);

      if (orderId != null && mounted) {
        // Clear cart after successful order creation
        await _cartService.clearCart();
        await _loadCart();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order sent to kitchen successfully!',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back after a short delay
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to create order');
      }
    } catch (e) {
      debugPrint('Error sending order to kitchen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send order to kitchen. Please try again.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOrder = false;
        });
      }
    }
  }
}
