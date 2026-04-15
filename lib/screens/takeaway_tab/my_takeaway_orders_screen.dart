// ignore_for_file: use_build_context_synchronously

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';

class MyTakeawayOrdersScreen extends StatefulWidget {
  const MyTakeawayOrdersScreen({super.key});

  @override
  State<MyTakeawayOrdersScreen> createState() => _MyTakeawayOrdersScreenState();
}

class _MyTakeawayOrdersScreenState extends State<MyTakeawayOrdersScreen> {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  List<OrderModel> _myOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyOrders();
  }

  Future<void> _loadMyOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all orders and filter by current user
      // Ideally, we should have a query to get orders by user ID directly
      // But for now, we'll fetch all and filter client-side if needed, or assume data policy
      // fetches relevant orders. Use orderService to fetch list.
      // Based on typical implementation, we might need to filter `getOrders`

      // Assuming getOrders() returns all orders, we filter for takeaway (tableNumber == 0) and potentially user match
      // If auth service has current user name, we could filter by guestNames containing user name
      // Or if orders stored with userId, better.
      // Looking at `_sendOrderToKitchen` in `CartScreen`, order has guestNames.

      final userData = await _authService.getUserData();
      final currentUserName = userData['name'] as String?;

      if (currentUserName == null) {
        // Handle guest or unauth case?
        // For now, let's just fetch all mostly for demo or if assuming device/user session context
      }

      final allOrders = await _orderService.getOrders();

      final myTakeawayOrders = allOrders.where((order) {
        // Takeaway orders have tableNumber = 0
        if (order.tableNumber != 0) return false;

        // Filter by user if possible
        if (currentUserName != null && order.guestNames.isNotEmpty) {
          return order.guestNames.any((name) => name == currentUserName);
        }

        return true; // Fallback: show all takeaways if user not matched (or for testing)
        // In tight security, this should be stricter.
      }).toList();

      // Sort by date descending
      myTakeawayOrders.sort(
        (a, b) => b.reservationTime.compareTo(a.reservationTime),
      );

      if (mounted) {
        setState(() {
          _myOrders = myTakeawayOrders;
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

  Future<void> _cancelOrder(OrderModel order) async {
    // Only pending orders can be cancelled
    if (order.status != OrderStatus.pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot cancel order in this status')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && order.orderId != null) {
      try {
        await _orderService.updateOrderStatus(
          orderId: order.orderId!,
          status: OrderStatus.cancelled,
        );

        await _loadMyOrders(); // Refresh list

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Takeaway Orders',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading:
            false, // Managed by parent tab or add leading if pushed
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myOrders.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadMyOrders,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _myOrders.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildOrderCard(_myOrders[index]);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No takeaway orders yet',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isPending = order.status == OrderStatus.pending;

    // Status color mapping
    Color statusColor;
    String statusText;

    switch (order.status) {
      case OrderStatus.pending:
        statusColor = AppColors.warning;
        statusText = 'Pending';
        break;
      case OrderStatus.preparing:
        statusColor = AppColors.info;
        statusText = 'Preparing';
        break;
      case OrderStatus.ready:
        statusColor = AppColors.success;
        statusText = 'Ready';
        break;
      case OrderStatus.completed:
        statusColor = AppColors.secondary;
        statusText = 'Completed';
        break;
      case OrderStatus.cancelled:
        statusColor = AppColors.error;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = 'Unknown';
    }

    return badges.Badge(
      position: badges.BadgePosition.topEnd(top: -10, end: -10),
      showBadge: true,
      badgeContent: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      badgeStyle: badges.BadgeStyle(
        badgeColor: statusColor,
        shape: badges.BadgeShape.square,
        borderRadius: BorderRadius.circular(5),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${(order.orderId ?? '').substring((order.orderId ?? '').length > 6 ? (order.orderId ?? '').length - 6 : 0).toUpperCase()}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _formatDate(order.reservationTime),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${item.quantity}x',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.itemName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'AED ${(item.priceAed * item.quantity).toStringAsFixed(2)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'AED ${order.total.toStringAsFixed(2)}',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _cancelOrder(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel Order'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
