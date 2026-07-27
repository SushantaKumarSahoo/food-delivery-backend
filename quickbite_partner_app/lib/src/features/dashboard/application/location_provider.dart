import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationState {
  final LatLng position;
  final bool isMock;
  final bool isLoading;
  final String? error;

  LocationState({
    required this.position,
    this.isMock = true,
    this.isLoading = false,
    this.error,
  });

  LocationState copyWith({
    LatLng? position,
    bool? isMock,
    bool? isLoading,
    String? error,
  }) {
    return LocationState(
      position: position ?? this.position,
      isMock: isMock ?? this.isMock,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class LocationController extends Notifier<LocationState> {
  @override
  LocationState build() {
    Future.microtask(() => determinePosition());
    return LocationState(
      position: const LatLng(12.9716, 77.5946), // Bengaluru (Bangalore) center fallback
      isMock: true,
      isLoading: true,
    );
  }

  Future<void> determinePosition() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoading: false,
          isMock: true,
          error: 'Location services are disabled.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLoading: false,
            isMock: true,
            error: 'Location permissions are denied.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          isMock: true,
          error: 'Location permissions are permanently denied.',
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      
      state = LocationState(
        position: LatLng(position.latitude, position.longitude),
        isMock: false,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isMock: true,
        error: e.toString(),
      );
    }
  }
}

final locationProvider = NotifierProvider<LocationController, LocationState>(() {
  return LocationController();
});
