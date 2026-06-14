import 'package:google_maps_flutter/google_maps_flutter.dart';

class Waypoint {
  final String id;
  final String name;
  final LatLng position;
  final double? elevation;
  final double distanceKm;
  final int elapsedSeconds;

  const Waypoint({
    required this.id,
    required this.name,
    required this.position,
    required this.distanceKm,
    required this.elapsedSeconds,
    this.elevation,
  });

  String get timeLabel {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': position.latitude,
        'lng': position.longitude,
        'elevation': elevation,
        'distanceKm': distanceKm,
        'elapsedSeconds': elapsedSeconds,
      };

  factory Waypoint.fromJson(Map<String, dynamic> json) => Waypoint(
        id: json['id'] as String,
        name: json['name'] as String,
        position: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        elevation: (json['elevation'] as num?)?.toDouble(),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        elapsedSeconds: json['elapsedSeconds'] as int,
      );
}
