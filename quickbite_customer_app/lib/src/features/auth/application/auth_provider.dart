import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../core/api/api_client.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.status = AuthStatus.initial,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _authRepository;

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    // Since build is synchronous and we can't do async easily without AsyncNotifier,
    // we return initial state and trigger check in the background.
    Future.microtask(() => checkAuthStatus());
    return AuthState();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'jwt_token');

    if (token != null && token.isNotEmpty) {
      state = state.copyWith(status: AuthStatus.authenticated, isLoading: false);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated, isLoading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final token = await _authRepository.login(email, password);
      
      if (token != null) {
        final storage = ref.read(secureStorageProvider);
        await storage.write(key: 'jwt_token', value: token);

        // FCM token registration will be added when Firebase is integrated

        state = state.copyWith(status: AuthStatus.authenticated, isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: 'Invalid credentials',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepository.sendOtp(phone);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<VerifyOtpResult> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _authRepository.verifyOtp(phone, otp);
      
      if (result.accessToken != null) {
        final storage = ref.read(secureStorageProvider);
        await storage.write(key: 'jwt_token', value: result.accessToken);

        // FCM token registration will be added when Firebase is integrated

        state = state.copyWith(status: AuthStatus.authenticated, isLoading: false);
        return result;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: 'Invalid OTP',
        );
        return VerifyOtpResult(accessToken: null, isNewUser: false);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return VerifyOtpResult(accessToken: null, isNewUser: false);
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'jwt_token');
    state = state.copyWith(status: AuthStatus.unauthenticated, isLoading: false);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});
