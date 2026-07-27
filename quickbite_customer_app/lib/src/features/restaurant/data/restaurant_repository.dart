import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../domain/menu_item.dart';
import '../domain/restaurant.dart';

class RestaurantRepository {
  final Dio _dio;

  RestaurantRepository(this._dio);

  Future<List<Restaurant>> getRestaurants() async {
    try {
      final response = await _dio.get(ApiConfig.merchants);
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((json) => Restaurant.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      // Return empty list instead of throwing — UI will show friendly empty state
      return [];
    }
  }

  Future<Restaurant> getRestaurantDetails(String id) async {
    try {
      final response = await _dio.get('${ApiConfig.merchants}/$id');
      
      if (response.statusCode == 200) {
        return Restaurant.fromJson(response.data);
      }
      throw Exception('Restaurant not found');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to load restaurant details');
    }
  }

  Future<List<MenuItem>> getMenuItems(String storeId) async {
    try {
      final response = await _dio.get('${ApiConfig.catalog}/stores/$storeId/products');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => MenuItem.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to load menu items');
    }
  }
}

// Provider for RestaurantRepository
final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepository(ref.watch(apiClientProvider));
});
