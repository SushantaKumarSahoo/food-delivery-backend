import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../search/application/search_provider.dart';

class SearchFeed extends ConsumerStatefulWidget {
  const SearchFeed({super.key});

  @override
  ConsumerState<SearchFeed> createState() => _SearchFeedState();
}

class _SearchFeedState extends ConsumerState<SearchFeed> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(searchQueryProvider.notifier).setQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    if (query.trim().isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).add(query.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);
    final recentSearches = ref.watch(recentSearchesProvider);
    final trendingAsync = ref.watch(trendingCuisinesProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: theme.scaffoldBackgroundColor,
              toolbarHeight: 90,
              title: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submitSearch,
                  decoration: InputDecoration(
                    hintText: 'Search for food, restaurants...',
                    prefixIcon: Icon(LucideIcons.search, color: Colors.grey.shade400),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).setQuery('');
                            },
                          )
                        : Icon(LucideIcons.slidersHorizontal, color: theme.colorScheme.primary),
                    border: InputBorder.none,
                  ),
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0, duration: 400.ms),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.sparkles, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text('Smart AI Search', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Switch(
                      value: ref.watch(isSmartSearchProvider),
                      onChanged: (val) => ref.read(isSmartSearchProvider.notifier).toggle(val),
                      activeColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            if (query.isEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recent Searches
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Searches', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20))
                              .animate().fadeIn(delay: 200.ms),
                          if (recentSearches.isNotEmpty)
                            TextButton(
                              onPressed: () => ref.read(recentSearchesProvider.notifier).clear(),
                              child: Text('Clear all', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (recentSearches.isEmpty)
                        Text('Your recent searches will appear here.',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 14))
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: recentSearches.map((e) => GestureDetector(
                            onTap: () {
                              _searchController.text = e;
                              ref.read(searchQueryProvider.notifier).setQuery(e);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.history, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text(e, style: theme.textTheme.bodyMedium),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => ref.read(recentSearchesProvider.notifier).remove(e),
                                    child: Icon(LucideIcons.x, size: 12, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                            ),
                          )).toList(),
                        ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),

                      const SizedBox(height: 32),
                      Text('Trending Cuisines', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20))
                          .animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Trending cuisines grid
              trendingAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                ),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                data: (cuisines) => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= cuisines.length) return const SizedBox.shrink();
                        final cuisine = cuisines[index];
                        final colors = [
                          const Color(0xFFFFF0E6), const Color(0xFFE6F5FF),
                          const Color(0xFFE6FFE6), const Color(0xFFFFF0F5),
                          const Color(0xFFF5E6FF), const Color(0xFFFFFFE6),
                        ];
                        return GestureDetector(
                          onTap: () {
                            _searchController.text = cuisine['name'];
                            ref.read(searchQueryProvider.notifier).setQuery(cuisine['name']);
                            ref.read(recentSearchesProvider.notifier).add(cuisine['name']);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors[index % colors.length],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  bottom: -10,
                                  right: -10,
                                  child: Text(cuisine['icon'] ?? '🍽️', style: const TextStyle(fontSize: 60)),
                                ),
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Text(cuisine['name'], style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                                ),
                              ],
                            ),
                          ),
                        ).animate(delay: (500 + (index * 50)).ms).scale(begin: const Offset(0.8, 0.8)).fadeIn();
                      },
                      childCount: cuisines.length,
                    ),
                  ),
                ),
              ),
            ] else ...[
              if (ref.watch(isSmartSearchProvider))
                ref.watch(aiSearchResultsProvider).when(
                  data: (data) {
                    final products = data['results'] as List<dynamic>? ?? [];
                    if (products.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text('No smart results found for "$query"', style: theme.textTheme.bodyLarge),
                          ),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = products[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('₹${product['basePrice']} • ${product['store']?['name']}'),
                            trailing: const Icon(LucideIcons.chevronRight, size: 16),
                            onTap: () => context.push('/restaurant/${product['storeId']}'),
                          );
                        },
                        childCount: products.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                  ),
                  error: (e, st) => SliverToBoxAdapter(
                    child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Error: $e'))),
                  ),
                )
              else
                searchResultsAsync.when(
                  data: (restaurants) {
                    if (restaurants.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text('No restaurants found for "$query"', style: theme.textTheme.bodyLarge),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final store = restaurants[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade200,
                                image: store.imageUrl != null 
                                    ? DecorationImage(image: NetworkImage(store.imageUrl!), fit: BoxFit.cover)
                                    : null,
                              ),
                            ),
                            title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(store.tags.join(', ')),
                            trailing: const Icon(LucideIcons.chevronRight, size: 16),
                            onTap: () => context.push('/restaurant/${store.id}'),
                          );
                        },
                        childCount: restaurants.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                  error: (e, st) => SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('Error: $e'),
                      ),
                    ),
                  ),
                ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
