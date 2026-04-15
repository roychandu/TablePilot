// ignore_for_file: empty_catches

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/cart_model.dart';
import '../models/menu_model.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Get current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Get cart reference for current user
  DatabaseReference get _cartRef {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }
    return _database.child('users').child(_userId!).child('cart');
  }

  // Get cart from Firebase
  Future<Cart> getCart() async {
    if (_userId == null) {
      return Cart();
    }

    try {
      final snapshot = await _cartRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        return Cart();
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      return Cart.fromMap(data);
    } catch (e) {
      return Cart();
    }
  }

  // Save cart to Firebase
  Future<bool> saveCart(Cart cart) async {
    if (_userId == null) {
      return false;
    }

    try {
      await _cartRef.set(cart.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Add item to cart
  Future<bool> addItemToCart(
    MenuItem menuItem, {
    String? customizationNotes,
    String? categoryName,
  }) async {
    try {
      final cart = await getCart();

      // Check if same item (same name and same customization) already exists in cart
      final customizationKey = customizationNotes ?? '';
      final existingItemIndex = cart.items.indexWhere(
        (item) =>
            item.itemName == menuItem.itemName &&
            (item.customizationNotes ?? '') == customizationKey,
      );

      List<CartItem> updatedItems;
      if (existingItemIndex >= 0) {
        // Update quantity if item exists (same name and customization)
        updatedItems = List<CartItem>.from(cart.items);
        final existingItem = updatedItems[existingItemIndex];
        updatedItems[existingItemIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
          categoryName:
              categoryName ??
              existingItem.categoryName, // Update category if provided
        );
      } else {
        // Add new item with unique ID
        final itemId = DateTime.now().millisecondsSinceEpoch.toString();
        updatedItems = [
          ...cart.items,
          CartItem(
            itemId: itemId,
            itemName: menuItem.itemName,
            description: menuItem.description,
            priceAed: menuItem.priceAed,
            imagePath: menuItem.imagePath,
            quantity: 1,
            customizationNotes: customizationNotes,
            categoryName: categoryName,
          ),
        ];
      }

      final updatedCart = cart.copyWith(items: updatedItems);
      return await saveCart(updatedCart);
    } catch (e) {
      return false;
    }
  }

  // Update item quantity in cart
  Future<bool> updateItemQuantity(String itemId, int quantity) async {
    try {
      if (quantity <= 0) {
        return await removeItemFromCart(itemId);
      }

      final cart = await getCart();
      final updatedItems = cart.items.map((item) {
        if (item.itemId == itemId) {
          return item.copyWith(quantity: quantity);
        }
        return item;
      }).toList();

      final updatedCart = cart.copyWith(items: updatedItems);
      return await saveCart(updatedCart);
    } catch (e) {
      return false;
    }
  }

  // Remove item from cart
  Future<bool> removeItemFromCart(String itemId) async {
    try {
      final cart = await getCart();
      final updatedItems = cart.items
          .where((item) => item.itemId != itemId)
          .toList();
      final updatedCart = cart.copyWith(items: updatedItems);
      return await saveCart(updatedCart);
    } catch (e) {
      return false;
    }
  }

  // Clear all items from cart
  Future<bool> clearCart() async {
    if (_userId == null) {
      return false;
    }

    try {
      await _cartRef.remove();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Apply coupon code
  Future<bool> applyCoupon(String couponCode, double discountAmount) async {
    try {
      final cart = await getCart();
      final updatedCart = cart.copyWith(
        appliedCouponCode: couponCode,
        discountAmount: discountAmount,
      );
      return await saveCart(updatedCart);
    } catch (e) {
      return false;
    }
  }

  // Remove coupon code
  Future<bool> removeCoupon() async {
    try {
      final cart = await getCart();
      final updatedCart = cart.copyWith(
        appliedCouponCode: null,
        discountAmount: null,
      );
      return await saveCart(updatedCart);
    } catch (e) {
      return false;
    }
  }

  // Get total item count in cart
  Future<int> getCartItemCount() async {
    final cart = await getCart();
    return cart.totalItems;
  }

  // Get quantity of a specific item in cart
  Future<int> getItemQuantity(
    MenuItem menuItem, {
    String? customizationNotes,
  }) async {
    final cart = await getCart();
    final customizationKey = customizationNotes ?? '';
    final existingItem = cart.items.firstWhere(
      (item) =>
          item.itemName == menuItem.itemName &&
          (item.customizationNotes ?? '') == customizationKey,
      orElse: () => CartItem(
        itemId: '',
        itemName: '',
        description: '',
        priceAed: 0.0,
        quantity: 0,
      ),
    );
    return existingItem.itemName == menuItem.itemName
        ? existingItem.quantity
        : 0;
  }

  // Get cart item by menu item name and customization
  Future<CartItem?> getCartItem(
    MenuItem menuItem, {
    String? customizationNotes,
  }) async {
    final cart = await getCart();
    final customizationKey = customizationNotes ?? '';
    try {
      return cart.items.firstWhere(
        (item) =>
            item.itemName == menuItem.itemName &&
            (item.customizationNotes ?? '') == customizationKey,
      );
    } catch (e) {
      return null;
    }
  }

  // Stream of cart changes (real-time from Firebase)
  Stream<Cart> getCartStream() {
    if (_userId == null) {
      return Stream.value(Cart());
    }

    return _cartRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) {
        return Cart();
      }

      try {
        final cartMap = data as Map<dynamic, dynamic>;
        return Cart.fromMap(cartMap);
      } catch (e) {
        return Cart();
      }
    });
  }
}
