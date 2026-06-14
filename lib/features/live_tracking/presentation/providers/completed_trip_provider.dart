import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tracking_state.dart';

final completedTripProvider = StateProvider<TrackingState?>((ref) => null);
