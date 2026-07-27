import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import '../application/location_provider.dart';
import '../../delivery/presentation/active_delivery_screen.dart';
import '../../delivery/presentation/incoming_order_alert.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isOnline = false;
  final MapController _mapController = MapController();

  Widget _buildLocationMarker(bool isMock) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulsing ring
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue.withOpacity(0.4), width: 1),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.6, 1.6), duration: 1500.ms, curve: Curves.easeOut)
            .fade(begin: 1.0, end: 0.0, duration: 1500.ms),
        // Inner glowing circle
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 2,
              )
            ],
          ),
        ),
      ],
    );
  }

  void _toggleOnline() {
    setState(() {
      _isOnline = !_isOnline;
    });
    // TODO: Send online status to backend
    if (_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are now ONLINE. Searching for deliveries...'), backgroundColor: Colors.green),
      );
      
      // Simulate getting an order after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted || !_isOnline) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => IncomingOrderAlert(
              deliveryData: const {
                'restaurantName': 'Spice Garden',
                'fee': 65,
                'distance': 3.2,
                'orderNumber': 'QB-8839',
                'customerName': 'Sushanta Kumar',
              },
              onDecline: () {
                Navigator.pop(context);
                setState(() => _isOnline = false);
              },
              onAccept: () {
                Navigator.pop(context); // Close alert
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActiveDeliveryScreen(
                      deliveryData: {
                        'restaurantName': 'Spice Garden',
                        'fee': 65,
                        'distance': 3.2,
                        'orderNumber': 'QB-8839',
                        'customerName': 'Sushanta Kumar',
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Partner Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(LucideIcons.user), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          // Real Interactive Map Background
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, child) {
                final locationState = ref.watch(locationProvider);
                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: locationState.position,
                    initialZoom: 15.0,
                    minZoom: 3.0,
                    maxZoom: 19.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.quickbite.partner_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: locationState.position,
                          width: 60,
                          height: 60,
                          child: _buildLocationMarker(locationState.isMock),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Re-center Locator Button
          Positioned(
            top: 110,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'recenter_locator',
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              onPressed: () {
                final locationState = ref.read(locationProvider);
                _mapController.move(locationState.position, 15.0);
              },
              child: const Icon(LucideIcons.locate, size: 20),
            ).animate().fade(delay: 400.ms).slideX(begin: 0.5, end: 0),
          ),
          
          // Top Stats Bar
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    child: Column(
                      children: [
                        const Text('TODAY', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('₹0', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ).animate().fade(duration: 500.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    child: Column(
                      children: [
                        const Text('TRIPS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('0', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ).animate(delay: 200.ms).fade(duration: 500.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart),
                ),
              ],
            ),
          ),

          // Bottom Go Online Button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _toggleOnline,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOnline ? Colors.redAccent : Colors.greenAccent.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isOnline ? LucideIcons.powerOff : LucideIcons.power, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    _isOnline ? 'GO OFFLINE' : 'GO ONLINE',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ],
              ),
            )
            .animate(delay: 500.ms)
            .fade()
            .slideY(begin: 0.5, end: 0)
            .animate(target: _isOnline ? 0 : 1, onPlay: (c) => c.repeat(reverse: true))
            .shimmer(color: Colors.white, duration: 2000.ms),
          ),
        ],
      ),
    );
  }
}

