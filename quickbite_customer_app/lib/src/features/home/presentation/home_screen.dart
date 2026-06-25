import 'package:flutter/material.dart';
import '../../../shared/widgets/animated_bottom_bar.dart';
import 'home_feed.dart';
import 'search_feed.dart';
import '../../cart/presentation/cart_feed.dart';
import '../../profile/presentation/profile_feed.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeFeed(),
    const SearchFeed(),
    const CartFeed(),
    const ProfileFeed(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows content to scroll under the transparent bottom bar
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: AnimatedBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
