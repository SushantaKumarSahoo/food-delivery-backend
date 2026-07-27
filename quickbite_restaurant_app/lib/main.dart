import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/features/auth/application/auth_provider.dart';
import 'src/features/auth/presentation/login_screen.dart';
import 'src/features/auth/presentation/otp_screen.dart';
import 'src/features/onboarding/presentation/onboarding_screen.dart';
import 'src/features/dashboard/presentation/dashboard_screen.dart';
import 'src/features/splash/presentation/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: QuickBiteRestaurantApp()));
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.uri.path == '/login' || state.uri.path.startsWith('/otp');
      final isSplashRoute = state.uri.path == '/splash';

      if (!isSplashRoute) {
        if (!isLoggedIn && !isAuthRoute) {
          return '/login';
        }
        if (isLoggedIn && isAuthRoute) {
          return '/';
        }
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? (state.extra as String? ?? '');
          return OtpScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/onboard',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});

class QuickBiteRestaurantApp extends ConsumerWidget {
  const QuickBiteRestaurantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'QuickBite Restaurant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316), // Orange for restaurant
          primary: const Color(0xFFF97316),
          secondary: const Color(0xFF14B8A6), // Teal
          surface: Colors.white,
          background: const Color(0xFFF8FAFC),
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      routerConfig: router,
    );
  }
}
