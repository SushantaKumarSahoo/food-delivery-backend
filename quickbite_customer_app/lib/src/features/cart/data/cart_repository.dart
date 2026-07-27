import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../domain/cart.dart';

class CartRepository {
  final Dio _dio;

  CartRepository(this._dio);

  Future<Cart> getCart() async {
    try {
      final response = await _dio.get(ApiConfig.cart);
      
      if (response.statusCode == 200) {
        return Cart.fromJson(response.data);
      }
      throw Exception('Cart not found');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Return empty cart if not found
        return Cart(id: '', items: [], itemTotal: 0, deliveryFee: 0, taxes: 0, total: 0);
      }
      throw Exception(e.response?.data['message'] ?? 'Failed to load cart');
    }
  }

  Future<Cart> addToCart(String productId, int quantity) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.cart}/items',
        data: {
          'productId': productId,
          'quantity': quantity,
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Cart.fromJson(response.data);
      }
      throw Exception('Failed to add to cart');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to add item to cart');
    }
  }

  Future<String> checkout(String paymentMethodId) async {
    try {
      final response = await _dio.post(
        ApiConfig.orders,
        data: {
          'paymentMethodId': paymentMethodId,
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['id']?.toString() ?? '';
      }
      throw Exception('Checkout failed');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to complete checkout');
    }
  }
}

// Provider for CartRepository
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});
