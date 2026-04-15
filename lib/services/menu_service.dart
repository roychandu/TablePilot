// ignore_for_file: empty_catches

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/menu_model.dart';

class MenuService {
  static final MenuService _instance = MenuService._internal();
  factory MenuService() => _instance;
  MenuService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  RestaurantMenu? _cachedMenu;

  // Get current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Find admin user ID by email
  Future<String?> _findAdminUserId() async {
    try {
      final usersSnapshot = await _database.child('users').get();
      if (!usersSnapshot.exists) return null;

      final users = usersSnapshot.value as Map<dynamic, dynamic>;
      for (final entry in users.entries) {
        final userId = entry.key as String;
        final userData = entry.value as Map<dynamic, dynamic>;
        final profile = userData['profile'] as Map<dynamic, dynamic>?;
        if (profile != null) {
          final email = profile['email'] as String?;
          if (email == 'test-admin@gmail.com') {
            return userId;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get menu from a specific user's path
  Future<RestaurantMenu?> _getMenuFromUserPath(String userId) async {
    try {
      final snapshot = await _database
          .child('users')
          .child(userId)
          .child('menu')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final menu = RestaurantMenu.fromMap(data);
        // Only return menu if it has categories
        if (menu.categories.isNotEmpty) {
          return menu;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get menu from Firebase (read-only, no auto-save)
  // For non-admin users, falls back to admin's menu if their menu is empty
  Future<RestaurantMenu> getMenuFromFirebase() async {
    if (_userId == null) {
      // Return empty menu if no user
      _cachedMenu = RestaurantMenu(categories: []);
      return _cachedMenu!;
    }

    // First, try to load menu from current user's path
    final userMenu = await _getMenuFromUserPath(_userId!);
    if (userMenu != null) {
      _cachedMenu = userMenu;
      return _cachedMenu!;
    }

    // If current user's menu is empty, try to load from admin's menu
    final adminUserId = await _findAdminUserId();
    if (adminUserId != null && adminUserId != _userId) {
      final adminMenu = await _getMenuFromUserPath(adminUserId);
      if (adminMenu != null) {
        _cachedMenu = adminMenu;
        return _cachedMenu!;
      }
    }

    // If both are empty, return empty menu
    _cachedMenu = RestaurantMenu(categories: []);
    return _cachedMenu!;
  }

  // Get menu stream for real-time updates
  Stream<RestaurantMenu> getMenuStream() {
    if (_userId == null) {
      return Stream.value(RestaurantMenu(categories: []));
    }

    return _database
        .child('users')
        .child(_userId!)
        .child('menu')
        .onValue
        .asyncMap((event) async {
          if (event.snapshot.exists && event.snapshot.value != null) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            final menu = RestaurantMenu.fromMap(data);
            if (menu.categories.isNotEmpty) {
              _cachedMenu = menu;
              return _cachedMenu!;
            }
          }

          // If current user's menu is empty, try to load from admin's menu
          final adminUserId = await _findAdminUserId();
          if (adminUserId != null && adminUserId != _userId) {
            final adminMenu = await _getMenuFromUserPath(adminUserId);
            if (adminMenu != null) {
              _cachedMenu = adminMenu;
              return _cachedMenu!;
            }
          }

          _cachedMenu = RestaurantMenu(categories: []);
          return _cachedMenu!;
        });
  }

  // Save menu to Firebase - DISABLED: Menu should not be stored in database
  // Keeping method signature for compatibility but it does nothing
  @Deprecated(
    'Menu should not be saved to Firebase. Use default menu from model instead.',
  )
  Future<bool> saveMenuToFirebase(RestaurantMenu menu) async {
    // Do not save menu to Firebase - menu data should only come from model
    _cachedMenu = menu;
    return true;
  }

  // Save menu to Firebase (for admin use)
  Future<bool> saveMenu(RestaurantMenu menu) async {
    if (_userId == null) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(_userId!)
          .child('menu')
          .set(menu.toMap());
      // Clear cache to force reload from Firebase on next getMenu() call
      _cachedMenu = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get cached menu (if available)
  RestaurantMenu? getCachedMenu() {
    return _cachedMenu;
  }

  // Clear cached menu
  void clearCache() {
    _cachedMenu = null;
  }

  // Get menu from Firebase only
  Future<RestaurantMenu> getMenu() async {
    return await getMenuFromFirebase();
  }

  // Search items by name
  List<MenuItem> searchItems(String query) {
    final menu = _cachedMenu ?? RestaurantMenu(categories: []);
    if (menu.categories.isEmpty) return [];

    final searchQuery = query.toLowerCase();
    final results = <MenuItem>[];

    for (final category in menu.categories) {
      for (final item in category.items) {
        if (item.itemName.toLowerCase().contains(searchQuery) ||
            item.description.toLowerCase().contains(searchQuery)) {
          results.add(item);
        }
      }
    }

    return results;
  }

  // Get items by category name
  List<MenuItem> getItemsByCategory(String categoryName) {
    final menu = _cachedMenu ?? RestaurantMenu(categories: []);
    if (menu.categories.isEmpty) return [];

    final category = menu.categories.firstWhere(
      (cat) => cat.categoryName.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => MenuCategory(categoryName: '', items: []),
    );

    return category.items;
  }

  // Get all category names
  List<String> getCategoryNames() {
    final menu = _cachedMenu ?? RestaurantMenu(categories: []);
    if (menu.categories.isEmpty) return [];

    return menu.categories.map((category) => category.categoryName).toList();
  }

  // Get menu item by name
  MenuItem? getItemByName(String itemName) {
    final menu = _cachedMenu ?? RestaurantMenu(categories: []);
    if (menu.categories.isEmpty) return null;

    for (final category in menu.categories) {
      try {
        return category.items.firstWhere(
          (item) => item.itemName.toLowerCase() == itemName.toLowerCase(),
        );
      } catch (e) {
        // Continue searching in next category
      }
    }

    return null;
  }

  // Initialize menu cache (loads from Firebase)
  Future<void> initializeMenu() async {
    if (_cachedMenu == null) {
      await getMenuFromFirebase();
    }
  }

  // Get all menu items (flattened list)
  List<MenuItem> getAllItems() {
    final menu = _cachedMenu ?? RestaurantMenu(categories: []);
    final items = <MenuItem>[];

    for (final category in menu.categories) {
      items.addAll(category.items);
    }

    return items;
  }

  // Get menu item by exact match (case-sensitive)
  MenuItem? getItemByExactName(String itemName) {
    final menu = _cachedMenu ?? RestaurantMenu(categories: []);

    for (final category in menu.categories) {
      try {
        return category.items.firstWhere((item) => item.itemName == itemName);
      } catch (e) {
        // Continue searching in next category
      }
    }

    return null;
  }
}
