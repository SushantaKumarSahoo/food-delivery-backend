import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../onboarding/data/merchant_repository.dart';
import '../data/menu_repository.dart';
import '../domain/product.dart';

final currentStoreIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  return ref.watch(merchantRepositoryProvider).getMyStoreId();
});

class MenuNotifier extends AsyncNotifier<List<Product>> {
  late final MenuRepository _repository;
  String? _storeId;

  @override
  Future<List<Product>> build() async {
    _repository = ref.watch(menuRepositoryProvider);
    _storeId = await ref.watch(currentStoreIdProvider.future);
    
    if (_storeId == null) return [];
    
    return _repository.getProductsByStore(_storeId!);
  }

  Future<void> refreshMenu() async {
    if (_storeId == null) return;
    state = const AsyncValue.loading();
    try {
      final products = await _repository.getProductsByStore(_storeId!);
      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> toggleAvailability(String productId, bool currentStatus) async {
    try {
      await _repository.toggleAvailability(productId, !currentStatus);
      await refreshMenu();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final menuProvider = AsyncNotifierProvider<MenuNotifier, List<Product>>(() {
  return MenuNotifier();
});
