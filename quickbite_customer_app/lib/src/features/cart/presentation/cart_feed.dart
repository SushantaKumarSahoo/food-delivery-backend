import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/cart_provider.dart';
import '../../profile/application/user_provider.dart';

class CartFeed extends ConsumerWidget {
  const CartFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartAsyncValue = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(LucideIcons.mapPin, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delivering to', style: theme.textTheme.bodyMedium),
                        ref.watch(userProfileProvider).when(
                          data: (profile) => Text('${profile.firstName}\'s Address', style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
                          loading: () => Text('Loading...', style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
                          error: (_, __) => Text('Add Address', style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, color: Colors.grey.shade400),
                ],
              ).animate().fadeIn().slideX(begin: -0.1, end: 0),
            ),
          ),
          
          cartAsyncValue.when(
            data: (cart) {
              if (cart.items.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('Your cart is empty'))),
                );
              }
              
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = cart.items[index];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))
                        ]
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60, height: 60,
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
                                Text(item.name, style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
                                const SizedBox(height: 8),
                                Text('₹${item.price}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                                child: const Icon(LucideIcons.minus, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                                child: const Icon(LucideIcons.plus, size: 16, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate(delay: (200 + (index * 100)).ms).slideY(begin: 0.2, end: 0).fadeIn();
                  },
                  childCount: cart.items.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, s) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
          ),
          
          cartAsyncValue.when(
            data: (cart) {
              if (cart.items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bill Details', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20))
                        .animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _buildBillRow('Item Total', '₹${cart.itemTotal}'),
                            const SizedBox(height: 12),
                            _buildBillRow('Delivery Fee', '₹${cart.deliveryFee}', highlight: cart.deliveryFee == 0),
                            const SizedBox(height: 12),
                            _buildBillRow('Taxes & Charges', '₹${cart.taxes}'),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('To Pay', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                                Text('₹${cart.total}', style: TextStyle(color: theme.colorScheme.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
                      
                      const SizedBox(height: 24),
                      
                      // Gamification: QuickCoins earn progress
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber.shade50, Colors.amber.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.sparkles, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'You will earn ${(cart.total * 0.1).floor()} QuickCoins!',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: 0.7, // Demo progress toward next reward
                                minHeight: 10,
                                backgroundColor: Colors.amber.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                              ).animate(onPlay: (controller) => controller.repeat(reverse: true)).shimmer(duration: 2000.ms),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Only 30 more coins to unlock a ₹50 discount! 🎉',
                              style: TextStyle(color: Colors.amber.shade800, fontSize: 13),
                            )
                          ],
                        ),
                      ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 32),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Create order first, then go to payment screen
                            final notifier = ref.read(cartProvider.notifier);
                            final orderId = await notifier.checkout('pending');
                            if (orderId != null && orderId.isNotEmpty && context.mounted) {
                              context.push('/payment/$orderId', extra: cart.total.toDouble());
                            }
                          },
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                          child: const Text('Proceed to Payment'),
                        ),
                      ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.9, 0.9)),
                      
                      const SizedBox(height: 100), // Bottom nav bar padding
                    ],
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (e, s) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          )
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String amount, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
        Text(
          highlight ? 'Free' : amount,
          style: TextStyle(
            color: highlight ? Colors.green : Colors.black87,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
            decoration: highlight ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}
