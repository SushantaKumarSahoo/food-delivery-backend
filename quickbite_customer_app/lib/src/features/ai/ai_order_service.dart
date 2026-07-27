import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class AiOrderItem {
  final String productId;
  final String productName;
  final int quantity;

  AiOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  factory AiOrderItem.fromJson(Map<String, dynamic> json) {
    return AiOrderItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? 'Item',
      quantity: json['quantity'] ?? 1,
    );
  }
}

class AiOrderService {
  final Dio _dio;

  AiOrderService(this._dio);

  Future<List<AiOrderItem>> parseOrder(String prompt, String storeId) async {
    final response = await _dio.post(
      '/catalog/ai-order',
      data: {'prompt': prompt, 'storeId': storeId},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> data = response.data;
      return data.map((json) => AiOrderItem.fromJson(json)).toList();
    }
    throw Exception('Failed to parse order');
  }
}

final aiOrderServiceProvider = Provider<AiOrderService>((ref) {
  return AiOrderService(ref.watch(apiClientProvider));
});
