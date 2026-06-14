import 'dart:math' show min, max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/router/routes.dart';
import '../../domain/tracking_state.dart';
import '../providers/completed_trip_provider.dart';

// ─── Brand colours ────────────────────────────────────────────────────────────

class AppColors {
  static const bg = Color(0xFFF4F3F1);
  static const card = Color(0xFFFAFAFA);
  static const border = Color(0xFFD9D9D9);
  static const cyan = Color(0xFF0EB5E8);
  static const green = Color(0xFF48B676);
  static const text = Color(0xFF1B1C1E);
  static const secondary = Color(0xFF8B8F96);
}

// ─── Reusable stat cell ───────────────────────────────────────────────────────

class StatCell extends StatelessWidget {
  final String title;
  final String value;
  final String unit;

  const StatCell({
    required this.title,
    required this.value,
    this.unit = '',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 3,
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                    color: AppColors.text,
                    height: .9,
                  ),
                ),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 6),
                    child: Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vertical divider helper ──────────────────────────────────────────────────

Widget _vDivider() => Container(width: 1, color: AppColors.border);

// ─── Screen ───────────────────────────────────────────────────────────────────

class TripStatisticsScreen extends ConsumerStatefulWidget {
  const TripStatisticsScreen({super.key});

  @override
  ConsumerState<TripStatisticsScreen> createState() =>
      _TripStatisticsScreenState();
}

class _TripStatisticsScreenState
    extends ConsumerState<TripStatisticsScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _focusOnWaypoint(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 16)),
    );
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
        48.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(completedTripProvider);

    if (trip == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.trips);
      });
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Overall avg speed (distance / total elapsed)
    final avgSpeedKmh = trip.elapsedSeconds > 0
        ? trip.distanceKm / (trip.elapsedSeconds / 3600.0)
        : 0.0;

    final waypointMarkers = trip.waypoints
        .map((w) => Marker(
              markerId: MarkerId('wp_${w.id}'),
              position: w.position,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: w.name),
            ))
        .toSet();

    final polylines = trip.routePoints.length >= 2
        ? <Polyline>{
            Polyline(
              polylineId: const PolylineId('route'),
              points: trip.routePoints,
              color: AppColors.cyan,
              width: 4,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          }
        : <Polyline>{};

    final initialCamera = trip.routePoints.isNotEmpty
        ? CameraPosition(target: trip.routePoints.first, zoom: 14)
        : const CameraPosition(
            target: LatLng(6.9271, 79.8612), zoom: 14);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────
              _Header(onBack: () => context.go(Routes.trips)),
              const SizedBox(height: 20),

              // ── Map card ──────────────────────────────────────
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: trip.routePoints.isNotEmpty
                      ? GoogleMap(
                          initialCameraPosition: initialCamera,
                          polylines: polylines,
                          markers: waypointMarkers,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          compassEnabled: false,
                          scrollGesturesEnabled: true,
                          zoomGesturesEnabled: true,
                          onMapCreated: (c) {
                            _mapController = c;
                            Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                              if (mounted) _fitRoute(trip.routePoints);
                            });
                          },
                        )
                      : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map_outlined,
                                  size: 52,
                                  color: AppColors.secondary),
                              SizedBox(height: 8),
                              Text('No route recorded',
                                  style: TextStyle(
                                      color: AppColors.secondary)),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Statistics grid ───────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Row 1: Distance · Duration · Moving
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 150,
                            child: StatCell(
                              title: 'DISTANCE',
                              value: trip.distanceKm.toStringAsFixed(2),
                              unit: 'km',
                            ),
                          ),
                        ),
                        _vDivider(),
                        Expanded(
                          child: SizedBox(
                            height: 150,
                            child: StatCell(
                              title: 'DURATION',
                              value: _compactDuration(
                                  trip.elapsedSeconds),
                            ),
                          ),
                        ),
                        _vDivider(),
                        Expanded(
                          child: SizedBox(
                            height: 150,
                            child: StatCell(
                              title: 'MOVING',
                              value: _compactDuration(
                                  trip.movingSeconds),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    // Row 2: Max Speed · Avg Speed · Avg Moving
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: StatCell(
                              title: 'MAX SPEED',
                              value: trip.maxSpeedKmh
                                  .toStringAsFixed(1),
                              unit: 'km/h',
                            ),
                          ),
                        ),
                        _vDivider(),
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: StatCell(
                              title: 'AVG SPEED',
                              value: avgSpeedKmh.toStringAsFixed(1),
                              unit: 'km/h',
                            ),
                          ),
                        ),
                        _vDivider(),
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: StatCell(
                              title: 'AVG MOVING',
                              value: trip.avgMovingSpeedKmh
                                  .toStringAsFixed(1),
                              unit: 'km/h',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Ascent stat ───────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: SizedBox(
                  height: 100,
                  child: StatCell(
                    title: 'ASCENT',
                    value: trip.ascentMeters.toStringAsFixed(0),
                    unit: 'm',
                  ),
                ),
              ),

              // ── Elevation section ─────────────────────────────
              if (trip.altitudePoints.length >= 2) ...[
                const SizedBox(height: 24),
                _ElevationSection(altitudes: trip.altitudePoints),
              ],

              // ── Waypoints section ─────────────────────────────
              if (trip.waypoints.isNotEmpty) ...[
                const SizedBox(height: 24),
                _WaypointsSection(
                  waypoints: trip.waypoints,
                  onWaypointTap: _focusOnWaypoint,
                ),
              ],

              // ── Follow back button ────────────────────────────
              if (trip.routePoints.length >= 2) ...[
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.go(Routes.followRoute),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.cyan,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.alt_route,
                            color: Colors.black, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Follow back',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Compact h:mm or mm:ss duration without leading zeros
String _compactDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: AppColors.text),
          ),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Statistics',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Elevation & slope section ────────────────────────────────────────────────

