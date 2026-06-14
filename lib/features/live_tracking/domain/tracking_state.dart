import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'waypoint.dart';

export 'waypoint.dart';

enum GpsStatus { searching, poor, good, excellent }

class TrackingState {
  final bool isTracking;
  final bool isPermissionDenied;
  final List<LatLng> routePoints;
  final double distanceMeters;
  final double currentSpeedMs;
  final double maxSpeedMs;
  final int elapsedSeconds;
  final int movingSeconds;
  final double ascentMeters;
  final double? accuracy;
  final List<double> altitudePoints;
  final List<Waypoint> waypoints;

  const TrackingState({
    required this.isTracking,
    required this.routePoints,
    required this.distanceMeters,
    required this.currentSpeedMs,
    required this.maxSpeedMs,
    required this.elapsedSeconds,
    required this.movingSeconds,
    required this.ascentMeters,
    required this.accuracy,
    required this.altitudePoints,
    required this.waypoints,
    this.isPermissionDenied = false,
  });

  factory TrackingState.initial() => const TrackingState(
        isTracking: true,
        isPermissionDenied: false,
        routePoints: [],
        distanceMeters: 0,
        currentSpeedMs: 0,
        maxSpeedMs: 0,
        elapsedSeconds: 0,
        movingSeconds: 0,
        ascentMeters: 0,
        accuracy: null,
        altitudePoints: [],
        waypoints: [],
      );

  double get currentSpeedKmh => currentSpeedMs * 3.6;
  double get maxSpeedKmh => maxSpeedMs * 3.6;
  double get distanceKm => distanceMeters / 1000;

  double get avgMovingSpeedKmh {
    if (movingSeconds < 1) return 0;
    return (distanceMeters / movingSeconds) * 3.6;
  }

  String get elapsedFormatted {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get movingFormatted {
    final h = movingSeconds ~/ 3600;
    final m = (movingSeconds % 3600) ~/ 60;
    final s = movingSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  GpsStatus get gpsStatus {
    if (accuracy == null) return GpsStatus.searching;
    if (accuracy! > 20) return GpsStatus.poor;
    if (accuracy! > 8) return GpsStatus.good;
    return GpsStatus.excellent;
  }

  String get accuracyLabel {
    if (accuracy == null) return 'Searching…';
    return '±${accuracy!.toStringAsFixed(0)} m';
  }

  TrackingState copyWith({
    bool? isTracking,
    bool? isPermissionDenied,
    List<LatLng>? routePoints,
    double? distanceMeters,
    double? currentSpeedMs,
    double? maxSpeedMs,
    int? elapsedSeconds,
    int? movingSeconds,
    double? ascentMeters,
    double? accuracy,
    List<double>? altitudePoints,
    List<Waypoint>? waypoints,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      routePoints: routePoints ?? this.routePoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentSpeedMs: currentSpeedMs ?? this.currentSpeedMs,
      maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      ascentMeters: ascentMeters ?? this.ascentMeters,
      accuracy: accuracy ?? this.accuracy,
      altitudePoints: altitudePoints ?? this.altitudePoints,
      waypoints: waypoints ?? this.waypoints,
    );
  }
}
