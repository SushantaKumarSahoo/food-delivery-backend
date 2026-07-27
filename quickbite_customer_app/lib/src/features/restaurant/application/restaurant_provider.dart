import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/restaurant_repository.dart';
import '../domain/menu_item.dart';
import '../domain/restaurant.dart';

// Provider that fetches and caches the list of restaurants
final restaurantsProvider = FutureProvider.autoDispose<List<Restaurant>>((ref) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getRestaurants();
});

// Family provider to fetch a specific restaurant by its ID
final restaurantDetailsProvider = FutureProvider.family.autoDispose<Restaurant, String>((ref, id) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getRestaurantDetails(id);
});

// Family provider to fetch menu items for a specific store/restaurant ID
final menuProvider = FutureProvider.family.autoDispose<List<MenuItem>, String>((ref, id) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  return repository.getMenuItems(id);
});
