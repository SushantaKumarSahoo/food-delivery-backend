import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class MerchantRepository {
  final Dio _dio;

  MerchantRepository(this._dio);

  Future<void> onboardMerchant({
    required String brandName,
    required String contactEmail,
    required String contactPhone,
    required String businessType,
    required String description,
  }) async {
    try {
      final response = await _dio.post(
        '/merchants/onboard',
        data: {
          'brandName': brandName,
          'contactEmail': contactEmail,
          'contactPhone': contactPhone,
          'businessType': businessType,
          'description': description,
        },
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to onboard merchant');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to onboard');
    }
  }

  Future<bool> hasCompletedOnboarding() async {
    try {
      final response = await _dio.get('/merchants/me');
      if (response.statusCode == 200 && response.data != null && response.data['id'] != null) {
        return true; 
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getMyMerchantId() async {
    try {
      final response = await _dio.get('/merchants/me');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['id'] as String?; 
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getMyStoreId() async {
    try {
      final response = await _dio.get('/merchants/me');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic>? stores = response.data['stores'];
        if (stores != null && stores.isNotEmpty) {
          return stores[0]['id'] as String?;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

final merchantRepositoryProvider = Provider<MerchantRepository>((ref) {
  return MerchantRepository(ref.watch(apiClientProvider));
});
