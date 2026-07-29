import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../restaurant/application/restaurant_provider.dart';
import '../../restaurant/domain/restaurant.dart';

final categoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    // 1. Fetch verticals
    final verticalRes = await api.get('${ApiConfig.catalog}/verticals');
    if (verticalRes.statusCode == 200) {
      List<dynamic> verticals = [];
      if (verticalRes.data is List) {
        verticals = verticalRes.data;
      } else if (verticalRes.data != null && verticalRes.data['data'] is List) {
        verticals = verticalRes.data['data'];
      }
      
      if (verticals.isNotEmpty) {
        // Take the first vertical (typically restaurant/food)
        final verticalId = verticals.first['id'];
        
        // 2. Fetch categories for this vertical
        final catRes = await api.get('${ApiConfig.catalog}/verticals/$verticalId/categories');
        if (catRes.statusCode == 200) {
          if (catRes.data is List) {
            return catRes.data as List<dynamic>;
          }
          if (catRes.data != null && catRes.data['data'] is List) {
            return catRes.data['data'] as List<dynamic>;
          }
        }
      }
    }
    return [];
  } catch (e) {
    print('Error fetching categories: $e');
    return [];
  }
});

/// Provider that filters restaurants by category name (matched against tags).
/// Takes the category name as a parameter.
final restaurantsByCategoryProvider =
    FutureProvider.family.autoDispose<List<Restaurant>, String>((ref, categoryName) async {
  final allRestaurants = await ref.watch(restaurantsProvider.future);
  final lowerName = categoryName.toLowerCase();

  return allRestaurants.where((restaurant) {
    // Match against tags (e.g., ['Burgers', 'Fast Food'])
    final tagMatch = restaurant.tags.any(
      (tag) => tag.toLowerCase().contains(lowerName),
    );
    // Also match against restaurant name or type
    final nameMatch = restaurant.name.toLowerCase().contains(lowerName);
    final typeMatch = restaurant.type.toLowerCase().contains(lowerName);
    return tagMatch || nameMatch || typeMatch;
  }).toList();
});
