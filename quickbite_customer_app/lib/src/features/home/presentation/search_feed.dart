import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SearchFeed extends StatefulWidget {
  const SearchFeed({super.key});

  @override
  State<SearchFeed> createState() => _SearchFeedState();
}

class _SearchFeedState extends State<SearchFeed> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search for food, restaurants...',
                    prefixIcon: Icon(LucideIcons.search, color: Colors.grey.shade400),
                    suffixIcon: Icon(LucideIcons.slidersHorizontal, color: theme.colorScheme.primary),
                    border: InputBorder.none,
                  ),
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0, duration: 400.ms),
            ),
            
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Searches', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20))
                      .animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: ['Burger King', 'Sushi', 'Healthy Salads', 'Pizza Hut'].map((e) => 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            ],
                          ),
                        )
                      ).toList(),
                    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 32),
                    Text('Trending Cuisines', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20))
                      .animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            SliverPadding(
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
                    final cuisines = [
                      {'name': 'Fast Food', 'icon': '🍔', 'color': const Color(0xFFFFF0E6)},
                      {'name': 'Italian', 'icon': '🍕', 'color': const Color(0xFFE6F5FF)},
                      {'name': 'Asian', 'icon': '🍜', 'color': const Color(0xFFE6FFE6)},
                      {'name': 'Desserts', 'icon': '🍩', 'color': const Color(0xFFFFF0F5)},
                      {'name': 'Healthy', 'icon': '🥗', 'color': const Color(0xFFF5E6FF)},
                      {'name': 'Mexican', 'icon': '🌮', 'color': const Color(0xFFFFFFE6)},
                    ];
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: cuisines[index]['color'] as Color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: -10,
                            right: -10,
                            child: Text(cuisines[index]['icon'] as String, style: const TextStyle(fontSize: 60)),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Text(
                              cuisines[index]['name'] as String,
                              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: (500 + (index * 50)).ms).scale(begin: const Offset(0.8, 0.8)).fadeIn();
                  },
                  childCount: 6,
                ),
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
