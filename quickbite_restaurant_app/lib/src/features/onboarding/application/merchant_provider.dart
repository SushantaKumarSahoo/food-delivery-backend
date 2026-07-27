import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/merchant_repository.dart';

class OnboardingState {
  final bool isLoading;
  final String? error;
  
  OnboardingState({this.isLoading = false, this.error});
}

class MerchantNotifier extends Notifier<OnboardingState> {
  late final MerchantRepository _repository;

  @override
  OnboardingState build() {
    _repository = ref.watch(merchantRepositoryProvider);
    return OnboardingState();
  }

  Future<bool> submitOnboarding({
    required String brandName,
    required String contactEmail,
    required String contactPhone,
    required String businessType,
    required String description,
  }) async {
    state = OnboardingState(isLoading: true);
    try {
      await _repository.onboardMerchant(
        brandName: brandName,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        businessType: businessType,
        description: description,
      );
      state = OnboardingState(isLoading: false);
      return true;
    } catch (e) {
      state = OnboardingState(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final merchantProvider = NotifierProvider<MerchantNotifier, OnboardingState>(() {
  return MerchantNotifier();
});

final merchantStatusProvider = FutureProvider.autoDispose<bool>((ref) async {
  return ref.watch(merchantRepositoryProvider).hasCompletedOnboarding();
});
