import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

class WalletRepository {
  final Dio _dio;

  WalletRepository(this._dio);

  Future<double> getBalance() async {
    try {
      final response = await _dio.get('${ApiConfig.wallet}/balance');
      if (response.statusCode == 200) {
        return (response.data['balance'] ?? 0.0).toDouble();
      }
      return 0.0;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return 0.0;
      throw Exception(e.response?.data['message'] ?? 'Failed to load wallet balance');
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final response = await _dio.get('${ApiConfig.wallet}/transactions');
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(
            (response.data as List).map((e) => Map<String, dynamic>.from(e)));
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider));
});
