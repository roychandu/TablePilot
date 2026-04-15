import '../aws/aws_static_images.dart';

class RestaurantMenu {
  final List<MenuCategory> categories;

  RestaurantMenu({required this.categories});

  // Convert from JSON Map
  factory RestaurantMenu.fromJson(Map<String, dynamic> json) {
    final menuData = json['restaurant_menu'] as Map<String, dynamic>? ?? json;
    final categoriesList = menuData['categories'] as List<dynamic>? ?? [];

    return RestaurantMenu(
      categories: categoriesList
          .map(
            (category) =>
                MenuCategory.fromJson(category as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  // Convert to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'restaurant_menu': {
        'categories': categories.map((category) => category.toJson()).toList(),
      },
    };
  }

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'categories': categories.map((category) => category.toMap()).toList(),
    };
  }

  // Create from Map (from Firebase)
  factory RestaurantMenu.fromMap(Map<dynamic, dynamic> map) {
    return RestaurantMenu(
      categories: (map['categories'] as List<dynamic>? ?? [])
          .map(
            (category) =>
                MenuCategory.fromMap(category as Map<dynamic, dynamic>),
          )
          .toList(),
    );
  }

  // Copy with method
  RestaurantMenu copyWith({List<MenuCategory>? categories}) {
    return RestaurantMenu(categories: categories ?? this.categories);
  }

  // Get default menu data (embedded in code)
  static RestaurantMenu getDefaultMenu() {
    String cdn(String fileName) => getStaticImageUrl(fileName);

    final menu = RestaurantMenu(
      categories: [
        MenuCategory(
          categoryName: 'BEST SELLERS',
          items: [
            MenuItem(
              itemName: 'Super Dinner Box',
              description: 'Complete dinner box with delicious favorites.',
              priceAed: 42,
              imagePath: cdn('Super Dinner Box.jpg'),
            ),
            MenuItem(
              itemName: 'Wrap Max Box Combo',
              description: 'Satisfying wrap combo box.',
              priceAed: 20,
              imagePath: cdn('Wrap Max Box Combo.jpg'),
            ),
          ],
        ),
        MenuCategory(
          categoryName: 'DEALS FOR SHARING',
          items: [
            MenuItem(
              itemName: '30 Pieces Chicken Strips',
              description: 'Perfect for sharing — 30 crispy chicken strips.',
              priceAed: 129,
              imagePath: cdn('30 Pieces Chicken Strips.jpg'),
            ),
            MenuItem(
              itemName: '40 Pieces Chicken Strips',
              description: 'Large sharing pack — 40 crispy chicken strips.',
              priceAed: 167,
              imagePath: cdn('40 Pieces Chicken Strips.jpg'),
            ),
            MenuItem(
              itemName: '20 Pieces Chicken Strips',
              description: 'Great for sharing — 20 crispy chicken strips.',
              priceAed: 110,
              imagePath: cdn('20 Pieces Chicken Strips.jpg'),
            ),
          ],
        ),
        MenuCategory(
          categoryName: 'INDIVIDUAL MEALS',
          items: [
            MenuItem(
              itemName: 'Snack Box Combo',
              description: 'Perfect snack combo box.',
              priceAed: 28,
              imagePath: cdn('Snack Box Combo.jpg'),
            ),
            MenuItem(
              itemName: 'Mighty Grande Meal',
              description: 'Grande meal with all favorites.',
              priceAed: 40,
              imagePath: cdn('Mighty Grande Meal.jpg'),
            ),
            MenuItem(
              itemName: '2 Pieces Chicken and Rice',
              description: 'Two pieces of chicken with rice.',
              priceAed: 34,
              imagePath: cdn('2 Pieces Chicken and Rice.jpg'),
            ),
            MenuItem(
              itemName: 'Mighty Box',
              description: 'Mighty box with delicious options.',
              priceAed: 48,
              imagePath: cdn('Mighty Box.jpg'),
            ),
            MenuItem(
              itemName: 'Quesadilla Meal',
              description: 'Satisfying quesadilla meal.',
              priceAed: 42,
              imagePath: cdn('Quesadilla Meal.jpg'),
            ),
            MenuItem(
              itemName: 'Chicken Grande Meal',
              description: 'Grande chicken meal.',
              priceAed: 34,
              imagePath: cdn('Chicken Grande Meal.jpg'),
            ),
          ],
        ),
        MenuCategory(
          categoryName: 'SIGNATURE BURGERS',
          items: [
            MenuItem(
              itemName: 'Angus Beef Burger',
              description: 'Premium angus beef burger.',
              priceAed: 34,
              imagePath: cdn('Angus Beef Burger.jpg'),
            ),
            MenuItem(
              itemName: 'Buffalo Chicken Burger',
              description: 'Spicy buffalo chicken burger.',
              priceAed: 36,
              imagePath: cdn('Buffalo Chicken Burger.jpg'),
            ),
            MenuItem(
              itemName: 'Chicken Fire Burger',
              description: 'Fiery hot chicken burger.',
              priceAed: 42,
              imagePath: cdn('Chicken Fire Burger.jpg'),
            ),
          ],
        ),
        MenuCategory(
          categoryName: 'SANDWICHES & WRAPS',
          items: [
            MenuItem(
              itemName: 'Original Beef Burger',
              description: 'Classic original beef burger.',
              priceAed: 27,
              imagePath: cdn('Original Beef Burger.jpg'),
            ),
            MenuItem(
              itemName: 'Wrap Max Box',
              description: 'Max wrap box combo.',
              priceAed: 26,
              imagePath: cdn('Wrap Max Box.jpg'),
            ),
            MenuItem(
              itemName: 'Wrap Sandwich',
              description: 'Delicious wrap sandwich.',
              priceAed: 19,
              imagePath: cdn('Wrap Sandwich.jpg'),
            ),
            MenuItem(
              itemName: 'Chicken Deluxe',
              description: 'Deluxe chicken sandwich.',
              priceAed: 26,
              imagePath: cdn('Chicken Deluxe.jpg'),
            ),
            MenuItem(
              itemName: 'Vegetable Burger',
              description: 'Fresh vegetable burger.',
              priceAed: 23,
              imagePath: cdn('Vegetable Burger.jpg'),
            ),
          ],
        ),
        MenuCategory(
          categoryName: 'SALAD, SIDES & DESSERTS',
          items: [
            MenuItem(
              itemName: 'Chicken Nuggets',
              description: 'Crispy chicken nuggets.',
              priceAed: 17,
              imagePath: cdn('Chicken Nuggets.jpg'),
            ),
            MenuItem(
              itemName: 'Hot Garlic Bread',
              description: 'Hot and crispy garlic bread.',
              priceAed: 12,
              imagePath: cdn('Hot Garlic Bread.jpg'),
            ),
            MenuItem(
              itemName: 'Cheese Garlic Bread',
              description: 'Cheesy garlic bread.',
              priceAed: 21,
              imagePath: cdn('Cheese Garlic Bread.jpg'),
            ),
            MenuItem(
              itemName: 'Mozzarella Sticks',
              description: 'Crispy mozzarella sticks.',
              priceAed: 24,
              imagePath: cdn('Mozzarella Sticks.jpg'),
            ),
            MenuItem(
              itemName: 'Hashed Brown',
              description: 'Crispy hashed brown.',
              priceAed: 13,
              imagePath: cdn('Hashed Brown.jpg'),
            ),
            MenuItem(
              itemName: 'Loaded Garlic Bread',
              description: 'Loaded garlic bread with toppings.',
              priceAed: 23,
              imagePath: cdn('Loaded Garlic Bread.jpg'),
            ),
            MenuItem(
              itemName: 'Lotus Cheesecake',
              description: 'Creamy lotus cheesecake.',
              priceAed: 21,
              imagePath: cdn('Lotus Cheesecake.jpg'),
            ),
            MenuItem(
              itemName: 'Nutella Cheesecake',
              description: 'Rich Nutella cheesecake.',
              priceAed: 21,
              imagePath: cdn('Nutella Cheesecake.jpg'),
            ),
            MenuItem(
              itemName: 'CHOCOLATE CHEESE CAKE',
              description: 'Decadent chocolate cheesecake.',
              priceAed: 21,
              imagePath: cdn('CHOCOLATE CHEESE CAKE.jpg'),
            ),
            MenuItem(
              itemName: 'New Garden Salad',
              description: 'Fresh garden salad.',
              priceAed: 26,
              imagePath: cdn('New Garden Salad.jpg'),
            ),
          ],
        ),
        MenuCategory(
          categoryName: 'BEVERAGES',
          items: [
            MenuItem(
              itemName: 'Coke',
              description: 'Refreshing Coca-Cola.',
              priceAed: 9,
              imagePath: cdn('Coke.jpg'),
            ),
            MenuItem(
              itemName: 'Lemonade',
              description: 'Fresh lemonade.',
              priceAed: 16,
              imagePath: cdn('Lemonade.jpg'),
            ),
            MenuItem(
              itemName: 'Juice Orange Fresh',
              description: 'Fresh orange juice.',
              priceAed: 15,
              imagePath: cdn('Juice Orange Fresh.jpg'),
            ),
            MenuItem(
              itemName: 'Milkshake',
              description: 'Creamy milkshake.',
              priceAed: 17,
              imagePath: cdn('Milkshake.jpg'),
            ),
          ],
        ),
        MenuCategory(
          categoryName: 'PIZZA',
          items: [
            MenuItem(
              itemName: 'Chicken Teriyaki',
              description: 'Chicken teriyaki pizza.',
              priceAed: 48,
              imagePath: cdn('Chicken Teriyaki.jpg'),
            ),
          ],
        ),
        MenuCategory(
          categoryName: 'SFC MELTS',
          items: [
            MenuItem(
              itemName: 'Pepperoni melts',
              description: 'Delicious pepperoni melts.',
              priceAed: 26,
              imagePath: cdn('Pepperoni melts.jpg'),
            ),
            MenuItem(
              itemName: 'Tandoori chicken melts',
              description: 'Spicy tandoori chicken melts.',
              priceAed: 26,
              imagePath: cdn('Tandoori chicken melts.jpg'),
            ),
            MenuItem(
              itemName: 'Bbq chicken melts',
              description: 'BBQ chicken melts.',
              priceAed: 26,
              imagePath: cdn('Bbq chicken melts.jpg'),
            ),
            MenuItem(
              itemName: 'Paneer melts',
              description: 'Creamy paneer melts.',
              priceAed: 26,
              imagePath: cdn('Paneer melts.jpg'),
            ),
          ],
        ),
      ],
    );

    return menu;
  }
}

