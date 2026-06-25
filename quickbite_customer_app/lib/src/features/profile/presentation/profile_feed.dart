import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ProfileFeed extends StatelessWidget {
  const ProfileFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  // User Profile Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.surface, theme.colorScheme.surface.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          child: Text('JD', style: theme.textTheme.displayLarge?.copyWith(fontSize: 28, color: theme.colorScheme.primary)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('John Doe', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                              const SizedBox(height: 4),
                              Text('john.doe@example.com', style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 2),
                              Text('+91 98765 43210', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                          child: Icon(LucideIcons.pencil, size: 18, color: Colors.grey.shade700),
                        )
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 24),

                  // Quick Actions Grid
                  Row(
                    children: [
                      _buildQuickActionCard(context, LucideIcons.heart, 'Favorites', Colors.pink),
                      const SizedBox(width: 16),
                      _buildQuickActionCard(context, LucideIcons.wallet, 'Wallet', theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      _buildQuickActionCard(context, LucideIcons.tag, 'Offers', Colors.orange),
                    ],
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),

                  // Food Orders Group
                  _buildSectionTitle('Food Orders', theme),
                  _buildListTile(LucideIcons.shoppingBag, 'Your Orders', 'View past and upcoming orders', theme),
                  _buildListTile(LucideIcons.star, 'Your Ratings', 'Restaurants and drivers you rated', theme),

                  const SizedBox(height: 24),

                  // Account & Payments Group
                  _buildSectionTitle('Account & Payments', theme),
                  _buildListTile(LucideIcons.mapPin, 'Saved Addresses', 'Home, Office, and others', theme),
                  _buildListTile(LucideIcons.creditCard, 'Payment Methods', 'Cards, UPI, and Netbanking', theme),
                  _buildListTile(LucideIcons.gift, 'Gift Cards', 'Check balance or redeem', theme),

                  const SizedBox(height: 24),

                  // More Group
                  _buildSectionTitle('More', theme),
                  _buildListTile(LucideIcons.helpCircle, 'Help & Support', 'FAQs and customer care', theme),
                  _buildListTile(LucideIcons.settings, 'Settings', 'Notifications, Dark Mode, etc.', theme),
                  _buildListTile(LucideIcons.info, 'About QuickBite', 'Privacy policy and Terms', theme),

                  const SizedBox(height: 32),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(LucideIcons.logOut, color: Colors.redAccent),
                      label: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 100), // Bottom nav padding
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, IconData icon, String label, Color color) {
    return Expanded(
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
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, color: Colors.grey.shade800),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.grey.shade700, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        trailing: Icon(LucideIcons.chevronRight, size: 20, color: Colors.grey.shade400),
        onTap: () {},
      ),
    ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.05, end: 0);
  }
}
