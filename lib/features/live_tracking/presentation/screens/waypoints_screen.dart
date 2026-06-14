import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/tracking_state.dart';
import '../providers/tracking_notifier.dart';

class WaypointsScreen extends ConsumerStatefulWidget {
  const WaypointsScreen({super.key});

  @override
  ConsumerState<WaypointsScreen> createState() => _WaypointsScreenState();
}

class _WaypointsScreenState extends ConsumerState<WaypointsScreen> {
  GoogleMapController? _mapController;
  LatLng? _mapCenter;
  Waypoint? _selectedWaypoint;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  LatLng _initialCenter(TrackingState state) {
    if (state.routePoints.isNotEmpty) return state.routePoints.last;
    return const LatLng(6.9271, 79.8612);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingProvider);

    final center = _mapCenter ?? _initialCenter(state);
    final currentElevation = state.altitudePoints.isNotEmpty
        ? state.altitudePoints.last
        : null;

    final displayed = _selectedWaypoint ??
        (state.waypoints.isNotEmpty ? state.waypoints.last : null);

    final markers = state.waypoints
        .map((w) => Marker(
              markerId: MarkerId(w.id),
              position: w.position,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: w.name),
              onTap: () => setState(() => _selectedWaypoint = w),
            ))
        .toSet();

    final polylines = state.routePoints.length >= 2
        ? <Polyline>{
            Polyline(
              polylineId: const PolylineId('route'),
              points: state.routePoints,
              color: const Color(0xFF2563EB),
              width: 4,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          }
        : <Polyline>{};

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    const Expanded(
                      child: Text(
                        'Waypoints',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          '${state.waypoints.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            // ── Map + overlaid cards ─────────────────────────
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: _initialCenter(state), zoom: 16),
                    onMapCreated: (c) => _mapController = c,
                    onCameraMove: (pos) =>
                        setState(() => _mapCenter = pos.target),
                    markers: markers,
                    polylines: polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: true,
                  ),

                  // Crosshair
                  const IgnorePointer(
                    child: Center(
                      child: Icon(Icons.add, size: 42),
                    ),
                  ),

                  // Latest/selected waypoint detail card
                  if (displayed != null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: _WaypointDetailCard(waypoint: displayed),
                    ),

                  // Drop-at-crosshair card
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: _DropCard(
                      center: center,
                      elevation: currentElevation,
                      onDrop: () => _drop(state),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _drop(TrackingState state) async {
    final count = state.waypoints.length + 1;
    final ctrl =
        TextEditingController(text: 'Waypoint $count');

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this waypoint'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Summit viewpoint'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    final elevation = ref.read(trackingProvider).altitudePoints.isNotEmpty
        ? ref.read(trackingProvider).altitudePoints.last
        : null;

    ref.read(trackingProvider.notifier).addWaypoint(
          _mapCenter ?? _initialCenter(state),
          name: name,
          elevation: elevation,
        );

    setState(() {
      _selectedWaypoint = ref.read(trackingProvider).waypoints.last;
    });
  }
}

// ─── Waypoint detail card ─────────────────────────────────────────────────────

class _WaypointDetailCard extends StatelessWidget {
  final Waypoint waypoint;
  const _WaypointDetailCard({required this.waypoint});

  @override
  Widget build(BuildContext context) {
    final lat = waypoint.position.latitude;
    final lng = waypoint.position.longitude;
    final latStr =
        '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}';
    final lngStr =
        '${lng.abs().toStringAsFixed(4)}° ${lng >= 0 ? 'E' : 'W'}';

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              waypoint.name,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('$latStr  •  $lngStr',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (waypoint.elevation != null)
                  Chip(
                    label: Text(
                        'ELEV ${waypoint.elevation!.toStringAsFixed(0)} m'),
                    padding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                Chip(
                  label: Text(
                      'KM ${waypoint.distanceKm.toStringAsFixed(2)}'),
                  padding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                Chip(
                  label: Text(waypoint.timeLabel),
                  padding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Drop-at-crosshair card ───────────────────────────────────────────────────

class _DropCard extends StatelessWidget {
  final LatLng center;
  final double? elevation;
  final VoidCallback onDrop;

  const _DropCard({
    required this.center,
    required this.elevation,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final lat = center.latitude;
    final lng = center.longitude;

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Drop at crosshair',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'MOVE MAP TO AIM',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 20),
            _coordRow(
              'Lat',
              lat.abs().toStringAsFixed(4),
              lat >= 0 ? '°N' : '°S',
            ),
            const SizedBox(height: 12),
            _coordRow(
              'Lon',
              lng.abs().toStringAsFixed(4),
              lng >= 0 ? '°E' : '°W',
            ),
            const SizedBox(height: 12),
            _coordRow(
              'Elev',
              elevation != null
                  ? elevation!.toStringAsFixed(0)
                  : '—',
              'm',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onDrop,
                icon: const Icon(Icons.place),
                label: const Text(
                  'Drop waypoint',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _coordRow(String label, String value, String unit) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label,
              style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        Text(unit,
            style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}