class MenuCategory {
  final String categoryName;
  final String? section;
  final List<MenuItem> items;

  MenuCategory({required this.categoryName, this.section, required this.items});

  // Convert from JSON Map
  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];

    return MenuCategory(
      categoryName: json['category_name'] as String? ?? '',
      section: json['section'] as String?,
      items: itemsList
          .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  // Convert to JSON Map
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'category_name': categoryName,
      'items': items.map((item) => item.toJson()).toList(),
    };

    if (section != null) {
      json['section'] = section;
    }

    return json;
  }

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'categoryName': categoryName,
      'items': items.map((item) => item.toMap()).toList(),
    };

    if (section != null) {
      map['section'] = section;
    }

    return map;
  }

  // Create from Map (from Firebase)
  factory MenuCategory.fromMap(Map<dynamic, dynamic> map) {
    return MenuCategory(
      categoryName:
          map['categoryName'] as String? ??
          map['category_name'] as String? ??
          '',
      section: map['section'] as String?,
      items: (map['items'] as List<dynamic>? ?? [])
          .map((item) => MenuItem.fromMap(item as Map<dynamic, dynamic>))
          .toList(),
    );
  }

  // Copy with method
  MenuCategory copyWith({
    String? categoryName,
    String? section,
    List<MenuItem>? items,
  }) {
    return MenuCategory(
      categoryName: categoryName ?? this.categoryName,
      section: section ?? this.section,
      items: items ?? this.items,
    );
  }
}

