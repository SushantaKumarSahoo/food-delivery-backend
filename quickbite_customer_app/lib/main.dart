import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/core/api/api_client.dart';
import 'src/core/notifications/fcm_service.dart';
import 'src/core/theme/app_theme.dart';
import 'src/routing/app_router.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init — requires google-services.json (Android) / GoogleService-Info.plist (iOS)
  // If firebase is not yet configured, this is wrapped in a try/catch so the app still runs.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase not configured yet: $e');
  }

  runApp(const ProviderScope(child: QuickBiteApp()));
}

class QuickBiteApp extends ConsumerStatefulWidget {
  const QuickBiteApp({super.key});

  @override
  ConsumerState<QuickBiteApp> createState() => _QuickBiteAppState();
}

class _QuickBiteAppState extends ConsumerState<QuickBiteApp> {
  @override
  void initState() {
    super.initState();
    // Initialize FCM after first frame — needs Dio from provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final dio = ref.read(apiClientProvider);
        await FcmService.instance.initialize(dio);
      } catch (e) {
        debugPrint('FCM init skipped: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'QuickBite',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
