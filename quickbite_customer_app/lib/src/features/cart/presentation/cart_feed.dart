import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

class CartFeed extends StatelessWidget {
  const CartFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                        Text('Home • 123 Main St, Apt 4B', style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, color: Colors.grey.shade400),
                ],
              ).animate().fadeIn().slideX(begin: -0.1, end: 0),
            ),
          ),
          
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final items = [
                  {'name': 'Whopper Meal', 'price': '₹299', 'qty': '2', 'img': '🍔'},
                  {'name': 'Onion Rings', 'price': '₹99', 'qty': '1', 'img': '🧅'},
                ];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(child: Text(items[index]['img']!, style: const TextStyle(fontSize: 30))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(items[index]['name']!, style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(items[index]['price']!, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
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
                          Text(items[index]['qty']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              childCount: 2,
            ),
          ),
          
          SliverToBoxAdapter(
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
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildBillRow('Item Total', '₹697'),
                        const SizedBox(height: 12),
                        _buildBillRow('Delivery Fee', '₹40', highlight: true),
                        const SizedBox(height: 12),
                        _buildBillRow('Taxes & Charges', '₹35'),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('To Pay', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                            Text('₹772', style: TextStyle(color: theme.colorScheme.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/tracking/123'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: const Text('Checkout & Pay'),
                    ),
                  ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.9, 0.9)),
                  
                  const SizedBox(height: 100), // Bottom nav bar padding
                ],
              ),
            ),
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
