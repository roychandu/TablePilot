// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';

class TakeawayScreen extends StatefulWidget {
  const TakeawayScreen({super.key});

  @override
  State<TakeawayScreen> createState() => _TakeawayScreenState();
}

class _TakeawayScreenState extends State<TakeawayScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  bool _isAdmin = false;
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  Map<String, String> _customerNames = {}; // userId -> customer name mapping
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeScreen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    // Wait for auth to be ready before checking admin status
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    // Check admin status first
    final currentUserEmail = _authService.currentUser?.email;
    final isAdmin = currentUserEmail == 'test-admin@gmail.com';

    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }

    // Load orders after admin status is set
    await _loadOrders(showLoading: true);

    // Set up periodic refresh every 30 seconds for admin view (only refresh data, don't show loading)
    if (mounted && _isAdmin) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (mounted && _isAdmin) {
          _loadOrders(showLoading: false);
        } else {
          timer.cancel();
        }
      });
    }
  }

  Future<void> _loadOrders({bool showLoading = false}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      List<OrderModel> orders;
      Map<String, String> customerNames = {};

      if (_isAdmin) {
        // Optimized: get orders and names in one go for admin
        final result = await _orderService.getAllNonAdminOrdersWithNames();
        orders = result.orders;
        customerNames = result.customerNames;
      } else {
        // For non-admin: get current user's orders
        orders = await _orderService.getOrders();
      }

      if (mounted) {
        // No need to fetch names separately anymore for admin

        setState(() {
          _orders = orders;
          _customerNames = customerNames;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Filter orders
    final pendingOrders = _orders.where((order) {
      return order.status == OrderStatus.pending ||
          order.status == OrderStatus.preparing ||
          order.status == OrderStatus.active ||
          order.status == OrderStatus.ready;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final completedOrders = _orders.where((order) {
      return order.status == OrderStatus.completed ||
          order.status == OrderStatus.served;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final rejectedOrders = _orders.where((order) {
      return order.status == OrderStatus.cancelled;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          _isAdmin ? 'All Takeaway Orders' : 'My Orders',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(
                  pendingOrders,
                  isTablet,
                  screenWidth,
                  'No active orders',
                ),
                _buildOrdersList(
                  completedOrders,
                  isTablet,
                  screenWidth,
                  'No completed orders',
                ),
                _buildOrdersList(
                  rejectedOrders,
                  isTablet,
                  screenWidth,
                  'No rejected orders',
                ),
              ],
            ),
    );
  }

  Widget _buildOrdersList(
    List<OrderModel> orders,
    bool isTablet,
    double screenWidth,
    String emptyMessage,
  ) {
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    final verticalSpacing = isTablet ? 24.0 : 16.0;

    return RefreshIndicator(
      onRefresh: () => _loadOrders(showLoading: false),
      color: AppColors.primary,
      child: orders.isEmpty
          ? _buildEmptyState(screenWidth, emptyMessage)
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalSpacing,
              ),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(bottom: isTablet ? 16 : 12),
                  child: _buildOrderCard(orders[index], isTablet),
                );
              },
            ),
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isTablet) {
    final formattedDate =
        '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year}';
    final formattedTime =
        '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

    // Get status color and text
    final statusColor = _getStatusColor(order.status);
    final statusText = _getStatusText(order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Customer Name and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCustomerName(order),
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$formattedDate at $formattedTime',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Order Items
          if (order.items.isNotEmpty) ...[
            Text(
              'Items (${order.items.length})',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}x ${item.itemName}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      'AED ${(item.priceAed * item.quantity).toStringAsFixed(0)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
          ],
          // Order Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'AED ${order.subtotal.toStringAsFixed(0)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (order.serviceCharge > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Service Charge',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'AED ${order.serviceCharge.toStringAsFixed(0)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'AED ${order.total.toStringAsFixed(0)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          // Status Update Buttons (for admin only)
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            _buildStatusButton(order),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusButton(OrderModel order) {
    // Show "Confirm" and "Reject" buttons if order is pending
    if (order.status == OrderStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateOrderStatus(order, OrderStatus.cancelled),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Reject',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateOrderStatus(order, OrderStatus.preparing),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success, // or AppColors.primary
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Confirm',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Show "Mark as Completed" button if order is preparing
    if (order.status == OrderStatus.preparing ||
        order.status == OrderStatus.active ||
        order.status == OrderStatus.ready) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _updateOrderStatus(order, OrderStatus.completed),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Mark as Completed',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Show no button if order is already completed or cancelled
    return const SizedBox.shrink();
  }

  Future<void> _updateOrderStatus(
    OrderModel order,
    OrderStatus newStatus,
  ) async {
    if (order.orderId == null || order.userId == null) {
      return;
    }

    try {
      final success = await _orderService.updateOrderStatusForUser(
        userId: order.userId!,
        orderId: order.orderId!,
        status: newStatus,
      );

      if (mounted) {
        if (success) {
          // Reload orders to reflect the updated status (without showing loading)
          await _loadOrders(showLoading: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order status updated to ${_getStatusText(newStatus)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update order status',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating order status: $e',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.active:
      case OrderStatus.preparing:
        return AppColors.info;
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.served:
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.active:
        return 'Active';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.served:
        return 'Served';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getCustomerName(OrderModel order) {
    if (_isAdmin &&
        order.userId != null &&
        _customerNames.containsKey(order.userId)) {
      return _customerNames[order.userId]!;
    }
    // Fallback to Order ID if name is not available
    return 'Order #${order.orderId?.substring(0, 8) ?? 'N/A'}';
  }

  Widget _buildEmptyState(double screenWidth, String emptyMessage) {
    final isTablet = screenWidth > 600;
    final padding = isTablet ? 60.0 : 40.0;
    final iconSize = isTablet ? 80.0 : 64.0;
    final titleFontSize = isTablet ? 22.0 : 18.0;
    final bodyFontSize = isTablet ? 17.0 : 15.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.bag,
            size: iconSize,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            emptyMessage,
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            _isAdmin
                ? 'Customer orders will appear here'
                : 'Your order history will appear here',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: bodyFontSize,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
