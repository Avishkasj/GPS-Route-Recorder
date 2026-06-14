import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/saved_trip.dart';

class TripStorageService {
  static const _key = 'trip_history_v1';

  Future<List<SavedTrip>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    final trips = <SavedTrip>[];
    for (final s in list) {
      try {
        trips.add(
            SavedTrip.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (e) {
        // Skip corrupted entries — do not crash the entire history
        debugPrint('[TripStorage] Skipping corrupt entry: $e');
      }
    }
    return trips;
  }

  Future<void> save(SavedTrip trip) async {
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(prefs.getStringList(_key) ?? []);
    list.insert(0, jsonEncode(trip.toJson())); // newest first
    await prefs.setStringList(_key, list);
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(prefs.getStringList(_key) ?? []);
    list.removeWhere((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['id'] == id;
      } catch (_) {
        return true; // remove corrupt entries too
      }
    });
    await prefs.setStringList(_key, list);
  }
}
