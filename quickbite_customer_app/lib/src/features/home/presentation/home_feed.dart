import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

class HomeFeed extends StatefulWidget {
  const HomeFeed({super.key});

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  int _selectedCategoryIndex = 0;

  final List<Map<String, dynamic>> _macroCategories = [
    {'name': 'Food Delivery', 'emoji': '🍔', 'color': const Color(0xFFFFF0E6), 'type': 'Food'},
    {'name': 'Grocery', 'emoji': '🛒', 'color': const Color(0xFFE6F5FF), 'type': 'Grocery'},
    {'name': 'Fresh Meat', 'emoji': '🥩', 'color': const Color(0xFFFFE6E6), 'type': 'Meat'},
    {'name': 'Wine & Spirits', 'emoji': '🍷', 'color': const Color(0xFFF5E6FF), 'type': 'Wine'},
  ];

  final List<Map<String, dynamic>> _allStores = [
    // Food
    {'name': 'Burger King', 'type': 'Food', 'img': 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80', 'rating': '4.5', 'tags': 'American • Fast Food'},
    {'name': 'Pizza Hut', 'type': 'Food', 'img': 'https://images.unsplash.com/photo-1550547660-d9450f859349?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80', 'rating': '4.2', 'tags': 'Pizza • Italian'},
    // Grocery
    {'name': 'FreshMart Groceries', 'type': 'Grocery', 'img': 'https://images.unsplash.com/photo-1542838132-92c53300491e?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80', 'rating': '4.8', 'tags': 'Vegetables • Daily Needs'},
    {'name': 'BlinkIt Essentials', 'type': 'Grocery', 'img': 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80', 'rating': '4.6', 'tags': 'Snacks • Beverages'},
    // Meat
    {'name': 'Prime Cuts Meat', 'type': 'Meat', 'img': 'https://images.unsplash.com/photo-1603048297172-c92544798d5e?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80', 'rating': '4.9', 'tags': 'Chicken • Mutton'},
    {'name': 'Ocean Catch Seafood', 'type': 'Meat', 'img': 'https://images.unsplash.com/photo-1615141982883-c7ad0e69fd62?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80', 'rating': '4.7', 'tags': 'Fish • Prawns'},
    // Wine
    {'name': 'Vintage Vines', 'type': 'Wine', 'img': 'https://images.unsplash.com/photo-1506377247377-2a5b3b417ebb?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80', 'rating': '4.7', 'tags': 'Red Wine • White Wine'},
    {'name': 'Craft Beer Hub', 'type': 'Wine', 'img': 'https://images.unsplash.com/photo-1538485399081-7191377e8241?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80', 'rating': '4.8', 'tags': 'IPA • Stout'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final activeType = _macroCategories[_selectedCategoryIndex]['type'];
    final filteredStores = _allStores.where((store) => store['type'] == activeType).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Sticky Location App Bar
          SliverAppBar(
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            title: Row(
              children: [
                Icon(LucideIcons.mapPin, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Home', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.chevronDown, size: 16),
                      ],
                    ),
                    Text('123 Main Street, New York', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  ],
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
                child: const Icon(LucideIcons.bell, size: 20),
              )
            ],
          ),

          // Search Bar (Dynamic hint text based on category)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: GestureDetector(
                onTap: () => context.push('/search'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.search, color: Colors.grey.shade400),
                      const SizedBox(width: 12),
                      Text('Search in "${_macroCategories[_selectedCategoryIndex]['name']}"', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                    ],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            ),
          ),

          // Macro Super-App Categories (Interactive)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildMacroCategory(0),
                      const SizedBox(width: 16),
                      _buildMacroCategory(1),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMacroCategory(2),
                      const SizedBox(width: 16),
                      _buildMacroCategory(3),
                    ],
                  )
                ],
              ),
            ),
          ),

          // Trending Header
          SliverToBoxAdapter(
            key: ValueKey('header_$_selectedCategoryIndex'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Top in ${_macroCategories[_selectedCategoryIndex]['name']}', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                  Text('See All', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ).animate().fadeIn(),
            ),
          ),

          // Filtered Stores List
          SliverList(
            key: ValueKey('list_$_selectedCategoryIndex'),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final store = filteredStores[index];

                return GestureDetector(
                  onTap: () => context.push('/restaurant/${index + 1}'),
                  child: Container(
                    margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image with Hero
                        Hero(
                          tag: 'restaurant_image_${store['name']}',
                          child: Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              image: DecorationImage(
                                image: NetworkImage(store['img']!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(store['name']!, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                                  const SizedBox(height: 4),
                                  Text(store['tags']!, style: theme.textTheme.bodyMedium),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    Text(store['rating']!, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    Icon(LucideIcons.star, size: 14, color: Colors.green.shade700),
                                  ],
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ).animate().slideY(begin: 0.1, end: 0).fadeIn(),
                );
              },
              childCount: filteredStores.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildMacroCategory(int index) {
    final cat = _macroCategories[index];
    final isSelected = _selectedCategoryIndex == index;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategoryIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: 110,
          decoration: BoxDecoration(
            color: cat['color'] as Color,
            borderRadius: BorderRadius.circular(24),
            border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 3) : Border.all(color: Colors.transparent, width: 3),
            boxShadow: isSelected 
                ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: isSelected ? -5 : -15,
                right: isSelected ? 0 : -10,
                child: Text(cat['emoji'] as String, style: TextStyle(fontSize: isSelected ? 80 : 70)),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: SizedBox(
                  width: 80,
                  child: Text(
                    cat['name'] as String,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18, 
                      height: 1.1,
                      color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (index * 100).ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
