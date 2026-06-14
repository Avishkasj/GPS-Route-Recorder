import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../live_tracking/domain/tracking_state.dart';

class SavedTrip {
  final String id;
  final DateTime date;
  final String name;
  final double distanceMeters;
  final int elapsedSeconds;
  final int movingSeconds;
  final double maxSpeedMs;
  final double ascentMeters;
  final List<LatLng> routePoints;
  final List<double> altitudePoints;
  final List<Waypoint> waypoints;

  const SavedTrip({
    required this.id,
    required this.date,
    required this.name,
    required this.distanceMeters,
    required this.elapsedSeconds,
    required this.movingSeconds,
    required this.maxSpeedMs,
    required this.ascentMeters,
    required this.routePoints,
    required this.altitudePoints,
    required this.waypoints,
  });

  double get distanceKm => distanceMeters / 1000;
  double get maxSpeedKmh => maxSpeedMs * 3.6;

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

  // Short h:mm label for list tiles
  String get durationHM {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  TrackingState toTrackingState() => TrackingState(
        isTracking: false,
        routePoints: routePoints,
        distanceMeters: distanceMeters,
        currentSpeedMs: 0,
        maxSpeedMs: maxSpeedMs,
        elapsedSeconds: elapsedSeconds,
        movingSeconds: movingSeconds,
        ascentMeters: ascentMeters,
        accuracy: null,
        altitudePoints: altitudePoints,
        waypoints: waypoints,
      );

  factory SavedTrip.fromTrackingState(TrackingState state) {
    final now = DateTime.now();
    final avgSpeed = state.movingSeconds > 0
        ? (state.distanceMeters / state.movingSeconds) * 3.6
        : 0.0;

    return SavedTrip(
      id: now.millisecondsSinceEpoch.toString(),
      date: now,
      name: _autoName(now, avgSpeed),
      distanceMeters: state.distanceMeters,
      elapsedSeconds: state.elapsedSeconds,
      movingSeconds: state.movingSeconds,
      maxSpeedMs: state.maxSpeedMs,
      ascentMeters: state.ascentMeters,
      routePoints: _downsample(state.routePoints, 300),
      altitudePoints: _downsampleDoubles(state.altitudePoints, 300),
      waypoints: state.waypoints,
    );
  }

  static String _autoName(DateTime date, double avgSpeedKmh) {
    final hour = date.hour;
    final time = hour >= 5 && hour < 12
        ? 'Morning'
        : hour >= 12 && hour < 17
            ? 'Afternoon'
            : hour >= 17 && hour < 21
                ? 'Evening'
                : 'Night';
    final activity = avgSpeedKmh > 15
        ? 'Bike Ride'
        : avgSpeedKmh > 7
            ? 'Run'
            : 'Walk';
    return '$time $activity';
  }

  static List<LatLng> _downsample(List<LatLng> pts, int max) {
    if (pts.length <= max) return pts;
    final step = pts.length / max;
    return List.generate(max, (i) => pts[(i * step).floor()]);
  }

  static List<double> _downsampleDoubles(List<double> vals, int max) {
    if (vals.length <= max) return vals;
    final step = vals.length / max;
    return List.generate(max, (i) => vals[(i * step).floor()]);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'name': name,
        'distanceMeters': distanceMeters,
        'elapsedSeconds': elapsedSeconds,
        'movingSeconds': movingSeconds,
        'maxSpeedMs': maxSpeedMs,
        'ascentMeters': ascentMeters,
        'routePoints': routePoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'altitudePoints': altitudePoints,
        'waypoints': waypoints.map((w) => w.toJson()).toList(),
      };

  factory SavedTrip.fromJson(Map<String, dynamic> json) => SavedTrip(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        name: json['name'] as String,
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        elapsedSeconds: json['elapsedSeconds'] as int,
        movingSeconds: json['movingSeconds'] as int,
        maxSpeedMs: (json['maxSpeedMs'] as num).toDouble(),
        ascentMeters: (json['ascentMeters'] as num).toDouble(),
        routePoints: (json['routePoints'] as List)
            .map((p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ))
            .toList(),
        altitudePoints: (json['altitudePoints'] as List)
            .map((v) => (v as num).toDouble())
            .toList(),
        waypoints: (json['waypoints'] as List? ?? [])
            .map((w) => Waypoint.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}
