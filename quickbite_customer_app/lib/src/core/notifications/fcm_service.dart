import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'quickbite_orders',
    'QuickBite Orders',
    description: 'Order status and delivery updates',
    importance: Importance.high,
  );

  Future<void> initialize(Dio dio) async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set up local notifications for foreground display
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });

    // Register FCM token with backend
    await _registerToken(dio);

    // Refresh token listener
    _messaging.onTokenRefresh.listen((token) => _sendTokenToBackend(dio, token));
  }

  Future<void> _registerToken(Dio dio) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(dio, token);
      }
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> _sendTokenToBackend(Dio dio, String token) async {
    try {
      const storage = FlutterSecureStorage();
      final jwt = await storage.read(key: 'jwt_token');
      if (jwt == null) return;

      await dio.put(
        '/users/device-token',
        data: {'fcmToken': token},
        options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      );
      debugPrint('FCM token registered with backend');
    } catch (e) {
      debugPrint('FCM backend registration failed: $e');
    }
  }

  /// Call after logout to remove the token from backend
  Future<void> unregister(Dio dio) async {
    try {
      await _messaging.deleteToken();
      await dio.delete('/users/device-token');
    } catch (_) {}
  }
}
