import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../domain/order.dart';

class OrderRepository {
  final Dio _dio;

  OrderRepository(this._dio);

  Future<List<Order>> getMerchantOrders(String merchantId) async {
    try {
      final response = await _dio.get('/orders/merchant/$merchantId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Order.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load merchant orders');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await _dio.put(
        '/orders/$orderId/status',
        data: {'status': status},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update order status');
      }
    } catch (e) {
      throw Exception('Failed to update order status');
    }
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiClientProvider));
});
