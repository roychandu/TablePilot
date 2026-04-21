// ignore_for_file: deprecated_member_use, empty_catches, use_build_context_synchronously

import 'package:table_pilot/screens/profile_screen/restaurant_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../common_widgets/app_colors.dart';
import '../../services/auth_service.dart';
import '../home_tab/home_tab_screen.dart';
import '../staff_tab/staff_screen.dart';
import '../reservation_tab/reservation_screen.dart';
import '../offers_tab/customer_offers_screen.dart';
import '../takeaway_tab/my_takeaway_orders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  final AuthService _authService = AuthService();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _selectedIndex = widget.initialTabIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAdminStatus();
  }

  void _checkAdminStatus() {
    final currentUserEmail = _authService.currentUser?.email;
    final isAdmin = currentUserEmail == 'test-admin@gmail.com';
    if (mounted && _isAdmin != isAdmin) {
      setState(() {
        _isAdmin = isAdmin;
      });
    } else if (!mounted) {
      _isAdmin = isAdmin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (_isAdmin) {
      // Admin: 0=Home, 1=Staff, 2=Reservation, 3=Menu
      switch (_selectedIndex) {
        case 0:
          return const HomeTabScreen();
        case 1:
          return const StaffScreen();
        case 2:
          return const ReservationScreen();
        case 3:
          return const RestaurantMenuScreen(showBackButton: false);
        default:
          return const HomeTabScreen();
      }
    } else {
      // Non-admin: 0=Home, 1=Reservation, 2=Offers, 3=Takeaway, 4=Menu
      switch (_selectedIndex) {
        case 0:
          return const HomeTabScreen();
        case 1:
          return const ReservationScreen();
        case 2:
          return const CustomerOffersScreen();
        case 3:
          return const MyTakeawayOrdersScreen();
        case 4:
          return const RestaurantMenuScreen(showBackButton: false);
        default:
          return const HomeTabScreen();
      }
    }
  }

  void switchToTab(int index, {String? eventInitialView}) {
    final maxIndex = _isAdmin ? 3 : 4;
    if (index >= 0 && index <= maxIndex) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildBottomNavigationBar() {
    final navItems = <_NavItemData>[
      _NavItemData(
        icon: CupertinoIcons.house,
        activeIcon: CupertinoIcons.house_fill,
        label: 'Home',
      ),
    ];

    if (_isAdmin) {
      navItems.addAll([
        _NavItemData(
          icon: CupertinoIcons.person_2,
          activeIcon: CupertinoIcons.person_2_fill,
          label: 'Staff',
        ),
        _NavItemData(
          icon: 'assets/table-icon.png',
          activeIcon: 'assets/table-icon.png',
          label: 'Tables',
          isAsset: true,
        ),
        _NavItemData(
          icon: CupertinoIcons.list_bullet,
          activeIcon: CupertinoIcons.list_bullet,
          label: 'Menu',
        ),
      ]);
    } else {
      navItems.addAll([
        _NavItemData(
          icon: 'assets/table-icon.png',
          activeIcon: 'assets/table-icon.png',
          label: 'Reservation',
          isAsset: true,
        ),
        _NavItemData(
          icon: CupertinoIcons.tag,
          activeIcon: CupertinoIcons.tag_fill,
          label: 'Offers',
        ),
        _NavItemData(
          icon: CupertinoIcons.bag,
          activeIcon: CupertinoIcons.bag_fill,
          label: 'Takeaway',
        ),
        _NavItemData(
          icon: CupertinoIcons.list_bullet,
          activeIcon: CupertinoIcons.list_bullet,
          label: 'Menu',
        ),
      ]);
    }

    return Container(
      height: 75 + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom,
        left: 8,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final isSelected = _selectedIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.symmetric(
                  vertical: isSelected ? 8 : 12,
                  horizontal: 4,
                ),
                decoration: const BoxDecoration(color: AppColors.transparent),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    data.isAsset
                        ? Image.asset(
                            data.icon as String,
                            width: isSelected ? 26 : 22,
                            height: isSelected ? 26 : 22,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.warmGray,
                          )
                        : Icon(
                            isSelected
                                ? data.activeIcon as IconData
                                : data.icon as IconData,
                            size: isSelected ? 26 : 22,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.warmGray,
                            shadows: isSelected
                                ? [
                                    Shadow(
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                      color: AppColors.primary.withOpacity(0.3),
                                    ),
                                  ]
                                : null,
                          ),
                    if (isSelected) const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        data.label,
                        style: TextStyle(
                          fontSize: isSelected ? 12 : 10,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.warmGray,
                          shadows: isSelected
                              ? [
                                  // Stronger 3D Text Effect
                                  Shadow(
                                    offset: const Offset(1, 1),
                                    color: AppColors.black.withOpacity(0.3),
                                    blurRadius: 1,
                                  ),
                                  Shadow(
                                    offset: const Offset(0, 2),
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavItemData {
  final dynamic icon;
  final dynamic activeIcon;
  final String label;
  final bool isAsset;

  _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isAsset = false,
  });
}
