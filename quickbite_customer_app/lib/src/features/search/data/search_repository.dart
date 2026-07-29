import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../restaurant/domain/restaurant.dart';

class SearchRepository {
  final Dio _dio;

  SearchRepository(this._dio);

  Future<List<Restaurant>> searchRestaurants(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await _dio.get(
        '${ApiConfig.search}/restaurants',
        queryParameters: {'q': query},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Restaurant.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Search failed');
    }
  }

  Future<Map<String, dynamic>> aiSearch(String query) async {
    if (query.isEmpty) return {'intent': null, 'results': []};
    
    try {
      final response = await _dio.post(
        '${ApiConfig.search}/ai',
        data: {'q': query},
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return {'intent': null, 'results': []};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'AI Search failed');
    }
  }

  Future<List<Map<String, dynamic>>> getTrendingCuisines() async {
    // Return a curated list of actual food cuisines rather than top-level verticals like Pharmacy/Grocery
    return [
      {'name': 'Fast Food', 'icon': '🍔', 'id': ''},
      {'name': 'Italian', 'icon': '🍕', 'id': ''},
      {'name': 'Asian', 'icon': '🍜', 'id': ''},
      {'name': 'Desserts', 'icon': '🍩', 'id': ''},
      {'name': 'Healthy', 'icon': '🥗', 'id': ''},
      {'name': 'Mexican', 'icon': '🌮', 'id': ''},
    ];
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider));
});