class MenuItem {
  final String itemName;
  final String description;
  final double priceAed;
  final String? imagePath;
  final String primaryIngredient;
  final bool isVeg;

  MenuItem({
    required this.itemName,
    required this.description,
    required this.priceAed,
    this.imagePath,
    String? primaryIngredient,
    this.isVeg = true,
  }) : primaryIngredient = _derivePrimaryIngredient(
         primaryIngredient ?? description,
       );

  // Convert from JSON Map
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final rawPath = json['image_path'] as String?;
    final rawPrimary =
        json['primary_ingredient'] as String? ?? json['primaryIngredient'];
    return MenuItem(
      itemName: json['item_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priceAed: (json['price_aed'] as num?)?.toDouble() ?? 0.0,
      imagePath: rawPath,
      primaryIngredient: rawPrimary,
      isVeg: json['is_veg'] as bool? ?? json['isVeg'] as bool? ?? true,
    );
  }

  // Convert to JSON Map
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'item_name': itemName,
      'description': description,
      'price_aed': priceAed,
      'primary_ingredient': primaryIngredient,
      'is_veg': isVeg,
    };
    if (imagePath != null) {
      json['image_path'] = imagePath;
    }
    return json;
  }

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'itemName': itemName,
      'description': description,
      'priceAed': priceAed,
      'primaryIngredient': primaryIngredient,
      'isVeg': isVeg,
    };
    if (imagePath != null) {
      map['imagePath'] = imagePath;
    }
    return map;
  }

  // Create from Map (from Firebase)
  factory MenuItem.fromMap(Map<dynamic, dynamic> map) {
    final rawPath = map['imagePath'] as String? ?? map['image_path'] as String?;
    final rawPrimary =
        map['primaryIngredient'] as String? ?? map['primary_ingredient'];
    return MenuItem(
      itemName: map['itemName'] as String? ?? map['item_name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      priceAed:
          (map['priceAed'] as num?)?.toDouble() ??
          (map['price_aed'] as num?)?.toDouble() ??
          0.0,
      imagePath: rawPath,
      primaryIngredient: rawPrimary,
      isVeg: map['isVeg'] as bool? ?? map['is_veg'] as bool? ?? true,
    );
  }

  // Copy with method
  MenuItem copyWith({
    String? itemName,
    String? description,
    double? priceAed,
    String? imagePath,
    String? primaryIngredient,
    bool? isVeg,
  }) {
    return MenuItem(
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      priceAed: priceAed ?? this.priceAed,
      imagePath: imagePath ?? this.imagePath,
      primaryIngredient: primaryIngredient ?? this.primaryIngredient,
      isVeg: isVeg ?? this.isVeg,
    );
  }
}

String _derivePrimaryIngredient(String description) {
  final cleaned = description.trim();
  if (cleaned.isEmpty) return 'Chef Special';

  final words = cleaned.split(RegExp(r'[ ,+/&-]+')).where((w) => w.isNotEmpty);
  final topWords = words.take(2).join(' ');
  return topWords.isEmpty ? 'Chef Special' : topWords;
}
