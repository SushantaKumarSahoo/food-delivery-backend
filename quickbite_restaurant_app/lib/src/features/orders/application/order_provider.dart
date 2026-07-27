import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../onboarding/data/merchant_repository.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';

final currentMerchantIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  return ref.watch(merchantRepositoryProvider).getMyMerchantId();
});

class OrderNotifier extends AsyncNotifier<List<Order>> {
  late final OrderRepository _repository;
  String? _merchantId;

  @override
  Future<List<Order>> build() async {
    _repository = ref.watch(orderRepositoryProvider);
    _merchantId = await ref.watch(currentMerchantIdProvider.future);
    
    if (_merchantId == null) return [];
    
    return _repository.getMerchantOrders(_merchantId!);
  }

  Future<void> refreshOrders() async {
    if (_merchantId == null) return;
    state = const AsyncValue.loading();
    try {
      final orders = await _repository.getMerchantOrders(_merchantId!);
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateStatus(String orderId, String status) async {
    try {
      await _repository.updateOrderStatus(orderId, status);
      await refreshOrders();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final orderProvider = AsyncNotifierProvider<OrderNotifier, List<Order>>(() {
  return OrderNotifier();
});
