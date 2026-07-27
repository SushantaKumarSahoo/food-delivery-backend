import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../domain/product.dart';

class MenuRepository {
  final Dio _dio;

  MenuRepository(this._dio);

  Future<List<Product>> getProductsByStore(String storeId) async {
    try {
      final response = await _dio.get('/catalog/stores/$storeId/products');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Product.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load menu items');
    }
  }

  Future<void> toggleAvailability(String productId, bool isAvailable) async {
    try {
      final response = await _dio.put(
        '/catalog/products/$productId/availability',
        data: {'isAvailable': isAvailable},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update availability');
      }
    } catch (e) {
      throw Exception('Failed to update availability');
    }
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(apiClientProvider));
});
