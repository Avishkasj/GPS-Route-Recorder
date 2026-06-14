import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/router/routes.dart';
import '../../domain/tracking_state.dart';
import '../providers/completed_trip_provider.dart';
import '../providers/tracking_notifier.dart';
import '../../../trip_history/domain/saved_trip.dart';
import '../../../trip_history/presentation/providers/trip_history_provider.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late final AnimationController _blinkCtrl;

  MapType _mapType = MapType.normal;
  bool _showLayerPanel = false;
  bool _isFollowing = true;
  bool _isProgrammaticMove = false;

  static const _fallbackCamera = CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 16,
  );

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;

    final pts = ref.read(trackingProvider).routePoints;
    if (pts.isNotEmpty) {
      controller.moveCamera(CameraUpdate.newLatLng(pts.last));
      return;
    }

    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        controller.moveCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
        );
      }
    } catch (_) {}
  }

  void _onCameraMoveStarted() {
    if (_showLayerPanel) setState(() => _showLayerPanel = false);
    if (!_isProgrammaticMove) setState(() => _isFollowing = false);
  }

  void _onCameraIdle() {
    _isProgrammaticMove = false;
  }

  void _recenterMap() {
    final pts = ref.read(trackingProvider).routePoints;
    final target = pts.isNotEmpty ? pts.last : null;
    if (target != null) {
      _isProgrammaticMove = true;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16),
        ),
      );
    }
    setState(() => _isFollowing = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingProvider);

    ref.listen<LatLng?>(
      trackingProvider.select(
          (s) => s.routePoints.isNotEmpty ? s.routePoints.last : null),
      (_, next) {
        if (next != null && _isFollowing) {
          _isProgrammaticMove = true;
          _mapController?.animateCamera(CameraUpdate.newLatLng(next));
        }
      },
    );

    ref.listen<bool>(
      trackingProvider.select((s) => s.isTracking),
      (prev, next) {
        if (prev == true && next == false) {
          final finalState = ref.read(trackingProvider);
          ref.read(completedTripProvider.notifier).state = finalState;
          // Persist trip to local storage (fire-and-forget)
          ref
              .read(tripHistoryProvider.notifier)
              .saveTrip(SavedTrip.fromTrackingState(finalState));
          context.go(Routes.tripStatistics);
        }
      },
    );

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
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FadeTransition(
                        opacity: _blinkCtrl,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'REC',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        state.elapsedFormatted,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _GpsChip(state: state),
                ],
              ),
            ),

            // ── Permission denied banner ─────────────────────
            if (state.isPermissionDenied)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off,
                        color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Location access is required to record routes.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                      child: const Text('Settings',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // ── Map with overlaid controls ───────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: _fallbackCamera,
                        onMapCreated: _onMapCreated,
                        polylines: polylines,
                        mapType: _mapType,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: true,
                        onCameraMoveStarted: _onCameraMoveStarted,
                        onCameraIdle: _onCameraIdle,
                      ),

                      // Layer panel (shown above the layer button)
                      if (_showLayerPanel)
                        Positioned(
                          top: 12,
                          right: 56,
                          child: _LayerPanel(
                            current: _mapType,
                            onChanged: (type) => setState(() {
                              _mapType = type;
                              _showLayerPanel = false;
                            }),
                          ),
                        ),

                      // Layers button — top right
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _MapControlButton(
                          icon: Icons.layers,
                          active: _showLayerPanel,
                          onTap: () => setState(
                              () => _showLayerPanel = !_showLayerPanel),
                        ),
                      ),

                      // Recenter / my-location button — below layers button
                      Positioned(
                        top: 60,
                        right: 12,
                        child: _MapControlButton(
                          icon: _isFollowing
                              ? Icons.my_location
                              : Icons.location_searching,
                          active: _isFollowing,
                          onTap: _recenterMap,
                        ),
                      ),

                      // Waypoints button — bottom left
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: _WaypointsFab(
                          count: state.waypoints.length,
                          onTap: () => context.push(Routes.waypoints),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Stats — fixed-height horizontal list ─────────
            SizedBox(
              height: 108,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _StatCard(
                    title: 'Distance',
                    value: state.distanceKm.toStringAsFixed(2),
                    unit: 'km',
                    icon: Icons.route,
                  ),
                  _StatCard(
                    title: 'Speed',
                    value: state.currentSpeedKmh.toStringAsFixed(1),
                    unit: 'km/h',
                    icon: Icons.speed,
                  ),
                  _StatCard(
                    title: 'Moving',
                    value: state.movingFormatted,
                    unit: '',
                    icon: Icons.timer,
                  ),
                  _StatCard(
                    title: 'Avg',
                    value: state.avgMovingSpeedKmh.toStringAsFixed(1),
                    unit: 'km/h',
                    icon: Icons.trending_up,
                  ),
                  _StatCard(
                    title: 'Ascent',
                    value: state.ascentMeters.toStringAsFixed(0),
                    unit: 'm',
                    icon: Icons.terrain,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Stop / Back button ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: state.isPermissionDenied
                    ? ElevatedButton.icon(
                        onPressed: () => context.go(Routes.trips),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text(
                          'Back to Trips',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () =>
                            ref.read(trackingProvider.notifier).stopRecording(),
                        icon: const Icon(Icons.stop),
                        label: const Text(
                          'Stop Recording',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Waypoints FAB ───────────────────────────────────────────────────────────

class _WaypointsFab extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _WaypointsFab({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place, size: 18, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              count > 0 ? 'Waypoints ($count)' : 'Waypoints',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Map control button ───────────────────────────────────────────────────────

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

// ─── Layer selection panel ────────────────────────────────────────────────────

class _LayerPanel extends StatelessWidget {
  final MapType current;
  final ValueChanged<MapType> onChanged;

  const _LayerPanel({required this.current, required this.onChanged});

  static const _options = [
    (icon: Icons.map, label: 'Map', type: MapType.normal),
    (icon: Icons.satellite_alt, label: 'Satellite', type: MapType.satellite),
    (icon: Icons.layers, label: 'Hybrid', type: MapType.hybrid),
    (icon: Icons.terrain, label: 'Terrain', type: MapType.terrain),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _options
            .map((o) => _LayerOption(
                  icon: o.icon,
                  label: o.label,
                  selected: current == o.type,
                  onTap: () => onChanged(o.type),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Single layer row ─────────────────────────────────────────────────────────

class _LayerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LayerOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? blue : Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? blue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── GPS chip ─────────────────────────────────────────────────────────────────

class _GpsChip extends StatelessWidget {
  final TrackingState state;
  const _GpsChip({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isPermissionDenied) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off,
                size: 18, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(
              'Location denied',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
        ),
      );
    }

    final isGood = state.gpsStatus == GpsStatus.good ||
        state.gpsStatus == GpsStatus.excellent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGood ? Icons.gps_fixed : Icons.gps_not_fixed,
            size: 18,
            color: isGood ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text('GPS · ${state.accuracyLabel}'),
        ],
      ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const Spacer(),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
