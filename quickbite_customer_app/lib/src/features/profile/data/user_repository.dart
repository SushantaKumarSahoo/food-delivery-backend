import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../domain/user_profile.dart';

class UserRepository {
  final Dio _dio;

  UserRepository(this._dio);

  Future<UserProfile> getProfile() async {
    try {
      final response = await _dio.get('${ApiConfig.users}/me');
      
      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      }
      throw Exception('Profile not found');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to load profile');
    }
  }

  Future<int> getWalletBalance() async {
    try {
      final response = await _dio.get('${ApiConfig.users}/wallet');
      if (response.statusCode == 200 && response.data != null) {
        final coins = response.data['coins'];
        if (coins is num) return coins.toInt();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> redeemWalletCoins(int coinsToRedeem) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.users}/wallet/redeem',
        data: {'coins': coinsToRedeem},
      );
      if (response.statusCode == 200 && response.data != null) {
        final coins = response.data['coins'];
        if (coins is num) return coins.toInt();
      }
    } catch (_) {}
    return 0;
  }

  Future<int> addWalletCoins(int coinsToAdd) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.users}/wallet/add',
        data: {'coins': coinsToAdd},
      );
      if (response.statusCode == 200 && response.data != null) {
        final coins = response.data['coins'];
        if (coins is num) return coins.toInt();
      }
    } catch (_) {}
    return 0;
  }

  Future<void> updateProfile({required String fullName, required String email}) async {
    try {
      await _dio.put(
        '${ApiConfig.users}/profile',
        data: {'fullName': fullName, 'email': email},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to update profile');
    }
  }

  Future<List<dynamic>> getAddresses() async {
    try {
      final response = await _dio.get('${ApiConfig.users}/addresses');
      if (response.statusCode == 200 && response.data is List) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> addAddress(Map<String, dynamic> data) async {
    try {
      await _dio.post('${ApiConfig.users}/addresses', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to add address');
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      await _dio.delete('${ApiConfig.users}/addresses/$addressId');
    } catch (e) {
      // Ignore failure
    }
  }

  Future<List<dynamic>> getUserOrders() async {
    try {
      final response = await _dio.get(ApiConfig.orders);
      if (response.statusCode == 200 && response.data is List) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getPaymentMethods() async {
    try {
      final response = await _dio.get('${ApiConfig.users}/payment-methods');
      if (response.statusCode == 200 && response.data is List) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> addPaymentMethod(Map<String, dynamic> data) async {
    try {
      await _dio.post('${ApiConfig.users}/payment-methods', data: data);
    } catch (e) {
      // Allow local fallback
    }
  }

  Future<void> updateDeviceToken(String token) async {
    try {
      await _dio.put(
        '${ApiConfig.users}/device-token',
        data: {'fcmToken': token},
      );
    } catch (e) {
      // Ignore token update failures
    }
  }
}

// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiClientProvider));
});
