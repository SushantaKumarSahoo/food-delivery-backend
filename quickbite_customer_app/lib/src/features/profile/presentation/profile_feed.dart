import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../auth/application/auth_provider.dart';
import '../application/user_provider.dart';
import '../application/wallet_provider.dart';
import '../data/user_repository.dart';
import '../domain/user_profile.dart';
import '../../review/presentation/review_sheet.dart';
import '../../offers/presentation/offers_sheet.dart';
import '../../offers/presentation/gift_card_sheet.dart';

class ProfileFeed extends ConsumerWidget {
  const ProfileFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsyncValue = ref.watch(userProfileProvider);
    final walletAsyncValue = ref.watch(walletBalanceProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'My Profile',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 24, color: theme.colorScheme.onSurface),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Profile Card (Interactive)
                  profileAsyncValue.when(
                    data: (profile) => GestureDetector(
                      onTap: () => _showEditProfileModal(context, ref, profile),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.surface, theme.colorScheme.surface.withOpacity(0.9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                              child: Text(
                                profile.initials,
                                style: theme.textTheme.displayLarge?.copyWith(fontSize: 28, color: theme.colorScheme.primary),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName.isNotEmpty ? profile.fullName : 'QuickBite User',
                                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile.email.isNotEmpty ? profile.email : 'Add email address',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                                  ),
                                  if (profile.phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      profile.phone,
                                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500, fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(LucideIcons.pencil, size: 18, color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                    error: (e, s) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Failed to load profile. Tap retry.', style: TextStyle(color: Colors.red.shade900))),
                          TextButton(
                            onPressed: () => ref.invalidate(userProfileProvider),
                            child: const Text('Retry'),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions Grid
                  Row(
                    children: [
                      _buildQuickActionCard(
                        context,
                        LucideIcons.heart,
                        'Favorites',
                        Colors.pink,
                        onTap: () => _showFavoritesModal(context),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showWalletModal(context, (walletAsyncValue.value ?? 0).toInt()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Icon(LucideIcons.wallet, color: theme.colorScheme.primary, size: 28),
                                const SizedBox(height: 8),
                                walletAsyncValue.when(
                                  data: (balance) => Text('₹$balance', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  loading: () => const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                  error: (_, __) => const Text('₹0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildQuickActionCard(
                        context,
                        LucideIcons.tag,
                        'Offers',
                        Colors.orange,
                        onTap: () => _showOffersModal(context),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),

                  // Food Orders Group
                  _buildSectionTitle('Food Orders', theme),
                  _buildListTile(
                    LucideIcons.shoppingBag,
                    'Your Orders',
                    'View real past and active orders',
                    theme,
                    onTap: () => _showOrdersModal(context, ref),
                  ),
                  _buildListTile(
                    LucideIcons.star,
                    'Your Ratings & Reviews',
                    'Ratings given to restaurants & riders',
                    theme,
                    onTap: () => _showRatingsModal(context),
                  ),

                  const SizedBox(height: 24),

                  // Account & Payments Group
                  _buildSectionTitle('Account & Payments', theme),
                  _buildListTile(
                    LucideIcons.mapPin,
                    'Saved Addresses',
                    'Home, Office, and custom map locations',
                    theme,
                    onTap: () => _showAddressesModal(context, ref),
                  ),
                  _buildListTile(
                    LucideIcons.creditCard,
                    'Payment Methods',
                    'Manage UPI IDs, Cards & Cash on Delivery',
                    theme,
                    onTap: () => _showPaymentMethodsModal(context, ref),
                  ),
                  _buildListTile(
                    LucideIcons.gift,
                    'Gift Cards & Vouchers',
                    'Claim balance or buy gift cards',
                    theme,
                    onTap: () => _showGiftCardsModal(context),
                  ),

                  const SizedBox(height: 24),

                  // Settings & Support Group
                  _buildSectionTitle('More', theme),
                  _buildListTile(
                    LucideIcons.helpCircle,
                    'Help & Support',
                    'FAQs, live chat, and dispute center',
                    theme,
                    onTap: () => _showHelpSupportModal(context),
                  ),
                  _buildListTile(
                    LucideIcons.settings,
                    'Preferences & Settings',
                    'Notifications, Privacy & App settings',
                    theme,
                    onTap: () => _showSettingsModal(context),
                  ),
                  _buildListTile(
                    LucideIcons.info,
                    'About QuickBite',
                    'Terms of service, Privacy Policy & Version',
                    theme,
                    onTap: () => _showAboutModal(context),
                  ),

                  const SizedBox(height: 32),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Log Out'),
                            content: const Text('Are you sure you want to log out of QuickBite?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                child: const Text('Log Out', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await ref.read(authControllerProvider.notifier).logout();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        }
                      },
                      icon: const Icon(LucideIcons.logOut, color: Colors.redAccent),
                      label: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, IconData icon, String label, Color color, {required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, ThemeData theme, {required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600, fontSize: 13)),
        trailing: Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.05, end: 0);
  }

  // ─── 1. REAL ORDERS MODAL ───────────────────────────────────────────────────

  void _showOrdersModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final ordersAsync = ref.watch(userOrdersProvider);

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollController) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your Real Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ordersAsync.when(
                    data: (orders) {
                      if (orders.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.shoppingBag, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text('No Orders Placed Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Explore top restaurants and order your favorite meal!', style: TextStyle(color: Colors.grey.shade600)),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  context.go('/home');
                                },
                                child: const Text('Browse Restaurants'),
                              )
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (ctx, index) {
                          final order = orders[index];
                          final orderNumber = order['orderNumber'] ?? 'QB-${order['id'].substring(0, 6)}';
                          final status = (order['status'] ?? 'created').toString().toLowerCase();
                          final totalAmount = order['totalAmount'] ?? order['subtotal'] ?? 0;
                          final items = (order['items'] as List<dynamic>?) ?? [];
                          final itemSummary = items.isNotEmpty
                              ? items.map((i) => '${i['quantity']}x ${i['productName']}').join(', ')
                              : 'Food Delivery Items';

                          final isDelivered = status == 'delivered';
                          final isCancelled = status == 'cancelled';
                          final isActive = !isDelivered && !isCancelled;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      orderNumber,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.orange.shade50
                                            : (isDelivered ? Colors.green.shade50 : Colors.red.shade50),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: isActive
                                              ? Colors.orange.shade800
                                              : (isDelivered ? Colors.green.shade800 : Colors.red.shade800),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(itemSummary, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total: ₹$totalAmount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (isActive)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          context.push('/tracking/${order['id']}');
                                        },
                                        icon: const Icon(LucideIcons.navigation, size: 14),
                                        label: const Text('Track Live'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepOrange,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                        ),
                                      ),
                                    if (isDelivered)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          final storeId = (order['store'] as Map?)?['id']?.toString()
                                              ?? order['storeId']?.toString() ?? '';
                                          final storeName = (order['store'] as Map?)?['name']?.toString()
                                              ?? 'this restaurant';
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                            ),
                                            builder: (_) => ReviewSheet(
                                              orderId: order['id'],
                                              storeId: storeId,
                                              storeName: storeName,
                                            ),
                                          );
                                        },
                                        icon: const Icon(LucideIcons.star, size: 14),
                                        label: const Text('Rate Order'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber.shade700,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Failed to load orders: $e')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 2. PAYMENT METHODS ─────────────────────────────────────────────────────

  void _showPaymentMethodsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final methodsAsync = ref.watch(paymentMethodsProvider);
        return StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Methods', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x)),
                  ],
                ),
                const SizedBox(height: 12),
                methodsAsync.when(
                  data: (methods) {
                    if (methods.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('No payment methods saved yet.',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ),
                      );
                    }
                    return Column(
                      children: methods.map((m) {
                        final type = (m['type'] ?? m['methodType'] ?? 'UPI').toString().toUpperCase();
                        final title = m['title'] ?? m['name'] ?? type;
                        final subtitle = m['subtitle'] ?? m['description'] ?? '';
                        final isUpi = type.contains('UPI');
                        final isCard = type.contains('CARD');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isUpi ? Colors.purple.shade50 : (isCard ? Colors.blue.shade50 : Colors.green.shade50),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isUpi ? LucideIcons.smartphone : (isCard ? LucideIcons.creditCard : LucideIcons.banknote),
                                  color: isUpi ? Colors.purple : (isCard ? Colors.blue : Colors.green),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    if (subtitle.toString().isNotEmpty)
                                      Text(subtitle.toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 20),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('Could not load methods', style: TextStyle(color: Colors.grey.shade500))),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showAddPaymentDialog(context, ref);
                    },
                    icon: const Icon(LucideIcons.plusCircle),
                    label: const Text('Add New Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddPaymentDialog(BuildContext context, WidgetRef ref) {
    final upiController = TextEditingController();
    final cardController = TextEditingController();
    int selectedType = 0; // 0: UPI, 1: Card

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('UPI ID'),
                      selected: selectedType == 0,
                      onSelected: (_) => setState(() => selectedType = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Debit/Credit Card'),
                      selected: selectedType == 1,
                      onSelected: (_) => setState(() => selectedType = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (selectedType == 0)
                TextField(
                  controller: upiController,
                  decoration: const InputDecoration(
                    labelText: 'Enter UPI ID (e.g. 9938123456@ybl)',
                    prefixIcon: Icon(LucideIcons.smartphone),
                    border: OutlineInputBorder(),
                  ),
                )
              else
                TextField(
                  controller: cardController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Card Number (16 Digits)',
                    prefixIcon: Icon(LucideIcons.creditCard),
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final text = selectedType == 0 ? upiController.text.trim() : cardController.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(ctx);

                final type = selectedType == 0 ? 'UPI' : 'Card';
                final title = selectedType == 0
                    ? 'UPI ($text)'
                    : 'Card (•••• ${text.length >= 4 ? text.substring(text.length - 4) : text})';

                try {
                  await ref.read(userRepositoryProvider).addPaymentMethod({
                    'type': type,
                    'title': title,
                    'methodType': type.toLowerCase(),
                  });
                  ref.invalidate(paymentMethodsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment method saved!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved locally — will sync when online.')),
                    );
                  }
                }
              },
              child: const Text('Add Method'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. SAVED ADDRESSES & INTERACTIVE MAP LOCATION PICKER ──────────────────

  void _showAddressesModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (ctx, scrollController) => _AddressModalContent(scrollController: scrollController),
      ),
    );
  }

  // ─── Other Modals ──────────────────────────────────────────────────────────

  void _showEditProfileModal(BuildContext context, WidgetRef ref, UserProfile profile) {
    final nameController = TextEditingController(text: profile.fullName);
    final emailController = TextEditingController(text: profile.email);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit Profile Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(LucideIcons.user),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(LucideIcons.mail),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => isSaving = true);
                            try {
                              await ref.read(userRepositoryProvider).updateProfile(
                                    fullName: nameController.text.trim(),
                                    email: emailController.text.trim(),
                                  );
                              ref.invalidate(userProfileProvider);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              setState(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWalletModal(BuildContext context, num balance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final txAsync = ref.watch(walletTransactionsProvider);
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (ctx, scroll) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('QuickBite Wallet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFFF5722)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('₹$balance', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Add Money feature coming soon!')),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepOrange),
                          child: const Text('Add Money'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: txAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => Center(child: Text('Could not load transactions', style: TextStyle(color: Colors.grey.shade500))),
                      data: (transactions) {
                        if (transactions.isEmpty) {
                          return Center(
                            child: Text('No transactions yet', style: TextStyle(color: Colors.grey.shade500)),
                          );
                        }
                        return ListView.separated(
                          controller: scroll,
                          itemCount: transactions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final tx = transactions[i];
                            final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
                            final isCredit = (tx['type'] ?? tx['transactionType'] ?? '').toString().toLowerCase().contains('credit') || amount > 0;
                            final description = tx['description'] ?? tx['note'] ?? (isCredit ? 'Wallet Credit' : 'Order Payment');
                            final date = tx['createdAt'] != null
                                ? DateTime.tryParse(tx['createdAt'].toString())
                                : null;
                            final dateStr = date != null
                                ? '${date.day} ${_monthName(date.month)} ${date.year}'
                                : '';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCredit ? Colors.green.shade50 : Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                                  color: isCredit ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(description, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: dateStr.isNotEmpty ? Text(dateStr) : null,
                              trailing: Text(
                                '${isCredit ? '+' : '-'}₹${amount.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isCredit ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }

  void _showOffersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OffersSheet(),
    );
  }

  void _showFavoritesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.heart, size: 48, color: Colors.pink),
            const SizedBox(height: 16),
            const Text('Your Favorite Restaurants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Heart your favorite restaurants & dishes while exploring to save them here!', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Explore Restaurants')),
          ],
        ),
      ),
    );
  }

  void _showRatingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.star, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            const Text('Your Ratings & Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Rate your delivered orders from Your Orders section!', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showGiftCardsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GiftCardSheet(),
    );
  }

  void _showHelpSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Help & Customer Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x)),
              ],
            ),
            const SizedBox(height: 12),
            const ListTile(
              leading: Icon(LucideIcons.messageSquare, color: Colors.deepOrange),
              title: Text('Chat with Live Support'),
              subtitle: Text('24/7 instant order assistance'),
            ),
            const ListTile(
              leading: Icon(LucideIcons.fileText, color: Colors.blue),
              title: Text('Order Refund & Cancellation Policy'),
              subtitle: Text('Read QuickBite support FAQs'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          bool pushNotifications = true;
          bool orderSMS = true;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('App Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x)),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Live order updates and offers'),
                  value: pushNotifications,
                  onChanged: (val) => setState(() => pushNotifications = val),
                ),
                SwitchListTile(
                  title: const Text('SMS Notifications'),
                  subtitle: const Text('Delivery status SMS alerts'),
                  value: orderSMS,
                  onChanged: (val) => setState(() => orderSMS = val),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAboutModal(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'QuickBite Food Delivery',
      applicationVersion: 'v2.4.0 (Build 2026)',
      applicationIcon: const Icon(LucideIcons.utensils, size: 40, color: Colors.deepOrange),
      children: [
        const SizedBox(height: 12),
        const Text('QuickBite is your ultra-fast food delivery platform.'),
      ],
    );
  }
}

// ─── INTERACTIVE MAP & ADDRESS PICKER WIDGET ────────────────────────────────

class _AddressModalContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _AddressModalContent({required this.scrollController});

  @override
  ConsumerState<_AddressModalContent> createState() => _AddressModalContentState();
}

class _AddressModalContentState extends ConsumerState<_AddressModalContent> {
  final MapController _mapController = MapController();
  final _labelController = TextEditingController(text: 'Home');
  final _streetController = TextEditingController(text: 'Plot 102, DLF Cybercity');
  final _cityController = TextEditingController(text: 'Bhubaneswar');
  final _pincodeController = TextEditingController(text: '751024');

  LatLng _selectedCenter = const LatLng(20.3012, 85.8201);
  int _selectedPresetIndex = 0;
  bool _isSaving = false;
  bool _isGeocoding = false;

  final List<Map<String, dynamic>> _mapPresets = [
    {
      'label': 'Cybercity (Home)',
      'street': 'Plot 102, DLF Cybercity',
      'city': 'Bhubaneswar',
      'pincode': '751024',
      'lat': 20.3012,
      'lng': 85.8201,
    },
    {
      'label': 'Infocity (Office)',
      'street': 'Suite 405, Infocity Tower B',
      'city': 'Bhubaneswar',
      'pincode': '751003',
      'lat': 20.3541,
      'lng': 85.8152,
    },
    {
      'label': 'Jaydev Vihar',
      'street': 'House 44, Near Mayfair Hotel',
      'city': 'Bhubaneswar',
      'pincode': '751013',
      'lat': 20.2980,
      'lng': 85.8290,
    },
  ];

  void _selectPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      final preset = _mapPresets[index];
      _selectedCenter = LatLng(preset['lat'], preset['lng']);
      _labelController.text = preset['label'].toString().split(' ')[0];
      _streetController.text = preset['street'];
      _cityController.text = preset['city'];
      _pincodeController.text = preset['pincode'];
    });
    _mapController.move(_selectedCenter, 15.0);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() => _isGeocoding = true);
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {'format': 'json', 'lat': lat, 'lon': lng},
      );
      if (response.statusCode == 200 && response.data != null) {
        final address = response.data['address'] ?? {};
        final road = address['road'] ?? address['suburb'] ?? address['neighbourhood'] ?? 'Pin Location';
        final city = address['city'] ?? address['town'] ?? address['village'] ?? address['state_district'] ?? 'Bhubaneswar';
        final postcode = address['postcode'] ?? '751001';

        setState(() {
          _streetController.text = road.toString();
          _cityController.text = city.toString();
          _pincodeController.text = postcode.toString();
        });
      }
    } catch (_) {
      // Keep existing input
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(userAddressesProvider);

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saved Delivery Addresses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
              ],
            ),
            const SizedBox(height: 12),

            // Live Saved Addresses List
            addressesAsync.when(
              data: (addresses) {
                if (addresses.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.mapPin, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(child: Text('No saved addresses found. Pick location on the map below!')),
                      ],
                    ),
                  );
                }
                return Column(
                  children: addresses.map((addr) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: const Icon(LucideIcons.mapPin, color: Colors.deepOrange),
                      title: Text(addr['label'] ?? 'Saved Address', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${addr['addressLine1'] ?? addr['fullAddress'] ?? ''}, ${addr['city'] ?? ''} ${addr['postalCode'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
                        onPressed: () async {
                          await ref.read(userRepositoryProvider).deleteAddress(addr['id']);
                          ref.invalidate(userAddressesProvider);
                        },
                      ),
                    ),
                  )).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, s) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  children: [
                    Icon(LucideIcons.mapPin, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(child: Text('Pick location on the real map below to save a new address!')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text('Real OpenStreetMap Location Picker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Pan map or tap preset below. Center pin auto-updates address:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),

            const SizedBox(height: 16),

            // REAL OPENSTREETMAP FLUTTERMAP CONTAINER
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.deepOrange.withOpacity(0.4), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedCenter,
                        initialZoom: 15.0,
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture) {
                            setState(() {
                              _selectedCenter = position.center;
                            });
                            _reverseGeocode(_selectedCenter.latitude, _selectedCenter.longitude);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.quickbite.customer_app',
                        ),
                      ],
                    ),

                    // Fixed Center Pin Marker
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isGeocoding)
                                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  else
                                    const Icon(LucideIcons.navigation, size: 12, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isGeocoding ? 'Locating...' : 'Set Delivery Pin',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(LucideIcons.mapPin, size: 44, color: Colors.deepOrange),
                          ],
                        ),
                      ),
                    ),

                    // Map GPS & Reset Buttons
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'my_location_btn',
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepOrange,
                            onPressed: () {
                              final current = const LatLng(20.3012, 85.8201);
                              _mapController.move(current, 15.5);
                              setState(() => _selectedCenter = current);
                              _reverseGeocode(current.latitude, current.longitude);
                            },
                            child: const Icon(LucideIcons.crosshair, size: 18),
                          ),
                        ],
                      ),
                    ),

                    // Lat/Lng Overlay Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Text(
                          '${_selectedCenter.latitude.toStringAsFixed(4)}, ${_selectedCenter.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Location Preset Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_mapPresets.length, (index) {
                  final isSelected = _selectedPresetIndex == index;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(_mapPresets[index]['label']),
                      avatar: Icon(
                        index == 0 ? LucideIcons.home : (index == 1 ? LucideIcons.building : LucideIcons.users),
                        size: 16,
                        color: isSelected ? Colors.white : Colors.deepOrange,
                      ),
                      selectedColor: Colors.deepOrange,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) => _selectPreset(index),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            // Address Details Form Inputs
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: 'Label (Home / Work / Other)',
                prefixIcon: const Icon(LucideIcons.tag),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _streetController,
              decoration: InputDecoration(
                labelText: 'Street Address (Auto-filled from map pin)',
                prefixIcon: const Icon(LucideIcons.navigation),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: 'City',
                      prefixIcon: const Icon(LucideIcons.building2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Pincode',
                      prefixIcon: const Icon(LucideIcons.hash),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Save Address Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (_streetController.text.trim().isEmpty) return;
                        setState(() => _isSaving = true);
                        try {
                          await ref.read(userRepositoryProvider).addAddress({
                            'label': _labelController.text.trim(),
                            'fullAddress': _streetController.text.trim(),
                            'addressLine1': _streetController.text.trim(),
                            'city': _cityController.text.trim(),
                            'state': 'Odisha',
                            'postalCode': _pincodeController.text.trim(),
                            'latitude': _selectedCenter.latitude,
                            'longitude': _selectedCenter.longitude,
                          });
                          ref.invalidate(userAddressesProvider);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Real map location saved successfully!'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setState(() => _isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                            );
                          }
                        }
                      },
                icon: const Icon(LucideIcons.check),
                label: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Real Map Location & Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
