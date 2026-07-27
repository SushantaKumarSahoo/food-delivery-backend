import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<String?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      // The backend should return the token (e.g., access_token)
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['access_token'] as String?;
      }
      return null;
    } on DioException catch (e) {
      // Throw a custom error or handle it as needed
      throw Exception(e.response?.data['message'] ?? 'Login failed');
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
        },
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Registration failed');
    }
  }

  Future<void> sendOtp(String phone) async {
    try {
      final response = await _dio.post(
        '/auth/send-otp',
        data: {'phone': phone},
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to send OTP');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to send OTP');
    }
  }

  Future<VerifyOtpResult> verifyOtp(String phone, String otp) async {
    try {
      final response = await _dio.post(
        '/auth/verify-otp',
        data: {'phone': phone, 'otp': otp},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = response.data['access_token'] as String?;
        final isNewUser = response.data['isNewUser'] == true;
        return VerifyOtpResult(accessToken: token, isNewUser: isNewUser);
      }
      return VerifyOtpResult(accessToken: null, isNewUser: false);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to verify OTP');
    }
  }
}

class VerifyOtpResult {
  final String? accessToken;
  final bool isNewUser;

  VerifyOtpResult({this.accessToken, this.isNewUser = false});
}

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
