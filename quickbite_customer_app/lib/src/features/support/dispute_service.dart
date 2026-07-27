import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class DisputeResult {
  final String decision; // 'approve', 'partial', 'deny'
  final String reason;
  final double refundAmount;
  final String orderNumber;

  DisputeResult({
    required this.decision,
    required this.reason,
    required this.refundAmount,
    required this.orderNumber,
  });

  factory DisputeResult.fromJson(Map<String, dynamic> json) {
    return DisputeResult(
      decision: json['decision'] ?? 'deny',
      reason: json['reason'] ?? '',
      refundAmount: (json['refundAmount'] ?? 0).toDouble(),
      orderNumber: json['orderNumber'] ?? '',
    );
  }

  bool get isApproved => decision == 'approve';
  bool get isPartial => decision == 'partial';
  bool get isDenied => decision == 'deny';
}

class DisputeService {
  final Dio _dio;

  DisputeService(this._dio);

  Future<DisputeResult> submitDispute({
    required String orderId,
    required String issueType,
    required String description,
  }) async {
    final response = await _dio.post(
      '/orders/$orderId/dispute',
      data: {
        'issueType': issueType,
        'description': description,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return DisputeResult.fromJson(response.data);
    }
    throw Exception('Failed to submit dispute');
  }
}

final disputeServiceProvider = Provider<DisputeService>((ref) {
  return DisputeService(ref.watch(apiClientProvider));
});
