import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trip_storage_service.dart';
import '../../domain/saved_trip.dart';

class TripHistoryNotifier
    extends StateNotifier<AsyncValue<List<SavedTrip>>> {
  final TripStorageService _storage;

  TripHistoryNotifier(this._storage) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_storage.loadAll);
  }

  Future<void> saveTrip(SavedTrip trip) async {
    await _storage.save(trip);
    await _load();
  }

  Future<void> deleteTrip(String id) async {
    await _storage.delete(id);
    await _load();
  }
}

final _storageProvider =
    Provider<TripStorageService>((ref) => TripStorageService());

final tripHistoryProvider = StateNotifierProvider<TripHistoryNotifier,
    AsyncValue<List<SavedTrip>>>(
  (ref) => TripHistoryNotifier(ref.read(_storageProvider)),
);
