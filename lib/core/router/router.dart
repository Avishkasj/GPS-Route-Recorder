import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/live_tracking/presentation/screens/follow_route_screen.dart';
import '../../features/live_tracking/presentation/screens/live_tracking_screen.dart';
import '../../features/live_tracking/presentation/screens/trip_statistics_screen.dart';
import '../../features/live_tracking/presentation/screens/waypoints_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/product_details/presentation/screens/product_detail_screen.dart';
import '../../features/products/presentation/screens/products_list_screen.dart';
import '../../features/trip_history/presentation/screens/trip_history_screen.dart';
import 'routes.dart';

part 'router.g.dart';

// Overridden in main.dart once SharedPreferences is read.
final initialRouteProvider = Provider<String>((ref) => Routes.trips);

@riverpod
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: ref.read(initialRouteProvider),
    routes: [
      GoRoute(
        path: Routes.trips,
        builder: (context, state) => const TripHistoryScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.liveTracking,
        builder: (context, state) => const LiveTrackingScreen(),
      ),
      GoRoute(
        path: Routes.waypoints,
        builder: (context, state) => const WaypointsScreen(),
      ),
      GoRoute(
        path: Routes.tripStatistics,
        builder: (context, state) => const TripStatisticsScreen(),
      ),
      GoRoute(
        path: Routes.followRoute,
        builder: (context, state) => const FollowRouteScreen(),
      ),
      GoRoute(
        path: Routes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const ProductsListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return ProductDetailScreen(productId: id);
            },
          ),
        ],
      ),
    ],
  );
}
