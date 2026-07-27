import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final bannersProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    // /cms/banners returns an array of banners
    final response = await api.get('${ApiConfig.cms}/banners');
    if (response.statusCode == 200) {
      if (response.data is List) {
        return response.data as List<dynamic>;
      }
      if (response.data != null && response.data['data'] is List) {
        return response.data['data'] as List<dynamic>;
      }
    }
    return [];
  } catch (e) {
    print('Error fetching banners: $e');
    return [];
  }
});
