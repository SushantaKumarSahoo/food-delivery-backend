import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wallet_repository.dart';

final walletBalanceProvider = FutureProvider.autoDispose<double>((ref) async {
  final repository = ref.watch(walletRepositoryProvider);
  return repository.getBalance();
});