class _ElevationSection extends StatelessWidget {
  final List<double> altitudes;
  const _ElevationSection({required this.altitudes});

  @override
  Widget build(BuildContext context) {
    final minAlt = altitudes.reduce(min);
    final maxAlt = altitudes.reduce(max);
    final range = (maxAlt - minAlt).abs();
    final padding = range < 1 ? 5.0 : range * 0.08;

    final spots = altitudes
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          const Row(
            children: [
              Text(
                'ELEVATION',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 3,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '↓ ${minAlt.toStringAsFixed(0)} m',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.secondary),
              ),
              Text(
                '↑ ${maxAlt.toStringAsFixed(0)} m',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minY: minAlt - padding,
                maxY: maxAlt + padding,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.cyan,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.cyan.withValues(alpha: 0.12),
                    ),
                    spots: spots,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Waypoints section ────────────────────────────────────────────────────────

class _WaypointsSection extends StatelessWidget {
  final List<Waypoint> waypoints;
  final void Function(LatLng) onWaypointTap;

  const _WaypointsSection({
    required this.waypoints,
    required this.onWaypointTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Text(
                  'WAYPOINTS',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 3,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${waypoints.length}',
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...waypoints.asMap().entries.map((entry) =>
              _WaypointRow(
                waypoint: entry.value,
                index: entry.key,
                isLast: entry.key == waypoints.length - 1,
                onTap: () => onWaypointTap(entry.value.position),
              )),
        ],
      ),
    );
  }
}

class _WaypointRow extends StatelessWidget {
  final Waypoint waypoint;
  final int index;
  final bool isLast;
  final VoidCallback onTap;

  const _WaypointRow({
    required this.waypoint,
    required this.index,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waypoint.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${waypoint.distanceKm.toStringAsFixed(2)} km  ·  ${waypoint.timeLabel}',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (waypoint.elevation != null)
              Text(
                '${waypoint.elevation!.toStringAsFixed(0)} m',
                style: const TextStyle(
                    color: AppColors.secondary, fontSize: 12),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.border, size: 18),
          ],
        ),
      ),
    );
  }
}
