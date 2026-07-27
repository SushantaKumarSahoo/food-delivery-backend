import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../dashboard/application/location_provider.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  final Map<String, dynamic> deliveryData;

  const ActiveDeliveryScreen({
    super.key,
    required this.deliveryData,
  });

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  String _status = 'accepted'; // accepted, picked_up, delivered
  LatLng? _restaurantPos;
  LatLng? _customerPos;

  void _initializeCoordinates(LatLng partnerPos) {
    if (_restaurantPos != null) return;
    // Generate logical positions nearby relative to the driver's location
    _restaurantPos = LatLng(partnerPos.latitude + 0.005, partnerPos.longitude + 0.006);
    _customerPos = LatLng(partnerPos.latitude + 0.012, partnerPos.longitude + 0.013);
  }

  Widget _buildMarkerIcon({required IconData icon, required Color color, required Color borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Center(
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  void _markPickedUp() {
    setState(() => _status = 'picked_up');
    // TODO: hit backend
  }

  void _markDelivered() {
    setState(() => _status = 'delivered');
    // TODO: hit backend
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery Completed! ₹40 earned.')));
    Navigator.pop(context); // Go back to dashboard
  }

  Future<void> _openGoogleMaps() async {
    final target = _status == 'accepted' ? _restaurantPos : _customerPos;
    if (target == null) return;

    final googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${target.latitude},${target.longitude}");
    final appleMapsUrl = Uri.parse("maps://?q=${target.latitude},${target.longitude}");
    
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUrl = Uri.parse("https://maps.google.com/?q=${target.latitude},${target.longitude}");
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps application: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPickedUp = _status == 'picked_up';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Active Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: const SizedBox.shrink(), // Cannot go back until finished
        actions: [
          IconButton(icon: const Icon(LucideIcons.phone, color: Colors.blue), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Real Map Routing View
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final locationState = ref.watch(locationProvider);
                final partnerPos = locationState.position;
                _initializeCoordinates(partnerPos);

                final currentTarget = _status == 'accepted' ? _restaurantPos! : _customerPos!;

                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: partnerPos,
                      initialZoom: 14.0,
                      minZoom: 3.0,
                      maxZoom: 19.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.quickbite.partner_app',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [partnerPos, currentTarget],
                            color: Colors.blue.shade600,
                            strokeWidth: 4.5,
                          ),
                          if (_status == 'accepted')
                            Polyline(
                              points: [_restaurantPos!, _customerPos!],
                              color: Colors.grey.shade500,
                              strokeWidth: 3.0,
                            ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          // Partner Location Marker
                          Marker(
                            point: partnerPos,
                            width: 40,
                            height: 40,
                            child: _buildMarkerIcon(
                              icon: LucideIcons.navigation,
                              color: Colors.blue.shade600,
                              borderColor: Colors.white,
                            ),
                          ),
                          // Restaurant/Pickup Marker
                          Marker(
                            point: _restaurantPos!,
                            width: 40,
                            height: 40,
                            child: _buildMarkerIcon(
                              icon: LucideIcons.store,
                              color: Colors.amber.shade800,
                              borderColor: Colors.white,
                            ),
                          ),
                          // Customer/Dropoff Marker
                          Marker(
                            point: _customerPos!,
                            width: 40,
                            height: 40,
                            child: _buildMarkerIcon(
                              icon: LucideIcons.user,
                              color: Colors.green.shade700,
                              borderColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ).animate().fade().slideY(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: (isPickedUp ? Colors.green : Colors.blue).withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(isPickedUp ? LucideIcons.user : LucideIcons.store, color: isPickedUp ? Colors.green : Colors.blue, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isPickedUp ? 'DELIVER TO' : 'PICKUP FROM', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                          Text(
                            isPickedUp ? (widget.deliveryData['customerName'] ?? 'Customer') : (widget.deliveryData['restaurantName'] ?? 'Restaurant'),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Order ${widget.deliveryData['orderNumber'] ?? '12345'}', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                OutlinedButton.icon(
                  onPressed: _openGoogleMaps,
                  icon: const Icon(LucideIcons.navigation, size: 24),
                  label: const Text('NAVIGATE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade200, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                ElevatedButton(
                  onPressed: isPickedUp ? _markDelivered : _markPickedUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPickedUp ? Colors.green.shade700 : Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: Text(
                    isPickedUp ? 'MARK DELIVERED' : 'MARK PICKED UP',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ).animate().fade(duration: 600.ms).slideY(begin: 0.5, end: 0, curve: Curves.easeOutCubic)
        ],
      ),
    );
  }
}
