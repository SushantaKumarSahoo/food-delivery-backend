import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class OffersRepository {
  final Dio _dio;
  OffersRepository(this._dio);

  Future<List<Map<String, dynamic>>> getActiveOffers() async {
    try {
      final response = await _dio.get('/offers');
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(
          (response.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> validateCoupon(String code, double orderAmount) async {
    final response = await _dio.post('/offers/validate', data: {
      'code': code,
      'orderAmount': orderAmount,
    });
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> redeemGiftCard(String code) async {
    final response = await _dio.post('/offers/redeem-gift-card', data: {'code': code});
    return Map<String, dynamic>.from(response.data);
  }
}

final offersRepositoryProvider = Provider<OffersRepository>((ref) {
  return OffersRepository(ref.watch(apiClientProvider));
});

final activeOffersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(offersRepositoryProvider).getActiveOffers();
});
