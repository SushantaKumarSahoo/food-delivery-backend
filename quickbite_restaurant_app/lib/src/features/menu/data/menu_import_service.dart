import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../domain/product.dart';

class MenuImportService {
  final Dio _dio;

  MenuImportService(this._dio);

  Future<List<Product>> parseMenuFromImage(String base64Image) async {
    try {
      final response = await _dio.post(
        '/catalog/ai-import',
        data: {'imageBase64': base64Image},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data;
        return data.map((json) => Product.fromJson(json)).toList();
      }
      throw Exception('Failed to parse menu');
    } catch (e) {
      throw Exception('Failed to parse menu: $e');
    }
  }

  Future<void> batchSaveMenu(String storeId, List<Product> products) async {
    try {
      final items = products.map((p) => {
        'name': p.name,
        'description': p.description,
        'price': p.price,
        'categoryId': p.categoryId,
        'imageUrl': p.imageUrl,
      }).toList();

      final response = await _dio.post(
        '/catalog/stores/$storeId/products/batch',
        data: {'items': items},
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save menu batch');
      }
    } catch (e) {
      throw Exception('Failed to save menu batch: $e');
    }
  }
}

final menuImportServiceProvider = Provider<MenuImportService>((ref) {
  return MenuImportService(ref.watch(apiClientProvider));
});
