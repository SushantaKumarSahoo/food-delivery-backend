import 'dart:io' show Platform;

class ApiConfig {
  /// Base URL of the API Gateway
  /// When running on Android emulator, localhost refers to the emulator itself.
  /// We must use 10.0.2.2 to reach the host machine.
  static String get baseUrl {
    // Note: If running on Web, Platform check throws error. 
    // For simplicity, checking android platform here. 
    // In production, this would be an environment variable.
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000/api';
      }
      return 'http://localhost:3000/api';
    } catch (e) {
      // Fallback for Web
      return 'http://localhost:3000/api';
    }
  }

  /// WebSocket base for delivery real-time tracking (port 3008)
  static String get deliveryWsUrl {
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3008';
      return 'http://localhost:3008';
    } catch (e) {
      return 'http://localhost:3008';
    }
  }

  // Common Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/users/profile';
  
  // Restaurant / Merchant Endpoints
  static const String merchants = '/merchants';
  static const String catalog = '/catalog';
  
  // Cart
  static const String cart = '/cart';
  
  // Users
  static const String users = '/users';
  
  // Search
  static const String search = '/search';

  // Orders
  static const String orders = '/orders';
  
  // Wallet
  static const String wallet = '/wallet';

  // Offers / Promos
  static const String offers = '/offers';

  // Reviews
  static const String reviews = '/reviews';
}
