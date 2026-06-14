import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/router/routes.dart';
import '../../domain/tracking_state.dart';
import '../providers/completed_trip_provider.dart';

typedef _Target = ({String label, LatLng position});

class FollowRouteScreen extends ConsumerStatefulWidget {
  const FollowRouteScreen({super.key});

  @override
  ConsumerState<FollowRouteScreen> createState() => _FollowRouteScreenState();
}

class _FollowRouteScreenState extends ConsumerState<FollowRouteScreen> {
  static const _arrivalRadius = 50.0; // metres

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;
  Position? _currentPosition;
  int _targetIndex = 0;
  late final List<_Target> _targets;

  @override
  void initState() {
    super.initState();
    final trip = ref.read(completedTripProvider);
    _targets = _buildTargets(trip);
    _startTracking();
  }

  static List<_Target> _buildTargets(TrackingState? trip) {
    if (trip == null) return [];
    final result = <_Target>[];
    for (final w in trip.waypoints.reversed) {
      result.add((label: w.name, position: w.position));
    }
    if (trip.routePoints.isNotEmpty) {
      result.add((label: 'Start', position: trip.routePoints.first));
    }
    return result;
  }

  Future<void> _startTracking() async {
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
      _checkArrival(pos);
    });
  }

  void _checkArrival(Position pos) {
    if (_targetIndex >= _targets.length) return;
    final target = _targets[_targetIndex];
    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      target.position.latitude,
      target.position.longitude,
    );
    if (dist <= _arrivalRadius) {
      setState(() => _targetIndex++);
    }
  }

  void _fitRoute(List<LatLng> points) {
    if (points.length < 2 || _mapController == null) return;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60.0,
      ),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(completedTripProvider);

    if (trip == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.trips);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isComplete = _targetIndex >= _targets.length;
    final currentTarget = isComplete ? null : _targets[_targetIndex];

    String distLabel = '';
    if (_currentPosition != null && currentTarget != null) {
      final dist = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        currentTarget.position.latitude,
        currentTarget.position.longitude,
      );
      distLabel = dist < 1000
          ? '${dist.toStringAsFixed(0)} m away'
          : '${(dist / 1000).toStringAsFixed(1)} km away';
    }

    // Build markers: reached=green, current=orange, future=azure
    final markers = <Marker>{};
    for (int i = 0; i < _targets.length; i++) {
      final t = _targets[i];
      final reached = i < _targetIndex;
      final isCurrent = i == _targetIndex;
      markers.add(Marker(
        markerId: MarkerId('target_$i'),
        position: t.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          reached
              ? BitmapDescriptor.hueGreen
              : isCurrent
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(title: t.label),
      ));
    }

    final polylines = trip.routePoints.length >= 2
        ? <Polyline>{
            Polyline(
              polylineId: const PolylineId('route'),
              points: trip.routePoints,
              color: const Color(0xFF9CA3AF),
              width: 4,
              patterns: [PatternItem.dash(16), PatternItem.gap(8)],
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          }
        : <Polyline>{};

    final initialCamera = CameraPosition(
      target: trip.routePoints.isNotEmpty
          ? trip.routePoints.last
          : const LatLng(6.9271, 79.8612),
      zoom: 14,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go(Routes.tripStatistics),
                      icon:
                          const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    const Expanded(
                      child: Text(
                        'Follow Route Back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isComplete
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isComplete
                            ? 'Done!'
                            : '$_targetIndex / ${_targets.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            // ── Map ─────────────────────────────────────────────
            Expanded(
              child: GoogleMap(
                initialCameraPosition: initialCamera,
                onMapCreated: (c) {
                  _mapController = c;
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _fitRoute(trip.routePoints);
                  });
                },
                markers: markers,
                polylines: polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
              ),
            ),

            // ── Bottom panel ────────────────────────────────────
            Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress strip
                  if (_targets.isNotEmpty)
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _targets.length,
                        itemBuilder: (_, i) => _ProgressChip(
                          label: _targets[i].label,
                          reached: i < _targetIndex,
                          isCurrent: i == _targetIndex,
                        ),
                      ),
                    ),

                  const Divider(height: 1),

                  // Next waypoint row
                  if (!isComplete && currentTarget != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.navigation_outlined,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentTarget.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                if (distLabel.isNotEmpty)
                                  Text(
                                    distLabel,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () =>
                                setState(() => _targetIndex++),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Reached'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Completion row
                  if (isComplete)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.flag_rounded,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'You made it back!',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                context.go(Routes.tripStatistics),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progress chip ────────────────────────────────────────────────────────────

class _ProgressChip extends StatelessWidget {
  final String label;
  final bool reached;
  final bool isCurrent;

  const _ProgressChip({
    required this.label,
    required this.reached,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: reached
            ? const Color(0xFF10B981)
            : isCurrent
                ? const Color(0xFF2563EB)
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reached
                ? Icons.check_circle
                : isCurrent
                    ? Icons.radio_button_on
                    : Icons.radio_button_off,
            size: 13,
            color: reached || isCurrent ? Colors.white : Colors.grey.shade400,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: reached || isCurrent
                  ? Colors.white
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
