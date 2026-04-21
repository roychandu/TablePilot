// ignore_for_file: deprecated_member_use, empty_catches, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_pilot/screens/reservation_tab/add_reservation_screen.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../services/bill_service.dart';
import '../../services/order_service.dart';
import '../../services/table_service.dart';
import '../../services/auth_service.dart';
import '../../services/table_booking_service.dart';
import '../../services/reservation_service.dart';
import '../../services/offer_service.dart';
import '../../services/menu_service.dart';
import '../../services/cart_service.dart';
import '../../models/order_model.dart';
import '../../models/table_booking_model.dart';
import '../../models/reservation_model.dart';
import '../../models/offer_model.dart';
import '../../models/menu_model.dart';
import '../../models/cart_model.dart';
import '../cart_tab/cart_screen.dart';
import '../profile_screen/profile_screen.dart';
import '../profile_screen/restaurant_profile_screen.dart';
import '../profile_screen/restaurant_menu_screen.dart';
import '../home_screen/home_screen.dart';
import '../offers_tab/offers_list_screen.dart';
import '../admin_tab/reservation_request_screen.dart';
import '../takeaway_tab/takeaway_screen.dart';
import '../../aws/aws_fields.dart';

/// Constants for responsive breakpoints and sizing
class _ResponsiveConstants {
  static const double tabletBreakpoint = 600.0;
  static const double desktopBreakpoint = 1200.0;
  static const double maxContentWidth = 1400.0;

