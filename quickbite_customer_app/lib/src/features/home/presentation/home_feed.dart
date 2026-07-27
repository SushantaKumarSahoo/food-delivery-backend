import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../restaurant/application/restaurant_provider.dart';
import '../../profile/application/user_provider.dart';
import '../../profile/data/user_repository.dart';
import '../application/banner_provider.dart';
import '../application/category_provider.dart';

class HomeFeed extends ConsumerStatefulWidget {
  const HomeFeed({super.key});

  @override
  ConsumerState<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends ConsumerState<HomeFeed> {
  int _calculateStreak(List<dynamic> orders) {
    if (orders.isEmpty) return 0;
    
    final sortedOrders = List.from(orders)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    Set<DateTime> orderDates = {};
    for (var o in sortedOrders) {
      final dateStr = o['createdAt']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          orderDates.add(DateTime(date.year, date.month, date.day));
        }
      }
    }
    
    int streak = 0;
    DateTime checkDate = today;
    
    if (!orderDates.contains(today)) {
      if (!orderDates.contains(today.subtract(const Duration(days: 1)))) {
        return 0;
      }
      checkDate = today.subtract(const Duration(days: 1));
    }
    
    while (orderDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restaurantsAsyncValue = ref.watch(restaurantsProvider);
    final walletAsyncValue = ref.watch(walletProvider);
    final bannersAsyncValue = ref.watch(bannersProvider);
    final categoriesAsyncValue = ref.watch(categoryProvider);

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
                Icon(
                  LucideIcons.mapPin,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Home',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.chevronDown, size: 16),
                      ],
                    ),
                    ref
                        .watch(userProfileProvider)
                        .when(
                          data: (profile) => Text(
                            'Welcome, ${profile.firstName}!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          loading: () => Text(
                            'Loading...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          error: (_, __) => Text(
                            'Home',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
            actions: [
              // Flame Badge (Active Orders / Streak) - Interactive
              GestureDetector(
                onTap: () => _showActiveOrdersModal(context, ref),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.flame,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      ref
                          .watch(userOrdersProvider)
                          .when(
                            data: (orders) {
                              final activeCount = orders
                                  .where(
                                    (o) =>
                                        o['status'] != 'delivered' &&
                                        o['status'] != 'cancelled',
                                  )
                                  .length;
                              final streakCount = _calculateStreak(orders);
                              final displayVal = activeCount > 0
                                  ? '$activeCount Active'
                                  : '$streakCount Streak';
                              return Text(
                                displayVal,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 13,
                                ),
                              );
                            },
                            loading: () => const Text(
                              '0',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            error: (_, __) => const Text(
                              '0',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),

              // Coins Badge (QuickBite Wallet) - Interactive
              GestureDetector(
                onTap: () =>
                    _showWalletQuickModal(context, walletAsyncValue.value ?? 0),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.coins,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      walletAsyncValue.when(
                        data: (coins) => Text(
                          '$coins',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        loading: () => const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, __) => const Text(
                          '0',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Notifications Bell - Interactive
              GestureDetector(
                onTap: () => _showNotificationsModal(context),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(LucideIcons.bell, size: 20),
                ),
              ),
            ],
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: GestureDetector(
                onTap: () => context.push('/search'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.search,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Search restaurants...',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            ),
          ),

          // Banners Section
          bannersAsyncValue.when(
            data: (apiBanners) {
              // Fallback to dummy data if DB is empty
              final banners = apiBanners.isEmpty ? [
                {
                  'title': 'Get 50% Off',
                  'subtitle': 'On your first order',
                  'imageUrl': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=1000&auto=format&fit=crop',
                },
                {
                  'title': 'Free Delivery',
                  'subtitle': 'For orders over \$20',
                  'imageUrl': 'https://images.unsplash.com/photo-1493770348161-369560ae357d?q=80&w=1000&auto=format&fit=crop',
                }
              ] : apiBanners;

              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: banners.length,
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(
                            image: NetworkImage(banner['imageUrl'] ?? ''),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner['title'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (banner['subtitle'] != null)
                                Text(
                                  banner['subtitle'],
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideX();
                    },
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Categories Section
          categoriesAsyncValue.when(
            data: (apiCategories) {
              // Fallback to dummy data if DB is empty
              final categories = apiCategories.isEmpty ? [
                {'name': 'Burgers', 'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=500&auto=format&fit=crop'},
                {'name': 'Pizza', 'imageUrl': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?q=80&w=500&auto=format&fit=crop'},
                {'name': 'Sushi', 'imageUrl': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=500&auto=format&fit=crop'},
                {'name': 'Healthy', 'imageUrl': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?q=80&w=500&auto=format&fit=crop'},
                {'name': 'Dessert', 'imageUrl': 'https://images.unsplash.com/photo-1551024506-0bccd828d307?q=80&w=500&auto=format&fit=crop'},
              ] : apiCategories;
              
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.surface,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                image: category['imageUrl'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(category['imageUrl']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: category['imageUrl'] == null
                                  ? Icon(LucideIcons.image, color: Colors.grey.shade400)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category['name'] ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).scale();
                    },
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Trending Header
          SliverToBoxAdapter(
            key: const ValueKey('header_restaurants'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top Restaurants',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'See All',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ).animate().fadeIn(),
            ),
          ),

          // Filtered Stores List
          restaurantsAsyncValue.when(
            data: (allRestaurants) {
              final filteredStores = allRestaurants.toList();

              // If filtered stores is empty or allRestaurants is empty
              if (filteredStores.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.grey.shade100,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.utensils,
                              size: 36,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Restaurants Nearby',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We\'re expanding fast! We haven\'t onboarded partners yet. Check back soon.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.invalidate(restaurantsProvider);
                            },
                            icon: const Icon(
                              LucideIcons.refreshCw,
                              size: 16,
                            ),
                            label: const Text('Refresh'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().scale(
                      begin: const Offset(0.95, 0.95),
                    ),
                  ),
                );
              }

              return SliverList(
                key: const ValueKey('list_restaurants'),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final store = filteredStores[index];

                          return GestureDetector(
                            onTap: () =>
                                context.push('/restaurant/${store.id}'),
                            child: Container(
                              margin: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                bottom: 20,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Hero(
                                    tag: 'restaurant_image_${store.id}',
                                    child: Stack(
                                      children: [
                                        Container(
                                          height: 160,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(24),
                                                ),
                                            color: Colors.grey.shade200,
                                            image: store.imageUrl != null
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                      store.imageUrl!,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: store.imageUrl == null
                                              ? const Center(
                                                  child: Icon(
                                                    LucideIcons.image,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        if (store.isSponsored)
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.75,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Sponsored',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                store.name,
                                                style: theme
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(fontSize: 18),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                store.tags.join(' • '),
                                                style:
                                                    theme.textTheme.bodyMedium,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                store.rating.toStringAsFixed(1),
                                                style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                LucideIcons.star,
                                                size: 14,
                                                color: Colors.green.shade700,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().slideY(begin: 0.1, end: 0).fadeIn(),
                          );
                        }, childCount: filteredStores.length),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (error, stack) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 36,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                LucideIcons.alertCircle,
                                size: 32,
                                color: Colors.red.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Unable to load restaurants right now',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please check your internet connection or backend service.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    ref.invalidate(restaurantsProvider),
                                icon: const Icon(
                                  LucideIcons.refreshCw,
                                  size: 16,
                                ),
                                label: const Text('Try Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }


  void _showActiveOrdersModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final ordersAsync = ref.watch(userOrdersProvider);

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Active Orders & Streak',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ordersAsync.when(
                data: (orders) {
                  final activeOrders = orders
                      .where(
                        (o) =>
                            o['status'] != 'delivered' &&
                            o['status'] != 'cancelled',
                      )
                      .toList();
                  if (activeOrders.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.flame,
                            color: Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_calculateStreak(orders)} Day Order Streak! 🔥',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Order today to keep your streak alive & earn 2x QuickCoins!',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: activeOrders
                        .map(
                          (o) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              LucideIcons.truck,
                              color: Colors.deepOrange,
                            ),
                            title: Text(
                              'Order #${o['orderNumber'] ?? 'QB-001'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Status: ${o['status'].toString().toUpperCase()}',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.push('/tracking/${o['id']}');
                              },
                              child: const Text('Track'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('No active orders'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWalletQuickModal(BuildContext context, int coins) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final liveCoins = ref.watch(walletProvider).value ?? coins;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'QuickCoins & Wallet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(LucideIcons.x),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Live QuickCoins Balance',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🪙 $liveCoins Coins',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: liveCoins < 25
                                ? null
                                : () async {
                                    final newCoins = await ref
                                        .read(userRepositoryProvider)
                                        .redeemWalletCoins(25);
                                    ref.invalidate(walletProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Redeemed 25 coins! Remaining: 🪙 $newCoins Coins',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.amber.shade900,
                            ),
                            child: const Text('Redeem 25'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Coins are earned automatically on every completed order.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNotificationsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Live Activity & Alerts',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const ListTile(
              leading: Icon(LucideIcons.bell, color: Colors.deepOrange),
              title: Text('Welcome to QuickBite! 🎉'),
              subtitle: Text(
                'Enjoy free delivery on your first 3 food orders.',
              ),
            ),
            const ListTile(
              leading: Icon(LucideIcons.percent, color: Colors.green),
              title: Text('50% OFF Weekend Deal 🔥'),
              subtitle: Text('Use code QUICKBITE50 on your next gourmet meal.'),
            ),
          ],
        ),
      ),
    );
  }
}
