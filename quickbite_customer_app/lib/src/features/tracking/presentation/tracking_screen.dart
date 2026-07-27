import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../support/dispute_screen.dart';

// ─── REST order provider ──────────────────────────────────────────────────────

final orderTrackingProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, orderId) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final response = await dio.get('${ApiConfig.orders}/$orderId');
    if (response.statusCode == 200) return Map<String, dynamic>.from(response.data);
  } on DioException catch (_) {}
  return {};
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class TrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const TrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  io.Socket? _socket;
  LatLng? _riderLoc;
  String _currentStatus = 'confirmed';
  int _etaMinutes = 15;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  Future<void> _connectSocket() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    if (token == null) return;

    // Derive WebSocket base from delivery service port
    final wsBase = ApiConfig.deliveryWsUrl;

    _socket = io.io(
      wsBase,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/delivery/socket.io')
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('track_order', {
        'orderId': widget.orderId,
        'token': token,
      });
    });

    _socket!.on('rider_location', (data) {
      if (!mounted) return;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() => _riderLoc = LatLng(lat, lng));
        _mapController.move(LatLng(lat, lng), 14.0);
      }
    });

    _socket!.on('order_status', (data) {
      if (!mounted) return;
      setState(() {
        _currentStatus = data['status']?.toString() ?? _currentStatus;
        _etaMinutes = (data['estimatedMinutes'] as num?)?.toInt() ?? _etaMinutes;
      });
    });

    _socket!.onDisconnect((_) => debugPrint('Tracking socket disconnected'));
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderAsync = ref.watch(orderTrackingProvider(widget.orderId));

    return orderAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => _buildView(context, theme, {}),
      data: (order) {
        // Sync initial status and ETA from REST
        final apiStatus = (order['status'] ?? '').toString().toLowerCase();
        if (apiStatus.isNotEmpty && _currentStatus == 'confirmed') {
          _currentStatus = apiStatus;
        }
        final apiEta = order['estimatedDeliveryMinutes'] as int?;
        if (apiEta != null && _etaMinutes == 15) _etaMinutes = apiEta;
        return _buildView(context, theme, order);
      },
    );
  }

  Widget _buildView(BuildContext context, ThemeData theme, Map<String, dynamic> order) {
    final delivery = order['deliveryDetails'] as Map<String, dynamic>?;
    final storeLat = ((order['store'] as Map?)?['latitude'] as num?)?.toDouble() ?? 20.3012;
    final storeLng = ((order['store'] as Map?)?['longitude'] as num?)?.toDouble() ?? 85.8201;
    final destLat = ((order['deliveryAddress'] as Map?)?['latitude'] as num?)?.toDouble();
    final destLng = ((order['deliveryAddress'] as Map?)?['longitude'] as num?)?.toDouble();

    final restaurantLoc = LatLng(storeLat, storeLng);
    // Use live WebSocket location if available, else fall back to REST delivery details
    final initRiderLat = (delivery?['currentLat'] as num?)?.toDouble();
    final initRiderLng = (delivery?['currentLng'] as num?)?.toDouble();
    final riderLoc = _riderLoc ??
        (initRiderLat != null ? LatLng(initRiderLat, initRiderLng!) : LatLng(storeLat + 0.024, storeLng - 0.003));
    final customerLoc = destLat != null ? LatLng(destLat, destLng!) : LatLng(storeLat + 0.053, storeLng - 0.005);

    final orderNumber = order['orderNumber'] ?? 'QB-${widget.orderId.substring(0, 6).toUpperCase()}';
    final riderName = delivery?['riderName'] ?? (order['rider'] as Map?)?['name'] ?? 'Delivery Partner';
    final riderRating = (delivery?['riderRating'] as num?)?.toStringAsFixed(1) ?? '4.8';
    final riderPhoto = delivery?['riderPhoto'] ?? (order['rider'] as Map?)?['photoUrl'];
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final stepStatuses = _getStepStatuses(_currentStatus);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.55,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: riderLoc, initialZoom: 13.5),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.quickbite.customer_app',
                ),
                PolylineLayer(polylines: [
                  Polyline(
                    points: [restaurantLoc, riderLoc, customerLoc],
                    strokeWidth: 4.5,
                    color: Colors.deepOrange,
                  ),
                ]),
                MarkerLayer(markers: [
                  _marker(restaurantLoc, Colors.redAccent, LucideIcons.utensilsCrossed, 50),
                  _marker(riderLoc, Colors.deepOrange, LucideIcons.bike, 60),
                  _marker(customerLoc, Colors.green, LucideIcons.home, 50),
                ]),
              ],
            ),
          ),

          // Live badge
          Positioned(
            top: 100,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                // Pulsing dot for live
                if (_riderLoc != null)
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 600.ms).then().fadeOut(duration: 600.ms),
                const Icon(LucideIcons.navigation, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Text(_statusLabel(_currentStatus),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            ),
          ),

          // Bottom panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.52,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, -10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order $orderNumber', style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Text('~$_etaMinutes mins',
                              style: theme.textTheme.displayLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16)),
                        child: Icon(LucideIcons.clock, color: theme.colorScheme.primary, size: 28),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildStepper('Order Confirmed', isCompleted: stepStatuses[0], theme: theme, delay: 300),
                  _buildStepper('Food Preparing', isCompleted: stepStatuses[1], theme: theme, delay: 400),
                  _buildStepper('Out for Delivery', isCompleted: stepStatuses[2], theme: theme, isLast: true, delay: 500),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4))],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: riderPhoto != null ? NetworkImage(riderPhoto) : null,
                        child: riderPhoto == null ? const Icon(LucideIcons.user, size: 22) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(riderName,
                                style: theme.textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Delivery Partner • ★ $riderRating',
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
                        child: Icon(LucideIcons.phone, color: Colors.green.shade700, size: 18),
                      ),
                    ]),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: OutlinedButton.icon(
            icon: const Icon(LucideIcons.headphones, size: 18),
            label: const Text('Help with this order'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => DisputeScreen(orderId: widget.orderId, orderNumber: orderNumber, orderAmount: totalAmount),
            )),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
      ),
    );
  }

  Marker _marker(LatLng point, Color color, IconData icon, double size) => Marker(
        point: point, width: size, height: size,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)]),
          child: Icon(icon, color: Colors.white, size: size * 0.36),
        ),
      );

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'Order confirmed';
      case 'preparing': return 'Food being prepared';
      case 'ready': return 'Ready for pickup';
      case 'driver_assigned': return 'Rider assigned';
      case 'out_for_delivery': return 'Rider on the way 🔴 LIVE';
      case 'delivered': return 'Delivered ✓';
      default: return 'Tracking your order';
    }
  }

  List<bool> _getStepStatuses(String status) {
    const steps = ['confirmed', 'preparing', 'ready', 'driver_assigned', 'out_for_delivery', 'delivered'];
    final idx = steps.indexOf(status);
    return [idx >= 0, idx >= 2, idx >= 4];
  }

  Widget _buildStepper(String title, {required bool isCompleted, required ThemeData theme, bool isLast = false, required int delay}) {
    const Color electricLime = Color(0xFFA3E635);
    return IntrinsicHeight(
      child: Row(children: [
        Column(children: [
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: isCompleted ? electricLime : Colors.white,
              border: Border.all(color: isCompleted ? electricLime : Colors.grey.shade300, width: 3),
              shape: BoxShape.circle,
            ),
          ),
          if (!isLast) Expanded(child: Container(width: 2, color: isCompleted ? electricLime : Colors.grey.shade300)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(title, style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 15, fontWeight: FontWeight.bold,
              color: isCompleted ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
            )),
          ),
        ),
      ]).animate(delay: delay.ms).fadeIn(),
    );
  }
}
