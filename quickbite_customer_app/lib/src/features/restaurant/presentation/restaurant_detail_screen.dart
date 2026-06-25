import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RestaurantDetailScreen extends StatelessWidget {
  final String restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black87),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.heart, size: 20, color: Colors.black87),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'restaurant_image_$restaurantId',
                child: Image.network(
                  'https://images.unsplash.com/photo-1550547660-d9450f859349?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              transform: Matrix4.translationValues(0, -30, 0),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Burger King', style: theme.textTheme.displayLarge?.copyWith(fontSize: 28)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.star, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              const Text('4.8', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 8),
                    Text('Burger • Fast Food • American', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16))
                      .animate().fadeIn(delay: 300.ms),
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(LucideIcons.clock, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('20-30 min', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 24),
                        Icon(LucideIcons.bike, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Free Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),
                    
                    const SizedBox(height: 32),
                    
                    Text('Popular Menu', style: theme.textTheme.titleLarge?.copyWith(fontSize: 22))
                      .animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          
          // Menu Items
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final items = [
                    {'name': 'Whopper Meal', 'price': '₹299', 'desc': 'Flame-grilled beef patty, tomatoes, fresh lettuce, mayo, ketchup.', 'img': '🍔'},
                    {'name': 'Chicken Royale', 'price': '₹249', 'desc': 'Crispy chicken breast, mayo, lettuce on a sesame seed bun.', 'img': '🍗'},
                    {'name': 'Onion Rings', 'price': '₹99', 'desc': 'Golden crispy battered onion rings.', 'img': '🧅'},
                    {'name': 'Coke Large', 'price': '₹89', 'desc': 'Refreshing Coca-Cola classic.', 'img': '🥤'},
                  ];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    transform: Matrix4.translationValues(0, -30, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(child: Text(items[index]['img']!, style: const TextStyle(fontSize: 40))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(items[index]['name']!, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(items[index]['desc']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
                              const SizedBox(height: 8),
                              Text(items[index]['price']!, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ).animate(delay: (600 + (index * 150)).ms).slideY(begin: 0.2, end: 0).fadeIn();
                },
                childCount: 4,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      
      // Floating Checkout Button
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: theme.colorScheme.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
          ]
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shoppingBag, color: Colors.white),
            SizedBox(width: 12),
            Text('View Cart (1 item)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ).animate(delay: 1000.ms).slideY(begin: 1, end: 0).fadeIn(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
