import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/cart_repository.dart';
import '../domain/cart.dart';

class CartNotifier extends AsyncNotifier<Cart> {
  late CartRepository _repository;

  @override
  FutureOr<Cart> build() async {
    _repository = ref.watch(cartRepositoryProvider);
    return _repository.getCart();
  }

  Future<void> addItem(String productId, int quantity) async {
    state = const AsyncValue.loading();
    try {
      final newCart = await _repository.addToCart(productId, quantity);
      state = AsyncValue.data(newCart);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      debugPrint('Error adding item: $e');
    }
  }

  Future<String?> checkout(String paymentMethodId) async {
    try {
      final orderId = await _repository.checkout(paymentMethodId);
      // Clear the cart on successful checkout
      state = AsyncValue.data(Cart(id: '', items: [], itemTotal: 0, deliveryFee: 0, taxes: 0, total: 0));
      return orderId;
    } catch (e) {
      debugPrint('Error during checkout: $e');
      return null;
    }
  }
}

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart>(() {
  return CartNotifier();
});
