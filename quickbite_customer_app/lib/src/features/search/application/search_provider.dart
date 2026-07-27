import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/search_repository.dart';
import '../../restaurant/domain/restaurant.dart';

// ─── Search Query ─────────────────────────────────────────────────────────────

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String newQuery) => state = newQuery;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() {
  return SearchQueryNotifier();
});

// ─── Smart Search Toggle ──────────────────────────────────────────────────────

class IsSmartSearchNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle(bool val) => state = val;
}

final isSmartSearchProvider = NotifierProvider<IsSmartSearchNotifier, bool>(() {
  return IsSmartSearchNotifier();
});

// ─── Recent Searches (in-memory, persisted per session) ──────────────────────

class RecentSearchesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void add(String query) {
    if (query.trim().isEmpty) return;
    final updated = [query, ...state.where((s) => s != query)].take(8).toList();
    state = updated;
  }

  void remove(String query) {
    state = state.where((s) => s != query).toList();
  }

  void clear() => state = [];
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(() {
  return RecentSearchesNotifier();
});

// ─── Trending Cuisines (from backend) ─────────────────────────────────────────

final trendingCuisinesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(searchRepositoryProvider);
  return repository.getTrendingCuisines();
});

// ─── Search Results ───────────────────────────────────────────────────────────

final searchResultsProvider = FutureProvider.autoDispose<List<Restaurant>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  final repository = ref.watch(searchRepositoryProvider);
  return repository.searchRestaurants(query);
});

final aiSearchResultsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return {'intent': null, 'results': []};
  final repository = ref.watch(searchRepositoryProvider);
  return repository.aiSearch(query);
});
