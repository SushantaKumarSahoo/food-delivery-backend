import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class PaymentRepository {
  final Dio _dio;
  PaymentRepository(this._dio);

  /// Creates a Cashfree order on the backend and returns session data.
  Future<Map<String, dynamic>> initiatePayment(String orderId, String methodType) async {
    try {
      final response = await _dio.post(
        '/payments/$orderId/initiate',
        data: {'methodType': methodType},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception('Failed to initiate payment');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Payment initiation failed');
    }
  }

  /// Verifies payment status from Cashfree after SDK callback.
  Future<Map<String, dynamic>> verifyPayment(String cfOrderId) async {
    try {
      final response = await _dio.get('/payments/verify/$cfOrderId');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception('Verification failed');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Payment verification failed');
    }
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});
