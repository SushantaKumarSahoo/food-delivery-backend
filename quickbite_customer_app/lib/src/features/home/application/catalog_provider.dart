import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/catalog_repository.dart';
import '../domain/vertical.dart';

final verticalsProvider = FutureProvider.autoDispose<List<Vertical>>((ref) async {
  final repository = ref.watch(catalogRepositoryProvider);
  return repository.getVerticals();
});
