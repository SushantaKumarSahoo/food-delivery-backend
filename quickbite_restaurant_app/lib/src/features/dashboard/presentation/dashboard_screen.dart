import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../onboarding/application/merchant_provider.dart';
import '../../orders/application/order_provider.dart';
import '../../orders/domain/order.dart';
import '../../menu/application/menu_provider.dart';
import '../../menu/domain/product.dart';
import '../../menu/application/menu_provider.dart';
import '../../menu/domain/product.dart';
import '../../menu/presentation/ai_import_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsyncValue = ref.watch(merchantStatusProvider);

    return statusAsyncValue.when(
      data: (hasOnboarded) {
        if (!hasOnboarded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/onboard');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return const _DashboardContent();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Focus Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.black87),
            onPressed: () => ref.read(orderProvider.notifier).refreshOrders(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          final newOrders = orders.where((o) => o.status == 'created').toList();
          final activeOrders = orders.where((o) => o.status == 'preparing' || o.status == 'ready').toList();
          
          return Column(
            children: [
              if (newOrders.isNotEmpty) _buildNewOrdersAlert(newOrders, ref),
              Expanded(
                child: activeOrders.isEmpty 
                    ? const Center(child: Text('No active orders. Waiting for new orders...', style: TextStyle(fontSize: 16, color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: activeOrders.length,
                        itemBuilder: (context, index) {
                          return _ActiveOrderCard(order: activeOrders[index])
                              .animate()
                              .fade(duration: 400.ms)
                              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                        },
                      ),
              ),
              _buildQuickActions(context),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading orders: $e')),
      ),
    );
  }

  Widget _buildNewOrdersAlert(List<Order> newOrders, WidgetRef ref) {
    // Show only the oldest new order to force focus
    final order = newOrders.last;
    return Container(
      width: double.infinity,
      color: Colors.red.shade600,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.bellRing, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Text('NEW ORDER ALERT!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .tint(color: Colors.yellowAccent, duration: 800.ms),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Order ${order.orderNumber}',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (order.customerTrustScore < 70) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.yellowAccent.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.alertTriangle, color: Colors.black, size: 20),
                  SizedBox(width: 8),
                  Text('⚠️ High Risk Customer (Score < 70)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text('${item.quantity}x ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 18))),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => ref.read(orderProvider.notifier).updateStatus(order.id, 'cancelled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('REJECT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => ref.read(orderProvider.notifier).updateStatus(order.id, 'preparing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('ACCEPT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (newOrders.length > 1) ...[
            const SizedBox(height: 16),
            Text('+ ${newOrders.length - 1} more new orders waiting', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
        ]
      ),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(LucideIcons.wand2, size: 24),
                label: const Text('AI Menu Wizard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AIImportScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.powerOff, size: 24),
                    label: const Text('Mark Out of Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => const _QuickMenuSheet(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(LucideIcons.settings, size: 24),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends ConsumerWidget {
  final Order order;
  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = DateFormat('hh:mm a');
    final isPreparing = order.status == 'preparing';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300)
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPreparing ? Colors.blue.shade50 : Colors.green.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isPreparing ? Colors.blue.shade900 : Colors.green.shade900),
                    ),
                    if (order.customerTrustScore < 70)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                        child: const Text('⚠️ High Risk', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                Text(
                  isPreparing ? 'PREPARING' : 'READY FOR PICKUP',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isPreparing ? Colors.blue.shade700 : Colors.green.shade700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
                    ],
                  ),
                )),
                const Divider(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isPreparing) {
                        ref.read(orderProvider.notifier).updateStatus(order.id, 'ready');
                      } else {
                        ref.read(orderProvider.notifier).updateStatus(order.id, 'delivered');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPreparing ? Colors.blue.shade600 : Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isPreparing ? 'MARK READY' : 'HANDED TO RIDER',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _QuickMenuSheet extends ConsumerStatefulWidget {
  const _QuickMenuSheet();
  @override
  ConsumerState<_QuickMenuSheet> createState() => _QuickMenuSheetState();
}

class _QuickMenuSheetState extends ConsumerState<_QuickMenuSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Menu Availability', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(LucideIcons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              ),
            ),
            Expanded(
              child: menuAsync.when(
                data: (products) {
                  final filtered = products.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No items found'));
                  }
                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_,__) => const Divider(),
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text(p.isAvailable ? 'In Stock' : 'Out of Stock', style: TextStyle(color: p.isAvailable ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        trailing: Switch(
                          value: p.isAvailable,
                          activeColor: Colors.green,
                          onChanged: (val) {
                            ref.read(menuProvider.notifier).toggleAvailability(p.id, p.isAvailable);
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            )
          ],
        );
      },
    );
  }
}
