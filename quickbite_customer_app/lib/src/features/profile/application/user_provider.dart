import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_repository.dart';
import '../data/wallet_repository.dart';
import '../domain/user_profile.dart';

final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getProfile();
});

final walletProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getWalletBalance();
});

final walletTransactionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(walletRepositoryProvider);
  return repository.getTransactions();
});

final userAddressesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getAddresses();
});

final userOrdersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUserOrders();
});

final paymentMethodsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getPaymentMethods();
});
