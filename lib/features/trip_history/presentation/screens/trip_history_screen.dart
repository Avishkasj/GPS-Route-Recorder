import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../live_tracking/presentation/providers/completed_trip_provider.dart';
import '../../domain/saved_trip.dart';
import '../providers/trip_history_provider.dart';

// ─── Colour tokens ────────────────────────────────────────────────────────────

const _bg = Color(0xFFF4F3F1);
const _dark = Color(0xFF111418);
const _textPrimary = Color(0xFF1B1C1E);
const _textSection = Color(0xFF5E636A);
const _textDim = Color(0xFF7D838A);
const _textSubDim = Color(0xFF8A8F95);
const _border = Color(0xFFD9D9D9);
const _cyan = Color(0xFF11B5E7);
const _green = Color(0xFF53BE7A);
const _record = Color(0xFFEF6B4C);
const _navInactive = Color(0xFF8D9197);

// ─── Screen ───────────────────────────────────────────────────────────────────

class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripHistoryProvider);

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const _BottomBar(),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(tripHistoryProvider),
        ),
        data: (trips) => _TripHistoryBody(trips: trips),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _TripHistoryBody extends ConsumerWidget {
  final List<SavedTrip> trips;
  const _TripHistoryBody({required this.trips});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalKm = trips.fold(0.0, (s, t) => s + t.distanceKm);
    final totalSec = trips.fold(0, (s, t) => s + t.elapsedSeconds);
    final totalH = totalSec ~/ 3600;
    final totalM = (totalSec % 3600) ~/ 60;
    final totalTime = '$totalH:${totalM.toString().padLeft(2, '0')}';

    final sections = _buildSections(trips);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Trips',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
                _topButton(Icons.search),
                const SizedBox(width: 10),
                _topButton(Icons.map_outlined),
              ],
            ),

            const SizedBox(height: 20),

            // ── Summary card ──────────────────────────────────
            Container(
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: _dark,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      title: 'DIST.',
                      value: totalKm.toStringAsFixed(1),
                      unit: 'km',
                    ),
                  ),
                  _summaryDivider(),
                  Expanded(
                    child: _SummaryItem(
                      title: 'TRIPS',
                      value: '${trips.length}',
                      unit: '',
                    ),
                  ),
                  _summaryDivider(),
                  Expanded(
                    child: _SummaryItem(
                      title: 'TIME',
                      value: totalTime,
                      unit: 'h',
                      blue: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            if (trips.isEmpty)
              const _EmptyState()
            else
              // ── Grouped trip sections ─────────────────────
              ...sections.entries.expand((entry) {
                final label = entry.key;
                final sectionTrips = entry.value;
                return [
                  Text(
                    label,
                    style: const TextStyle(
                      letterSpacing: 3,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textSection,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      children: List.generate(
                        sectionTrips.length,
                        (i) => Column(
                          children: [
                            _TripTile(
                              trip: sectionTrips[i],
                              isFirst: i == 0,
                              isLast: i == sectionTrips.length - 1,
                              onTap: () =>
                                  _openTrip(context, ref, sectionTrips[i]),
                              onDelete: () => ref
                                  .read(tripHistoryProvider.notifier)
                                  .deleteTrip(sectionTrips[i].id),
                            ),
                            if (i < sectionTrips.length - 1)
                              const Divider(
                                height: 1,
                                indent: 20,
                                endIndent: 20,
                                color: _border,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ];
              }),
          ],
        ),
      ),
    );
  }

  void _openTrip(BuildContext context, WidgetRef ref, SavedTrip trip) {
    ref.read(completedTripProvider.notifier).state = trip.toTrackingState();
    context.go(Routes.tripStatistics);
  }

  static Widget _topButton(IconData icon) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, size: 22, color: _textPrimary),
    );
  }

  static Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 44,
      color: const Color(0xFF2A2F36),
    );
  }
}

// ─── Section grouping ─────────────────────────────────────────────────────────

Map<String, List<SavedTrip>> _buildSections(List<SavedTrip> trips) {
  final now = DateTime.now();
  const months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL',
    'MAY', 'JUNE', 'JULY', 'AUGUST',
    'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];
  final sections = <String, List<SavedTrip>>{};

  for (final trip in trips) {
    final diff = now.difference(trip.date);
    final String key;
    if (diff.inDays < 7) {
      key = 'THIS WEEK';
    } else if (trip.date.year == now.year) {
      key = months[trip.date.month - 1];
    } else {
      key = '${months[trip.date.month - 1]}  ·  ${trip.date.year}';
    }
    sections.putIfAbsent(key, () => []).add(trip);
  }

  return sections;
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final year = date.year == now.year ? '' : ' ${date.year}';
  return '${months[date.month - 1]} ${date.day}$year';
}

// ─── Summary item ─────────────────────────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final bool blue;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.unit,
    this.blue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                color: _textDim,
                letterSpacing: 2,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      color: blue ? _cyan : Colors.white,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        color: _textSubDim,
                        fontSize: 15,
                      ),
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

// ─── Trip tile ────────────────────────────────────────────────────────────────

class _TripTile extends StatelessWidget {
  final SavedTrip trip;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TripTile({
    required this.trip,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? 24 : 0),
      topRight: Radius.circular(isFirst ? 24 : 0),
      bottomLeft: Radius.circular(isLast ? 24 : 0),
      bottomRight: Radius.circular(isLast ? 24 : 0),
    );

    return Dismissible(
      key: Key(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline,
            color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete trip?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: _dark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.alt_route, color: _cyan, size: 28),
              ),
              const SizedBox(width: 16),
              // Trip info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(trip.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _navInactive,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textSection,
                        ),
                        children: [
                          TextSpan(
                              text: '${trip.distanceKm.toStringAsFixed(2)} km'),
                          const TextSpan(text: '  ·  '),
                          TextSpan(text: trip.durationHM),
                          const TextSpan(text: '  ·  '),
                          TextSpan(
                            text:
                                '↑ ${trip.ascentMeters.toStringAsFixed(0)} m',
                            style: const TextStyle(
                              color: _green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                size: 24,
                color: Color(0xFF9DA1A7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────

class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(
              Icons.map_outlined,
              'MAP',
              onTap: () {
                final trips = ref.read(tripHistoryProvider).value ?? [];
                if (trips.isNotEmpty) {
                  ref.read(completedTripProvider.notifier).state =
                      trips.first.toTrackingState();
                  context.go(Routes.tripStatistics);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No trips yet — record one first!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            _navItem(Icons.alt_route, 'TRIPS', active: true, onTap: () {}),
            // Record button
            GestureDetector(
              onTap: () => context.go(Routes.liveTracking),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _record,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.black,
                  ),
                ),
              ),
            ),
            _navItem(
              Icons.place_outlined,
              'PLACES',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  duration: Duration(seconds: 1),
                ),
              ),
            ),
            _navItem(
              Icons.more_horiz,
              'MORE',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  duration: Duration(seconds: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _navItem(
    IconData icon,
    String label, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    final color = active ? _cyan : _navInactive;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _dark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.alt_route, color: _cyan, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No trips yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textSection,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the record button to\nstart your first activity',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _navInactive,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Could not load trips',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: _navInactive, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
