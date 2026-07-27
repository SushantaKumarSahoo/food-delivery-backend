import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/restaurant_provider.dart';
import '../../ai/ai_order_assistant_sheet.dart';
import '../../cart/application/cart_provider.dart';
import '../../../core/api/api_client.dart';

// ─── Favorite toggle — uses local StatefulWidget to avoid Riverpod 3 family complexity ──

class _FavButton extends StatefulWidget {
  final String restaurantId;
  const _FavButton({required this.restaurantId});

  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton> {
  bool _isFav = false;
  bool _isLoading = false;

  Future<void> _toggle(WidgetRef ref) async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(apiClientProvider);
      if (_isFav) {
        await dio.delete('/users/favorites/${widget.restaurantId}');
      } else {
        await dio.post('/users/favorites', data: {'storeId': widget.restaurantId});
      }
      setState(() => _isFav = !_isFav);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isFav ? 'Added to favorites ❤️' : 'Removed from favorites'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      setState(() => _isFav = !_isFav); // optimistic
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
              : Icon(_isFav ? LucideIcons.heartOff : LucideIcons.heart,
                  size: 20, color: _isFav ? Colors.red : Colors.black87),
        ),
        onPressed: _isLoading ? null : () => _toggle(ref),
      ),
    );
  }
}

class RestaurantDetailScreen extends ConsumerWidget {
  final String restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final restaurantAsyncValue = ref.watch(restaurantDetailsProvider(restaurantId));
    final menuAsyncValue = ref.watch(menuProvider(restaurantId));

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
              _FavButton(restaurantId: restaurantId),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'restaurant_image_$restaurantId',
                child: restaurantAsyncValue.maybeWhen(
                  data: (restaurant) => restaurant.imageUrl != null && restaurant.imageUrl!.isNotEmpty
                      ? Image.network(restaurant.imageUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade300, child: const Center(child: Icon(LucideIcons.image, size: 50, color: Colors.grey))),
                  orElse: () => Container(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          // Restaurant Header & Details
          restaurantAsyncValue.when(
            data: (restaurant) => SliverToBoxAdapter(
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
                          Expanded(child: Text(restaurant.name, style: theme.textTheme.displayLarge?.copyWith(fontSize: 28), maxLines: 2, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
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
                                Text(restaurant.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                      
                      const SizedBox(height: 8),
                      Text(restaurant.tags.join(' • '), style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16))
                        .animate().fadeIn(delay: 300.ms),
                      
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(LucideIcons.clock, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('${restaurant.deliveryTimeMinutes} min', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          
                          const SizedBox(width: 24),
                          
                          Icon(LucideIcons.bike, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(restaurant.deliveryFee == 0 ? 'Free Delivery' : '₹${restaurant.deliveryFee}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),
                      
                      if (restaurant.description != null) ...[
                        const SizedBox(height: 16),
                        Text(restaurant.description!, style: theme.textTheme.bodyMedium),
                      ],
                      
                      const SizedBox(height: 32),
                      
                      Text('Menu', style: theme.textTheme.titleLarge?.copyWith(fontSize: 22))
                        .animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))),
            error: (e, s) => SliverToBoxAdapter(child: Center(child: Text('Error loading details: $e'))),
          ),
          
          // Menu Items
          menuAsyncValue.when(
            data: (items) {
              if (items.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No menu items available.'))),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      
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
                                image: item.imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover) : null,
                              ),
                              child: item.imageUrl.isEmpty ? const Center(child: Icon(LucideIcons.image, color: Colors.grey)) : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                                  const SizedBox(height: 4),
                                  if (item.description.isNotEmpty) Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Text('₹${item.price}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
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
                    childCount: items.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, s) => SliverToBoxAdapter(child: Center(child: Text('Error loading menu: $e'))),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      
      // Dual FABs: AI Assistant + Cart
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Order Assistant FAB
          FloatingActionButton.extended(
            heroTag: 'ai_fab',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AiOrderAssistantSheet(storeId: restaurantId),
              );
            },
            backgroundColor: const Color(0xFF6C63FF),
            icon: const Icon(LucideIcons.sparkles, color: Colors.white),
            label: const Text('AI Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ).animate(delay: 500.ms).slideX(begin: 1, end: 0).fadeIn(),
          const SizedBox(height: 12),
          // Cart FAB
          Consumer(
            builder: (context, ref, _) {
              final cartAsync = ref.watch(cartProvider);
              final count = cartAsync.value?.items.fold<int>(0, (s, i) => s + i.quantity) ?? 0;
              return GestureDetector(
                onTap: () => context.push('/cart'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: count > 0 ? theme.colorScheme.primary : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.shoppingBag, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        count > 0 ? 'View Cart ($count item${count > 1 ? 's' : ''})' : 'Cart is empty',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ).animate(delay: 1000.ms).slideY(begin: 1, end: 0).fadeIn(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
