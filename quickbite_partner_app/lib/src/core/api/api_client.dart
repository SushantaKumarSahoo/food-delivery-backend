import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_config.dart';

// Use an in-memory storage to prevent Android Keystore crashes on some emulators
class MockSecureStorage {
  final _storage = <String, String>{};
  
  Future<String?> read({required String key}) async => _storage[key];
  Future<void> write({required String key, required String value}) async => _storage[key] = value;
  Future<void> delete({required String key}) async => _storage.remove(key);
}

final secureStorageProvider = Provider<MockSecureStorage>((ref) {
  return MockSecureStorage();
});

final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // Fetch token from secure storage and append to header
      final token = await storage.read(key: 'jwt_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options); // continue
    },
    onError: (DioException e, handler) {
      // Global error handling could go here (e.g. logging out on 401)
      return handler.next(e);
    },
  ));

  return dio;
});
