import '../models/order_model.dart';

class OrdersWithNames {
  final List<OrderModel> orders;
  final Map<String, String> customerNames;

  OrdersWithNames(this.orders, this.customerNames);
}