  // Spacing
  static const double spacingMobile = 16.0;
  static const double spacingTablet = 24.0;
  static const double spacingDesktop = 32.0;
}

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key});

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen>
    with WidgetsBindingObserver {
  // Services
  final BillService _billService = BillService();
  final OrderService _orderService = OrderService();
  final TableService _tableService = TableService();
  final AuthService _authService = AuthService();
  final TableBookingService _tableBookingService = TableBookingService();
  final ReservationService _eventService = ReservationService();
  final OfferService _offerService = OfferService();
  final MenuService _menuService = MenuService();
  final CartService _cartService = CartService();

  // User data
  String? _profileImageUrl;
  bool _isAdmin = false;

  // Dashboard metrics
  double _revenue = 0.0;
  int _totalTables = 0;
  List<OrderModel> _recentOrders = [];
  List<OrderModel> _allOrders =
      []; // Store all orders for counting pending takeaway orders
  List<TableBookingModel> _recentTableBookings = [];
  List<ReservationModel> _recentEvents = [];
  List<ReservationModel> _allEvents =
      []; // Store all events for counting upcoming reservation requests
  int _activeTableBookings = 0;
  int _activeReservationsCount = 0;
  int _pendingApprovalsCount = 0;
  int _todaysOrdersCount = 0;

  // Floor data
  Map<int, int> _floorOccupancy = {};
  Map<int, int> _floorCapacity = {};
  Map<int, TableStatus> _tableStatuses = {};
  int _occupiedTablesCount = 0;

  // Offers (for customers)
  List<OfferModel> _activeOffers = [];
  PageController? _offersPageController;
  Timer? _offersAutoScrollTimer;
  int _currentOfferIndex = 0;

  // State management
  bool _isLoading = true;
  StreamSubscription<List<TableBookingModel>>? _bookingSubscription;
  StreamSubscription<Map<int, TableStatus>>? _tableSubscription;
  String? _lastAddedItemName;
  final TextEditingController _searchController = TextEditingController();

  // Menu data for non-admin users
  RestaurantMenu? _menu;
  String _selectedCategory = 'All';

  // Cart data for non-admin users
  int _cartItemCount = 0;
  Cart _cart = Cart();
  StreamSubscription<Cart>? _cartSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAdminStatus();
    _loadProfileImage();
    _loadDashboardData();
    _loadOffers();
    _bookingSubscription = _tableBookingService.getTableBookingsStream().listen(
      (bookings) {
        // Update bookings-driven metrics immediately without full reload
        _handleBookingsUpdate(bookings);
      },
    );
    _tableSubscription = _tableService.getTablesStream().listen((tables) {
      _handleTableStatusUpdate(tables);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh profile image when app comes to foreground
      _loadProfileImage();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh profile image and admin status when navigating back to this screen
    _checkAdminStatus();
    _loadProfileImage();
  }

  void _handleBookingsUpdate(List<TableBookingModel> bookings) {
    // Keep latest bookings sorted (latest first)
    final sorted = List<TableBookingModel>.from(bookings)
      ..sort((a, b) {
        final aDateTime = DateTime(
          a.bookingDate.year,
          a.bookingDate.month,
          a.bookingDate.day,
          a.bookingTime.hour,
          a.bookingTime.minute,
        );
        final bDateTime = DateTime(
          b.bookingDate.year,
          b.bookingDate.month,
          b.bookingDate.day,
          b.bookingTime.hour,
          b.bookingTime.minute,
        );
        return bDateTime.compareTo(aDateTime);
      });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Active table bookings (not completed/cancelled) for today
    final activeToday = sorted.where((booking) {
      final bookingDate = booking.bookingDate;
      final isToday =
          bookingDate.isAfter(
            startOfDay.subtract(const Duration(seconds: 1)),
          ) &&
          bookingDate.isBefore(endOfDay);
      if (!isToday) return false;
      return booking.status != TableBookingStatus.cancelled &&
          booking.status != TableBookingStatus.completed;
    }).length;

    // Recompute table occupancy using current table statuses and incoming bookings
    _recomputeTableOccupancy(sorted);

    setState(() {
      _recentTableBookings = sorted;
      _activeTableBookings = activeToday;
    });
  }

  void _handleTableStatusUpdate(Map<int, TableStatus> tables) {
    // Update table statuses and total tables, then recompute occupancy with latest bookings
    _tableStatuses = tables;
    if (tables.isNotEmpty) {
      _totalTables = tables.length;
    }
    _recomputeTableOccupancy(_recentTableBookings);
    setState(() {});
  }

  void _recomputeTableOccupancy(List<TableBookingModel> bookings) {
    final Map<int, int> occupancy = {};
    final Map<int, int> capacity = {};
    final tables = _tableStatuses;
    const tablesPerFloor = 10;

    // Build occupied tables from bookings for today (confirmed/seated)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final Set<int> occupiedTablesFromBookings = {};

    for (final booking in bookings) {
      final bookingDate = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
      );
      final isToday =
          bookingDate.year == today.year &&
          bookingDate.month == today.month &&
          bookingDate.day == today.day;
      if (!isToday) continue;

      // If guests are seated, table is occupied immediately (no time check needed)
      if (booking.status == TableBookingStatus.seated &&
          booking.tableNumber != null) {
        occupiedTablesFromBookings.add(booking.tableNumber!);
        continue;
      }

      // For confirmed bookings, check if booking time has arrived
      if (booking.status == TableBookingStatus.confirmed &&
          booking.tableNumber != null) {
        final bookingDateTime = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
          booking.bookingTime.hour,
          booking.bookingTime.minute,
        );
        // Consider confirmed booking active if time has arrived (within 15 min early window)
        if (now.isAfter(
          bookingDateTime.subtract(const Duration(minutes: 15)),
        )) {
          occupiedTablesFromBookings.add(booking.tableNumber!);
        }
      }
    }

    final totalTables = _totalTables;
    int occupiedTablesCount = 0;

    for (int tableNum = 1; tableNum <= totalTables; tableNum++) {
      final floorNum = ((tableNum - 1) ~/ tablesPerFloor) + 1;
      capacity[floorNum] = (capacity[floorNum] ?? 0) + 1;

      final tableStatus = tables[tableNum];
      final isOccupiedFromStatus =
          tableStatus == TableStatus.occupied ||
          tableStatus == TableStatus.reserved;
      final isOccupiedFromBooking = occupiedTablesFromBookings.contains(
        tableNum,
      );

      if (isOccupiedFromStatus || isOccupiedFromBooking) {
        occupancy[floorNum] = (occupancy[floorNum] ?? 0) + 1;
        occupiedTablesCount++;
      }
    }

    // Ensure four floors with at least 10 capacity as before
    for (int floor = 1; floor <= 4; floor++) {
      final currentCapacity = capacity[floor] ?? 0;
      capacity[floor] = currentCapacity >= tablesPerFloor
          ? currentCapacity
          : tablesPerFloor;
      occupancy.putIfAbsent(floor, () => 0);
    }

    setState(() {
      _floorOccupancy = occupancy;
      _floorCapacity = capacity;
      _occupiedTablesCount = occupiedTablesCount;
    });
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
    _cartSubscription?.cancel();
    _cartSubscription = _cartService.getCartStream().listen((cart) {
      if (mounted) {
        setState(() {
          _cart = cart;
          _cartItemCount = cart.totalItems;
        });
      }
    });
  }

  // Check if an offer applies to a menu item
  bool _doesOfferApply(OfferModel offer, MenuItem item, String? categoryName) {
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
      if (categoryName != null &&
          offer.categoryNames != null &&
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
  List<OfferModel> _getApplicableOffers(MenuItem item, String? categoryName) {
    return _activeOffers
        .where((offer) => _doesOfferApply(offer, item, categoryName))
        .toList();
  }

  // Calculate discounted price for an item
  double _calculateDiscountedPrice(MenuItem item, String? categoryName) {
    final applicableOffers = _getApplicableOffers(item, categoryName);
    if (applicableOffers.isEmpty) {
      return item.priceAed;
    }

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
        discountedPrice = item.priceAed;
        break;
    }

    return discountedPrice;
  }

  // Get best offer text for display
  String? _getOfferText(MenuItem item, String? categoryName) {
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
    WidgetsBinding.instance.removeObserver(this);
    _bookingSubscription?.cancel();
    _tableSubscription?.cancel();
    _cartSubscription?.cancel();
    _offersAutoScrollTimer?.cancel();
    _offersPageController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final currentUserEmail = _authService.currentUser?.email;
      if (mounted) {
        final isAdmin = currentUserEmail == 'test-admin@gmail.com';
        setState(() {
          _isAdmin = isAdmin;
        });
        // Load offers for all users (including admin)
        _loadOffers();
        // Load menu and cart for non-admin users
        if (!isAdmin) {
          _loadMenu();
          _loadCart();
          _subscribeToCart();
        }
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await _offerService.getActiveOffersForCustomers();
      if (mounted) {
        setState(() {
          _activeOffers = offers;
        });

        // Precache images for immediate display
        for (final offer in offers) {
          if (offer.bannerImageUrl != null &&
              offer.bannerImageUrl!.isNotEmpty) {
            final imageUrl = offer.bannerImageUrl!.startsWith('http')
                ? offer.bannerImageUrl!
                : getUrlForUserUploadedImage(offer.bannerImageUrl!);

            precacheImage(NetworkImage(imageUrl), context);
          }
        }

        // Initialize page controller and start auto-scroll if offers exist
        if (_activeOffers.isNotEmpty) {
          _initializeOffersCarousel();
        }
      }
    } catch (e) {
      debugPrint('Error loading offers: $e');
    }
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
        });

        debugPrint(
          'Menu merged successfully in home tab. Default categories: ${defaultMenu.categories.length}, '
          'Firebase categories: ${firebaseMenu.categories.length}, '
          'Total categories: ${mergedMenu.categories.length}',
        );
      }
    } catch (e) {
      debugPrint('Error loading menu: $e. Using default menu only.');
      // If there's an error, at least show default menu
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

  void _initializeOffersCarousel() {
    final offersToShow = _activeOffers.length > 3 ? 3 : _activeOffers.length;
    if (offersToShow <= 1) return; // No need for carousel if only one offer

    _offersPageController?.dispose();
    // Start from a middle index for infinite scrolling
    final initialIndex = offersToShow * 500; // Start in the middle
    _offersPageController = PageController(initialPage: initialIndex);
    _currentOfferIndex = 0;

    // Start auto-scroll timer (slower speed - 5 seconds)
    _offersAutoScrollTimer?.cancel();
    _offersAutoScrollTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) {
      if (!mounted || _offersPageController == null) {
        timer.cancel();
        return;
      }

      final offersToShow = _activeOffers.length > 3 ? 3 : _activeOffers.length;
      if (offersToShow <= 1) {
        timer.cancel();
        return;
      }

      final currentPage = _offersPageController!.page?.round() ?? 0;
      final nextPage = currentPage + 1;

      _offersPageController!.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _loadProfileImage() async {
    try {
      final userData = await _authService.getUserData().timeout(
        const Duration(seconds: 5),
      );
      final profileImageFromPrefs =
          (userData['profileImage'] ??
                  userData['photoURL'] ??
                  userData['photoUrl'])
              as String?;
      final currentUserPhoto = _authService.currentUser?.photoURL;
      final currentUserEmail = _authService.currentUser?.email;
      if (mounted) {
        setState(() {
          _profileImageUrl = _resolveProfileImage(
            profileImageFromPrefs,
            currentUserPhoto,
          );
          _isAdmin = currentUserEmail == 'test-admin@gmail.com';
        });
      }
    } catch (e) {
      // Silently fail - profile image loading shouldn't block the UI
      debugPrint('Error loading profile image: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load profile image separately for immediate updates
      _loadProfileImage();

      // Get today's date range
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Load today's bills
      final allBills = await _billService.getAllBills().timeout(
        const Duration(seconds: 12),
      );
      final todayBills = allBills.where((bill) {
        final paidAt = bill.paidAt;
        return paidAt.isAfter(startOfDay) && paidAt.isBefore(endOfDay);
      }).toList();

      // Calculate today's revenue from bills
      _revenue = todayBills.fold(0.0, (sum, bill) => sum + bill.finalTotal);

      // Load today's table bookings and include in revenue/active counts
      final allTableBookings = await _tableBookingService
          .getTableBookings()
          .timeout(const Duration(seconds: 12));
      final todayTableBookings = allTableBookings.where((booking) {
        final bookingDate = booking.bookingDate;
        return bookingDate.isAfter(
              startOfDay.subtract(const Duration(seconds: 1)),
            ) &&
            bookingDate.isBefore(endOfDay);
      }).toList();

      // Load events - use admin method if admin, otherwise use regular method
      final allEvents = _isAdmin
          ? await _eventService.getAllReservationsForAdmin().timeout(
              const Duration(seconds: 12),
            )
          : await _eventService.getReservations().timeout(
              const Duration(seconds: 12),
            );

      // Store all events for counting upcoming reservation requests
      _allEvents = allEvents;

      // Filter to only today's and upcoming reservations (exclude past reservations)
      final filteredEvents = allEvents.where((reservation) {
        final reservationDateOnly = DateTime(
          reservation.reservationDate.year,
          reservation.reservationDate.month,
          reservation.reservationDate.day,
        );
        // Include reservations for today or future dates (exclude past dates)
        return !reservationDateOnly.isBefore(startOfDay);
      }).toList();

      _recentEvents = List<ReservationModel>.from(filteredEvents)
        ..sort((a, b) => b.reservationDate.compareTo(a.reservationDate));

      // Filter to only today's and upcoming table bookings (exclude past bookings)
      final filteredTableBookings = allTableBookings.where((booking) {
        final bookingDateOnly = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
        );
        // Include bookings for today or future dates (exclude past dates)
        return !bookingDateOnly.isBefore(startOfDay);
      }).toList();

      // Recent table bookings (latest first)
      _recentTableBookings = List<TableBookingModel>.from(filteredTableBookings)
        ..sort((a, b) {
          final aDateTime = DateTime(
            a.bookingDate.year,
            a.bookingDate.month,
            a.bookingDate.day,
            a.bookingTime.hour,
            a.bookingTime.minute,
          );
          final bDateTime = DateTime(
            b.bookingDate.year,
            b.bookingDate.month,
            b.bookingDate.day,
            b.bookingTime.hour,
            b.bookingTime.minute,
          );
          return bDateTime.compareTo(aDateTime);
        });

      // Active table bookings (not completed/cancelled)
      _activeTableBookings = todayTableBookings.where((booking) {
        return booking.status != TableBookingStatus.cancelled &&
            booking.status != TableBookingStatus.completed;
      }).length;

      // Add table booking revenue (only completed bookings: menu items + 10% service charge)
      double tableBookingRevenue = 0.0;
      for (final booking in todayTableBookings) {
        // Only count completed table bookings
        if (booking.status == TableBookingStatus.completed) {
          double subtotal = 0.0;
          for (final item in booking.menuItems) {
            subtotal += item.totalPrice;
          }
          final serviceCharge = subtotal * 0.1;
          tableBookingRevenue += subtotal + serviceCharge;
        }
      }
      _revenue += tableBookingRevenue;

      // Add reservation revenue (only completed reservations)
      final todayReservations = allEvents.where((reservation) {
        final reservationDate = DateTime(
          reservation.reservationDate.year,
          reservation.reservationDate.month,
          reservation.reservationDate.day,
        );
        return reservationDate.isAfter(
              startOfDay.subtract(const Duration(seconds: 1)),
            ) &&
            reservationDate.isBefore(endOfDay);
      }).toList();

      // Calculate active reservations count (today's reservations that haven't passed their time)
      final currentTime = DateTime.now();
      _activeReservationsCount = todayReservations.where((reservation) {
        // Exclude cancelled and completed reservations
        if (reservation.status == ReservationStatus.cancelled ||
            reservation.status == ReservationStatus.completed) {
          return false;
        }

        // Check if reservation time has passed
        final reservationDateTime = DateTime(
          reservation.reservationDate.year,
          reservation.reservationDate.month,
          reservation.reservationDate.day,
          reservation.startTime.hour,
          reservation.startTime.minute,
        );

        // Only count reservations that haven't passed their start time (future or current)
        return !currentTime.isAfter(reservationDateTime);
      }).length;

      double reservationRevenue = 0.0;
      for (final reservation in todayReservations) {
        // Only count completed reservations
        if (reservation.status == ReservationStatus.completed) {
          final totalCost = reservation.estimatedTotalCost > 0
              ? reservation.estimatedTotalCost
              : reservation.totalCost;
          reservationRevenue += totalCost;
        }
      }
      _revenue += reservationRevenue;

      // Load orders - use admin method if admin, otherwise use regular method
      final allOrders = _isAdmin
          ? await _orderService.getAllNonAdminOrders().timeout(
              const Duration(seconds: 12),
            )
          : await _orderService.getOrders().timeout(
              const Duration(seconds: 12),
            );

      // Store all orders for counting pending takeaway orders
      _allOrders = allOrders;

      // Get today's orders for recent orders
      _recentOrders = allOrders.where((order) {
        final createdAt = order.createdAt;
        return createdAt.isAfter(startOfDay) && createdAt.isBefore(endOfDay);
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Count today's orders
      _todaysOrdersCount = _recentOrders.length;

      // Calculate pending approvals (pending orders + upcoming reservations + confirmed table bookings)
      int pendingOrders = _recentOrders
          .where((order) => order.status == OrderStatus.pending)
          .length;

      // Count upcoming reservations that need approval (upcoming status)
      int pendingReservations = filteredEvents
          .where(
            (reservation) => reservation.status == ReservationStatus.upcoming,
          )
          .length;

      // Count confirmed table bookings for today
      int pendingTableBookings = todayTableBookings
          .where((booking) => booking.status == TableBookingStatus.confirmed)
          .length;

      _pendingApprovalsCount =
          pendingOrders + pendingReservations + pendingTableBookings;

      // Load table data
      _totalTables = await _tableService.getTotalTables().timeout(
        const Duration(seconds: 12),
      );
      _tableStatuses = await _tableService.getTables().timeout(
        const Duration(seconds: 12),
      );
      await _updateTableOccupancy();
    } on TimeoutException {
      _showSnackBar('Request timed out. Please try again.');
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      _showSnackBar('Unable to load dashboard. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Update table occupancy based on table status and active bookings
  Future<void> _updateTableOccupancy() async {
    _floorOccupancy.clear();
    _floorCapacity.clear();
    _occupiedTablesCount = 0;

    try {
      final tables = await _tableService.getTables().timeout(
        const Duration(seconds: 12),
      );
      const tablesPerFloor = 10;

      // Get today's active table bookings
      final allTableBookings = await _tableBookingService
          .getTableBookings()
          .timeout(const Duration(seconds: 12));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Create a set of occupied tables from active bookings
      final Set<int> occupiedTablesFromBookings = {};

      for (final booking in allTableBookings) {
        // Check if booking is for today
        final bookingDate = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
        );
        final isToday =
            bookingDate.year == today.year &&
            bookingDate.month == today.month &&
            bookingDate.day == today.day;

        if (!isToday) continue;

        // If guests are seated, table is occupied immediately (no time check needed)
        if (booking.status == TableBookingStatus.seated &&
            booking.tableNumber != null) {
          occupiedTablesFromBookings.add(booking.tableNumber!);
          continue;
        }

        // For confirmed bookings, check if booking time has arrived
        if (booking.status == TableBookingStatus.confirmed &&
            booking.tableNumber != null) {
          final bookingDateTime = DateTime(
            booking.bookingDate.year,
            booking.bookingDate.month,
            booking.bookingDate.day,
            booking.bookingTime.hour,
            booking.bookingTime.minute,
          );

          // Consider confirmed booking active if time has arrived (within 15 min early window)
          // and hasn't exceeded the booking duration
          final bookingEndTime = bookingDateTime.add(
            Duration(
              hours: booking.durationHours.toInt(),
              minutes: ((booking.durationHours % 1) * 60).toInt(),
            ),
          );

          if (now.isAfter(
                bookingDateTime.subtract(const Duration(minutes: 15)),
              ) &&
              now.isBefore(bookingEndTime)) {
            occupiedTablesFromBookings.add(booking.tableNumber!);
          }
        }
      }

      int occupiedTablesCount = 0;
      for (int tableNum = 1; tableNum <= _totalTables; tableNum++) {
        final floorNum = ((tableNum - 1) ~/ tablesPerFloor) + 1;
        _floorCapacity[floorNum] = (_floorCapacity[floorNum] ?? 0) + 1;

        final tableStatus = tables[tableNum];
        final isOccupiedFromStatus =
            tableStatus == TableStatus.occupied ||
            tableStatus == TableStatus.reserved;
        final isOccupiedFromBooking = occupiedTablesFromBookings.contains(
          tableNum,
        );

        if (isOccupiedFromStatus || isOccupiedFromBooking) {
          _floorOccupancy[floorNum] = (_floorOccupancy[floorNum] ?? 0) + 1;
          occupiedTablesCount++;
        }
      }

      // Ensure we always have entries for four floors (even if empty) and show 10 tables each
      for (int floor = 1; floor <= 4; floor++) {
        final currentCapacity = _floorCapacity[floor] ?? 0;
        _floorCapacity[floor] = currentCapacity >= tablesPerFloor
            ? currentCapacity
            : tablesPerFloor;
        _floorOccupancy.putIfAbsent(floor, () => 0);
      }

      setState(() {
        _occupiedTablesCount = occupiedTablesCount;
      });
    } on TimeoutException {
      _showSnackBar('Request timed out. Please try again.');
    } catch (e) {
      debugPrint('Error calculating table occupancy: $e');
      _showSnackBar('Unable to update table occupancy.');
    }
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = AppColors.error,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > _ResponsiveConstants.tabletBreakpoint;
    final isDesktop = screenWidth > _ResponsiveConstants.desktopBreakpoint;

    final horizontalPadding = isDesktop
        ? _ResponsiveConstants.spacingDesktop
        : (isTablet
              ? _ResponsiveConstants.spacingTablet
              : _ResponsiveConstants.spacingMobile);
    final verticalSpacing = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header (Outside SafeArea to have background color till top)
                _buildHeader(),
                // Content
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: RefreshIndicator(
                      onRefresh: _loadDashboardData,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = isDesktop
                              ? _ResponsiveConstants.maxContentWidth
                              : double.infinity;
                          return SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 16,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxWidth),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Today's Overview (Admin only) or Search Bar (Non-admin)
                                    if (_isAdmin)
                                      _buildTodaysOverview(
                                        isTablet: isTablet,
                                        isDesktop: isDesktop,
                                      )
                                    else
                                      _buildSearchBar(
                                        isTablet: isTablet,
                                        isDesktop: isDesktop,
                                      ),
                                    SizedBox(height: verticalSpacing),
                                    // Active Offers
                                    if (_activeOffers.isNotEmpty) ...[
                                      _buildActiveOffers(),
                                      SizedBox(height: verticalSpacing),
                                    ],
                                    // Admin sections or Customer sections
                                    if (_isAdmin) ...[
                                      // Online Requests
                                      _buildOnlineRequests(),
                                      SizedBox(height: verticalSpacing),
                                      // Quick Actions
                                      _buildQuickActions(),
                                      SizedBox(height: verticalSpacing),
                                      // Upcoming Bookings
                                      _buildUpcomingBookings(),
                                      SizedBox(height: verticalSpacing),
                                      // Recent Orders
                                      _buildRecentOrders(),
                                    ] else ...[
                                      // Service Options
                                      _buildServiceOptions(),
                                      SizedBox(height: verticalSpacing),
                                      // Popular Menu Items
                                      _buildPopularMenuItems(),
                                      SizedBox(height: verticalSpacing),
                                      // Featured Items
                                      _buildFeaturedItems(
                                        isTablet: isTablet,
                                        isDesktop: isDesktop,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: !_isAdmin && _cartItemCount > 0
          ? _buildCartFAB()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > _ResponsiveConstants.tabletBreakpoint;
    final isDesktop = screenWidth > _ResponsiveConstants.desktopBreakpoint;
    final horizontalPadding = isDesktop
        ? _ResponsiveConstants.spacingDesktop
        : (isTablet ? _ResponsiveConstants.spacingTablet : 20.0);
    final verticalPadding = isDesktop ? 16.0 : (isTablet ? 14.0 : 14.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top:
            MediaQuery.paddingOf(context).top +
            (isDesktop ? 14 : (isTablet ? 12 : 10)),
        bottom: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.background, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RestaurantProfileScreen(),
                  ),
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.warning, AppColors.warning],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Image.asset(
                      'assets/restaurant-icon.png',
                      fit: BoxFit.contain,
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'SFC Plus - Southern Fried Chicken',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.border,
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildProfileAvatar(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return Image.network(
        _profileImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.person, color: AppColors.textPrimary, size: 18),
      );
    }

    return Icon(Icons.person, color: AppColors.textPrimary, size: 18);
  }

  String? _resolveProfileImage(String? storedImage, String? fallback) {
    if (storedImage != null && storedImage.isNotEmpty) {
      return storedImage.startsWith('http')
          ? storedImage
          : getUrlForUserUploadedImage(storedImage);
    }
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return null;
  }

  /// Calculate table occupancy percentage
  double _calculateTableOccupancy() {
    if (_totalTables == 0) return 0.0;

    // Calculate percentage based on occupied tables
    final percentage = (_occupiedTablesCount / _totalTables * 100).clamp(
      0.0,
      100.0,
    );

    // Round to nearest 5% increment
    return (percentage / 5).round() * 5.0;
  }

  Widget _buildTodaysOverview({bool isTablet = false, bool isDesktop = false}) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final tableOccupancy = _calculateTableOccupancy();
    // Active reservations count (today's reservations that haven't passed their time)
    final activeReservations = _activeReservationsCount;

    // Get horizontal padding to offset it
    final horizontalPadding = isDesktop
        ? _ResponsiveConstants.spacingDesktop
        : (isTablet
              ? _ResponsiveConstants.spacingTablet
              : _ResponsiveConstants.spacingMobile);

    // Compact fixed card height so there is no large empty space above/below
    final double cardHeight = isDesktop ? 140.0 : (isTablet ? 120.0 : 110.0);

    // Calculate card width - use 1/4th of screen width for each card (for 4 cards)
    final cardWidth = screenWidth * 0.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Overview",
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
          ),
        ),
        const SizedBox(height: 8),
        // Scrollable section extends to edges (no horizontal padding)
        SizedBox(
          height: cardHeight,
          child: OverflowBox(
            maxWidth: screenWidth,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(-horizontalPadding, 0),
              child: SizedBox(
                width: screenWidth,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: cardWidth,
                            child: _metricCard(
                              icon: Icons.my_location,
                              iconColor: AppColors.primary,
                              label: 'Table Occupancy',
                              value: '${tableOccupancy.toInt()}%',
                              valueColor: AppColors.primary,
                              height: cardHeight,
                              screenWidth: screenWidth,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: cardWidth,
                            child: _metricCard(
                              icon: Icons.calendar_today,
                              iconColor: AppColors.info,
                              label: 'Active Reservations',
                              value: '$activeReservations',
                              valueColor: AppColors.info,
                              height: cardHeight,
                              screenWidth: screenWidth,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: cardWidth,
                            child: _metricCard(
                              icon: Icons.receipt_long,
                              iconColor: AppColors.warning,
                              label: "Today's Orders",
                              value: '$_todaysOrdersCount',
                              valueColor: AppColors.warning,
                              height: cardHeight,
                              screenWidth: screenWidth,
                            ),
                          ),
                        ),
                        if (_isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: cardWidth,
                              child: _metricCard(
                                icon: Icons.pending_actions,
                                iconColor: AppColors.error,
                                label: 'Pending Approvals',
                                value: '$_pendingApprovalsCount',
                                valueColor: AppColors.error,
                                height: cardHeight,
                                screenWidth: screenWidth,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: cardWidth,
                          child: _metricCard(
                            icon: Icons.monetization_on_rounded,
                            iconColor: AppColors.secondary,
                            label: "Today's Revenue",
                            value: 'AED ${_revenue.toStringAsFixed(0)}',
                            valueColor: AppColors.secondary,
                            height: cardHeight,
                            screenWidth: screenWidth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar({bool isTablet = false, bool isDesktop = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: AppColors.textSecondary,
            size: isDesktop ? 20 : (isTablet ? 18 : 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search menu items, offers...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceOptions() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > _ResponsiveConstants.tabletBreakpoint;
    final isDesktop = screenWidth > _ResponsiveConstants.desktopBreakpoint;

    // Get horizontal padding to offset it
    final horizontalPadding = isDesktop
        ? _ResponsiveConstants.spacingDesktop
        : (isTablet
              ? _ResponsiveConstants.spacingTablet
              : _ResponsiveConstants.spacingMobile);

    // Service options section extends to edges (no horizontal padding)
    return SizedBox(
      height: 120,
      child: OverflowBox(
        maxWidth: screenWidth,
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          offset: Offset(-horizontalPadding, 0),
          child: SizedBox(
            width: screenWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 6),
                    child: _serviceOptionCard(
                      topText: 'Skip the Line',
                      mainText: 'Order online',
                      bottomText: 'Order will be fastracked',
                      gradientColors: const [
                        AppColors.cardBackground, // Dark blue-grey
                        Color(0xFFFF6B4A), // Vibrant orange-red
                      ],
                      backgroundImage: 'assets/order-take.png',
                      onTap: () {
                        // Navigate to menu tab
                        final homeScreenState = context
                            .findAncestorStateOfType<HomeScreenState>();
                        homeScreenState?.switchToTab(3);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, right: 8),
                    child: _serviceOptionCard(
                      topText: 'Book Table',
                      mainText: 'Reserve Table',
                      bottomText: 'Order will be fastracked',
                      gradientColors: const [
                        AppColors.cardBackground, // Dark blue-grey
                        AppColors.success, // Deep green
                      ],
                      backgroundImage: 'assets/reserve-table.png',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddReservationScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _serviceOptionCard({
    required String topText,
    required String mainText,
    required String bottomText,
    required List<Color> gradientColors,
    required String backgroundImage,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  backgroundImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading background image: $error');
                    return Container(color: gradientColors[0]);
                  },
                ),
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      gradientColors[0].withOpacity(0.6),
                      gradientColors[1].withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top text
                  Text(
                    topText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Main text and bottom text grouped together
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main text
                      Text(
                        mainText,
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Bottom text
                      Text(
                        bottomText,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularMenuItems() {
    if (_menu == null || _menu!.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate popular items from today's orders
    final Map<String, int> itemOrderCounts = {};
    for (final order in _recentOrders) {
      for (final orderItem in order.items) {
        itemOrderCounts[orderItem.itemName] =
            (itemOrderCounts[orderItem.itemName] ?? 0) + orderItem.quantity;
      }
    }

    // Get all menu items from all categories
    final allItems = <MenuItem>[];
    for (final category in _menu!.categories) {
      allItems.addAll(category.items);
    }

    // Sort all items by order count (most popular first)
    final sortedItems =
        allItems
            .map(
              (item) => {
                'item': item,
                'count': itemOrderCounts[item.itemName] ?? 0,
              },
            )
            .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    // Get top 3 items overall (regardless of category)
    // If items have orders, show those; otherwise show first 3 items from sorted list
    final itemsToShow = sortedItems
        .take(3)
        .map((entry) => entry['item'] as MenuItem)
        .toList();

    if (itemsToShow.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > _ResponsiveConstants.tabletBreakpoint;
    final isDesktop = screenWidth > _ResponsiveConstants.desktopBreakpoint;

    // Get horizontal padding to offset it
    final horizontalPadding = isDesktop
        ? _ResponsiveConstants.spacingDesktop
        : (isTablet
              ? _ResponsiveConstants.spacingTablet
              : _ResponsiveConstants.spacingMobile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title, subtitle, and View All button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Popular Menu Items',
                    style: AppTextStyles.h4.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Most ordered items today',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to menu screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RestaurantMenuScreen(),
                  ),
                );
              },
              child: Text(
                'View All',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Popular items section extends to edges (no horizontal padding)
        SizedBox(
          height: 180,
          child: OverflowBox(
            maxWidth: screenWidth,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(-horizontalPadding, 0),
              child: SizedBox(
                width: screenWidth,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: itemsToShow.length,
                  itemBuilder: (context, index) {
                    final item = itemsToShow[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < itemsToShow.length - 1 ? 16 : 0,
                      ),
                      child: _buildPopularMenuItemCard(item),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPopularMenuItemCard(MenuItem item) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular frame with light pink background
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5E5), // Light pink background
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: item.imagePath != null && item.imagePath!.isNotEmpty
                  ? Image.network(
                      item.imagePath!.startsWith('http')
                          ? item.imagePath!
                          : getUrlForUserUploadedImage(item.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.restaurant,
                        size: 50,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Icon(
                      Icons.restaurant,
                      size: 50,
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Item name
          Text(
            item.itemName,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Chef Special tag
          Text(
            'Chef Special',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedItems({bool isTablet = false, bool isDesktop = false}) {
    if (_menu == null) {
      return const SizedBox.shrink();
    }

    // Get items based on selected category
    List<MenuItem> filteredItems;
    if (_selectedCategory == 'All') {
      // Get all menu items from all categories
      filteredItems = [];
      for (final category in _menu!.categories) {
        filteredItems.addAll(category.items);
      }
    } else {
      // Get items from selected category
      final selectedCategory = _menu!.categories.firstWhere(
        (cat) => cat.categoryName == _selectedCategory,
        orElse: () => _menu!.categories.first,
      );
      filteredItems = selectedCategory.items;
    }

    // Limit to featured items (first 4-8 items)
    final featuredItems = filteredItems.take(8).toList();

    if (featuredItems.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Featured Items',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No items available',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured Items',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final crossAxisCount = isDesktop ? 3 : (isTablet ? 3 : 2);
            final spacing = 12.0;
            final availableWidth =
                screenWidth - (spacing * (crossAxisCount - 1));
            final cardWidth = availableWidth / crossAxisCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: featuredItems.map((item) {
                // Find category for this item
                String? itemCategory;
                for (final category in _menu!.categories) {
                  if (category.items.any((i) => i.itemName == item.itemName)) {
                    itemCategory = category.categoryName;
                    break;
                  }
                }
                return SizedBox(
                  width: cardWidth,
                  child: _buildMenuItemCard(
                    item: item,
                    categoryName: itemCategory,
                    cardWidth: cardWidth,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuItemCard({
    required MenuItem item,
    String? categoryName,
    required double cardWidth,
  }) {
    // Responsive calculations based on card width
    final cardPadding = (cardWidth * 0.04).clamp(6.0, 12.0);
    final imageHeight = (cardWidth * 0.75).clamp(120.0, 220.0);
    final itemNameFontSize = (cardWidth * 0.065).clamp(11.0, 16.0);
    final priceFontSize = (cardWidth * 0.07).clamp(12.0, 16.0);
    final iconSize = (cardWidth * 0.25).clamp(32.0, 56.0);
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
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image Section
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
                  color: AppColors.border,
                  child: item.imagePath != null && item.imagePath!.isNotEmpty
                      ? Image.network(
                          item.imagePath!.startsWith('http')
                              ? item.imagePath!
                              : getUrlForUserUploadedImage(item.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.restaurant,
                            size: iconSize,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Icon(
                          Icons.restaurant,
                          size: iconSize,
                          color: AppColors.textSecondary,
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
                            color: AppColors.black.withOpacity(0.2),
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
          // Content Section
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.itemName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: itemNameFontSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: spacingMedium),
                // Price and Rating in Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: _buildPriceWithOffer(
                        item,
                        categoryName,
                        priceFontSize,
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

  Widget _buildPriceWithOffer(
    MenuItem item,
    String? categoryName,
    double baseFontSize,
  ) {
    final applicableOffers = _getApplicableOffers(item, categoryName);
    final hasOffer = applicableOffers.isNotEmpty;
    final discountedPrice = hasOffer
        ? _calculateDiscountedPrice(item, categoryName)
        : item.priceAed;

    final mainPriceFontSize = baseFontSize;
    final strikethroughFontSize = (baseFontSize * 0.75).clamp(9.0, 12.0);
    final spacing = 6.0;

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
    final customizationKey = '';
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

    final buttonSize = (cardWidth * 0.16).clamp(24.0, 36.0);
    final iconSize = (cardWidth * 0.08).clamp(14.0, 22.0);
    final quantityFontSize = (cardWidth * 0.07).clamp(12.0, 16.0);
    final spacing = (cardWidth * 0.03).clamp(4.0, 8.0);

    if (!isInCart) {
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
                color: AppColors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.add, color: AppColors.black, size: iconSize),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Text(
              '$quantity',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w700,
                fontSize: quantityFontSize,
              ),
            ),
            SizedBox(width: spacing),
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

  Widget _buildCartFAB() {
    if (_cartItemCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 60,
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            ).then((_) {
              _loadCart();
            });
          },
          backgroundColor: AppColors.primary,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          label: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    color: AppColors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_cartItemCount Items',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'View Cart',
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
              const SizedBox(width: 40),
              Row(
                children: [
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

  Widget _metricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required double height,
    required double screenWidth,
  }) {
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenWidth < 360;

    // Match compact dark tiles like the provided design
    final cardHeight = height.clamp(68.0, 88.0);
    final valueFontSize = isTablet ? 22.0 : (isSmallScreen ? 16.0 : 18.0);
    final labelFontSize = isTablet ? 16.0 : 14.0;

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white.withOpacity(0.05), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title (can be single or two lines like in the reference image)
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
              fontSize: labelFontSize,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Value
          Text(
            value,
            style: AppTextStyles.h4.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: valueFontSize,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOffers() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > _ResponsiveConstants.tabletBreakpoint;
    final isDesktop = screenWidth > _ResponsiveConstants.desktopBreakpoint;

    // Get horizontal padding to offset it
    final horizontalPadding = isDesktop
        ? _ResponsiveConstants.spacingDesktop
        : (isTablet
              ? _ResponsiveConstants.spacingTablet
              : _ResponsiveConstants.spacingMobile);

    // If only one offer, display it as a static card without carousel/auto-scroll
    if (_activeOffers.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isAdmin) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Promotions',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _buildOfferCard(_activeOffers.first),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only show title for admin users
        if (_isAdmin) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Promotions',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_activeOffers.length > 3)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OffersListScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View All',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Carousel section extends to edges (no horizontal padding)
        SizedBox(
          height: 180,
          child: OverflowBox(
            maxWidth: screenWidth,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(-horizontalPadding, 0),
              child: SizedBox(
                width: screenWidth,
                child: PageView.builder(
                  controller: _offersPageController,
                  onPageChanged: (index) {
                    final offersToShow = _activeOffers.length > 3
                        ? 3
                        : _activeOffers.length;
                    final actualIndex = index % offersToShow;
                    setState(() {
                      _currentOfferIndex = actualIndex;
                    });
                  },
                  itemCount: 10000, // Large number for infinite scrolling
                  padEnds: false,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final offersToShow = _activeOffers.length > 3
                        ? 3
                        : _activeOffers.length;
                    final actualIndex = index % offersToShow;
                    final offer = _activeOffers[actualIndex];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildOfferCard(offer),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Carousel Indicator
        if ((_activeOffers.length > 3 ? 3 : _activeOffers.length) > 1)
          _buildCarouselIndicator(),
      ],
    );
  }

  Widget _buildOfferCard(OfferModel offer) {
    String discountText = '';
    switch (offer.offerType) {
      case OfferType.percentageDiscount:
        discountText = '${offer.discountValue.toInt()}% OFF';
        break;
      case OfferType.fixedAmountOff:
        discountText = 'AED ${offer.discountValue.toStringAsFixed(0)} OFF';
        break;
      case OfferType.buyOneGetOne:
        discountText = 'BOGO';
        break;
      case OfferType.freeItemWithPurchase:
        discountText = 'FREE ITEM';
        break;
    }

    return GestureDetector(
      onTap: () {
        // Navigate to Offers tab
        final homeScreenState = context
            .findAncestorStateOfType<HomeScreenState>();
        homeScreenState?.switchToTab(2);
      },
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.9),
              AppColors.primary.withOpacity(0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image if available
            if (offer.bannerImageUrl != null &&
                offer.bannerImageUrl!.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    offer.bannerImageUrl!.startsWith('http')
                        ? offer.bannerImageUrl!
                        : getUrlForUserUploadedImage(offer.bannerImageUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            // Lighter gradient overlay to highlight the image
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.black.withOpacity(0.2),
                    AppColors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
            // Active badge (top right)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Active',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Discount badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      discountText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselIndicator() {
    final offersToShow = _activeOffers.length > 3 ? 3 : _activeOffers.length;
    if (offersToShow <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        offersToShow,
        (index) => Container(
          width: _currentOfferIndex == index ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _currentOfferIndex == index
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    // Combine takeaway orders and table bookings, then sort by creation date
    final takeawayOrders = _recentOrders
        .where((order) => order.tableNumber == 0)
        .toList();

    // Create a combined list with both types
    final List<Map<String, dynamic>> combinedItems = [];

    // Add takeaway orders
    for (final order in takeawayOrders) {
      combinedItems.add({
        'type': 'takeaway',
        'order': order,
        'createdAt': order.createdAt,
      });
    }

    // Add table bookings
    for (final booking in _recentTableBookings) {
      combinedItems.add({
        'type': 'table',
        'booking': booking,
        'createdAt': booking.createdAt,
      });
    }

    // Sort by creation date (newest first)
    combinedItems.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Orders',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (combinedItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
            child: Column(
              children: [
                Image.asset(
                  'assets/no_active.png',
                  width: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.receipt_long,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'No orders yet today',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Single container with all orders
          Builder(
            builder: (context) {
              final itemsToShow = combinedItems.take(3).toList();
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ...itemsToShow.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;

                      if (item['type'] == 'takeaway') {
                        final order = item['order'] as OrderModel;
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final orderDateOnly = DateTime(
                          order.createdAt.year,
                          order.createdAt.month,
                          order.createdAt.day,
                        );
                        final isToday = orderDateOnly.isAtSameMomentAs(today);
                        final dateLabel = isToday
                            ? 'Today'
                            : _formatDate(order.createdAt);
                        final timeStr = _formatTime(order.createdAt);
                        final guestName = order.guestNames.isNotEmpty
                            ? order.guestNames.first
                            : 'Customer';

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Order type and name
                                        Text(
                                          'Takeaway • $guestName',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Items and date/time
                                        Text(
                                          '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'} • Created: $dateLabel, $timeStr',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Total amount aligned to right
                                  Text(
                                    'AED ${order.total.toStringAsFixed(2)}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Divider (except for last item)
                            if (index < itemsToShow.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.border.withOpacity(0.3),
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      } else {
                        // Table booking
                        final booking = item['booking'] as TableBookingModel;
                        final bookingDateTime = DateTime(
                          booking.bookingDate.year,
                          booking.bookingDate.month,
                          booking.bookingDate.day,
                          booking.bookingTime.hour,
                          booking.bookingTime.minute,
                        );
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final bookingDateOnly = DateTime(
                          booking.bookingDate.year,
                          booking.bookingDate.month,
                          booking.bookingDate.day,
                        );
                        final isToday = bookingDateOnly.isAtSameMomentAs(today);
                        final dateLabel = isToday
                            ? 'Today'
                            : _formatDate(booking.bookingDate);
                        final timeStr = _formatTime(bookingDateTime);
                        final createdAt = booking.createdAt;
                        final createdAtDateOnly = DateTime(
                          createdAt.year,
                          createdAt.month,
                          createdAt.day,
                        );
                        final isCreatedToday = createdAtDateOnly
                            .isAtSameMomentAs(today);
                        final createdDateLabel = isCreatedToday
                            ? 'Today'
                            : _formatDate(createdAt);
                        final createdTimeStr = _formatTime(createdAt);
                        final guestName =
                            booking.guestName != null &&
                                booking.guestName!.isNotEmpty
                            ? booking.guestName!
                            : 'Guest';
                        // Calculate subtotal of menu items
                        final subtotal = booking.menuItems.fold<double>(
                          0,
                          (sum, item) => sum + item.totalPrice,
                        );

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Table number and guest name
                                        Text(
                                          'Table ${booking.tableNumber != null ? '${booking.tableNumber}' : 'N/A'} • $guestName',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Booking date and time
                                        Text(
                                          'Booking: $dateLabel, $timeStr | ${booking.numberOfGuests} Guests',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        // Created date and time
                                        Text(
                                          'Created: $createdDateLabel, $createdTimeStr',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Total amount aligned to right
                                  Text(
                                    'AED ${subtotal.toStringAsFixed(2)}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Divider (except for last item)
                            if (index < itemsToShow.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.border.withOpacity(0.3),
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      }
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildOnlineRequests() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > _ResponsiveConstants.tabletBreakpoint;
    final isDesktop = screenWidth > _ResponsiveConstants.desktopBreakpoint;

    // Get horizontal padding to offset it
    final horizontalPadding = isDesktop
        ? _ResponsiveConstants.spacingDesktop
        : (isTablet
              ? _ResponsiveConstants.spacingTablet
              : _ResponsiveConstants.spacingMobile);

    // Calculate counts
    // Takeaway orders: tableNumber == 0 indicates takeaway order
    // Use all orders, not just today's, to get all pending takeaway orders
    final takeawayOrdersCount = _allOrders
        .where(
          (order) =>
              order.status == OrderStatus.pending && order.tableNumber == 0,
        )
        .length;
    // Reservation requests: upcoming status indicates pending request
    // Use all events, not just recent ones, to get all upcoming reservation requests
    final reservationRequestsCount = _allEvents
        .where(
          (reservation) => reservation.status == ReservationStatus.upcoming,
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and View All button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Online Requests',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to requests screen or show all
                final homeScreenState = context
                    .findAncestorStateOfType<HomeScreenState>();
                homeScreenState?.switchToTab(2);
              },
              child: Text(
                'View All',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Cards section extends to edges (no horizontal padding)
        SizedBox(
          height: 120,
          child: OverflowBox(
            maxWidth: screenWidth,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(-horizontalPadding, 0),
              child: SizedBox(
                width: screenWidth,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: _buildOnlineRequestCard(
                          title: 'Open Online Orders',
                          count: takeawayOrdersCount,
                          gradientColors: const [
                            AppColors.cardBackground, // Dark blue-grey
                            Color(0xFFFF6B4A), // Vibrant orange-red
                          ],
                          backgroundImage: 'assets/order-take.png',
                          onTap: () {
                            // Navigate to takeaway orders screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TakeawayScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 16),
                        child: _buildOnlineRequestCard(
                          title: 'Online Reservation Request',
                          count: reservationRequestsCount,
                          gradientColors: const [
                            AppColors.cardBackground, // Dark blue-grey
                            AppColors.success, // Deep green
                          ],
                          backgroundImage: 'assets/reserve-table.png',
                          onTap: () async {
                            // Navigate to reservation requests and reload on return
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ReservationRequestScreen(),
                              ),
                            );
                            _loadDashboardData();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineRequestCard({
    required String title,
    required int count,
    required List<Color> gradientColors,
    required String backgroundImage,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  backgroundImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading background image: $error');
                    return Container(color: gradientColors[0]);
                  },
                ),
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      gradientColors[0].withOpacity(0.6),
                      gradientColors[1].withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Count
                  Text(
                    '$count',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Quick Actions',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Two buttons side-by-side
        Row(
          children: [
            Expanded(
              child: _quickActionButton(
                label: 'Assign Tables',
                onTap: () {
                  final homeScreenState = context
                      .findAncestorStateOfType<HomeScreenState>();
                  homeScreenState?.switchToTab(2);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionButton(
                label: 'Create Offers',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OffersListScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground, // Dark purplish-grey
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingBookings() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter to show only confirmed reservations (status == completed) that are upcoming
    final upcomingReservations = _allEvents.where((reservation) {
      final reservationDateOnly = DateTime(
        reservation.reservationDate.year,
        reservation.reservationDate.month,
        reservation.reservationDate.day,
      );
      return reservation.status == ReservationStatus.completed &&
          !reservationDateOnly.isBefore(today);
    }).toList()..sort((a, b) => a.reservationDate.compareTo(b.reservationDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Reservations',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReservationRequestScreen(),
                  ),
                );
                _loadDashboardData();
              },
              child: Text(
                'View All',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (upcomingReservations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
            child: Column(
              children: [
                Image.asset(
                  'assets/no_active.png',
                  width: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.event_note,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'No upcoming reservations',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Single container with all reservations
          Builder(
            builder: (context) {
              final reservationsToShow = upcomingReservations.take(3).toList();
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ...reservationsToShow.asMap().entries.map((entry) {
                      final index = entry.key;
                      final event = entry.value;
                      final eventDate = event.reservationDate;
                      final eventDateTime = DateTime(
                        eventDate.year,
                        eventDate.month,
                        eventDate.day,
                        event.startTime.hour,
                        event.startTime.minute,
                      );

                      // Check if reservation is today
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final reservationDateOnly = DateTime(
                        eventDate.year,
                        eventDate.month,
                        eventDate.day,
                      );
                      final isToday = reservationDateOnly.isAtSameMomentAs(
                        today,
                      );

                      final dateLabel = isToday
                          ? 'Today'
                          : _formatDate(eventDate);
                      final timeStr = _formatTime(eventDateTime);

                      // Booking date and time (when reservation was created)
                      final bookingDateTime = event.createdAt;
                      final bookingDateOnly = DateTime(
                        bookingDateTime.year,
                        bookingDateTime.month,
                        bookingDateTime.day,
                      );
                      final isBookingToday = bookingDateOnly.isAtSameMomentAs(
                        today,
                      );
                      final bookingDateLabel = isBookingToday
                          ? 'Today'
                          : _formatDate(bookingDateTime);
                      final bookingTimeStr = _formatTime(bookingDateTime);

                      // Format table number(s)
                      String tableText = '';
                      if (event.tableNumber != null) {
                        tableText = 'Table ${event.tableNumber}';
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Name
                                      Text(
                                        event.reservationName,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Reservation date and time
                                      Text(
                                        'Reservation: $dateLabel, $timeStr | ${event.numberOfGuests} Guests',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Booking date and time
                                      Text(
                                        'Booked: $bookingDateLabel, $bookingTimeStr',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Table number aligned to right
                                if (tableText.isNotEmpty)
                                  Text(
                                    tableText,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Divider (except for last item)
                          if (index < reservationsToShow.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.border.withOpacity(0.3),
                              indent: 16,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
