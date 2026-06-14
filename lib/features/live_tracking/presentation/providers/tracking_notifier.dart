import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/tracking_state.dart';

class TrackingNotifier extends StateNotifier<TrackingState> {
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  double? _lastAltitude;
  bool _disposed = false;

  TrackingNotifier() : super(TrackingState.initial()) {
    _init();
  }

  Future<void> _init() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        state = state.copyWith(isTracking: false, isPermissionDenied: true);
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (_disposed) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        state = state.copyWith(isTracking: false, isPermissionDenied: true);
      }
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(
      _onPosition,
      onError: (Object e) => debugPrint('[Tracking] stream error: $e'),
    );
  }

  void _onTick(Timer _) {
    if (!mounted || !state.isTracking) return;
    final isMoving = state.currentSpeedMs > 0.5;
    state = state.copyWith(
      elapsedSeconds: state.elapsedSeconds + 1,
      movingSeconds: isMoving ? state.movingSeconds + 1 : state.movingSeconds,
    );
  }

  void _onPosition(Position position) {
    if (!mounted || !state.isTracking) return;

    final newPoint = LatLng(position.latitude, position.longitude);

    final List<LatLng> updatedPoints;
    final List<double> updatedAltitudes;
    double addedDistance = 0;
    List<Waypoint> updatedWaypoints = state.waypoints;

    if (position.accuracy <= 25) {
      updatedPoints = [...state.routePoints, newPoint];
      updatedAltitudes = [...state.altitudePoints, position.altitude];
      if (state.routePoints.isNotEmpty) {
        final last = state.routePoints.last;
        addedDistance = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
      }

      // Auto km-marker waypoints
      final prevKm = state.distanceMeters ~/ 1000;
      final newKm = (state.distanceMeters + addedDistance) ~/ 1000;
      if (newKm > prevKm) {
        for (int km = prevKm + 1; km <= newKm; km++) {
          updatedWaypoints = [
            ...updatedWaypoints,
            Waypoint(
              id: 'km_${km}_${DateTime.now().millisecondsSinceEpoch}',
              name: 'KM $km',
              position: newPoint,
              elevation: position.altitude,
              distanceKm: km.toDouble(),
              elapsedSeconds: state.elapsedSeconds,
            ),
          ];
        }
      }
    } else {
      updatedPoints = state.routePoints;
      updatedAltitudes = state.altitudePoints;
    }

    double addedAscent = 0;
    if (_lastAltitude != null) {
      final diff = position.altitude - _lastAltitude!;
      if (diff > 1.0) addedAscent = diff;
    }
    _lastAltitude = position.altitude;

    final speed = position.speed < 0 ? 0.0 : position.speed;
    final newMaxSpeed = speed > state.maxSpeedMs ? speed : state.maxSpeedMs;

    state = state.copyWith(
      routePoints: updatedPoints,
      altitudePoints: updatedAltitudes,
      distanceMeters: state.distanceMeters + addedDistance,
      currentSpeedMs: speed,
      maxSpeedMs: newMaxSpeed,
      ascentMeters: state.ascentMeters + addedAscent,
      accuracy: position.accuracy,
      waypoints: updatedWaypoints,
    );
  }

  void addWaypoint(LatLng position, {required String name, double? elevation}) {
    if (!mounted || !state.isTracking) return;
    final w = Waypoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      position: position,
      elevation: elevation,
      distanceKm: state.distanceKm,
      elapsedSeconds: state.elapsedSeconds,
    );
    state = state.copyWith(waypoints: [...state.waypoints, w]);
  }

  void stopRecording() {
    _timer?.cancel();
    _positionSub?.cancel();
    if (mounted) state = state.copyWith(isTracking: false);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}

final trackingProvider =
    StateNotifierProvider.autoDispose<TrackingNotifier, TrackingState>(
  (ref) => TrackingNotifier(),
);
