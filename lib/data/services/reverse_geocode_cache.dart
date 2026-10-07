import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A persistent cache of reverse-geocoded place names, keyed by a coarse
/// grid cell — issue #254's "cache resolved names per rounded grid cell in
/// SharedPreferences, same idea as `depth_cache.dart`". A city name is
/// essentially static over the area a grid cell covers, so a fresh entry is
/// reused for a very long time (unlike `BeachCache`'s 7-day TTL or
/// `DepthCache`'s 90-day one); mirrors [DepthCache]'s "a miss is just
/// re-fetched, no stale-while-revalidate" behavior.
class ReverseGeocodeCache {
  ReverseGeocodeCache(
    this._prefs, {
    DateTime Function()? now,
    this.ttl = const Duration(days: 30),
    this.gridSize = 0.01,
  }) : _now = now ?? DateTime.now;

  /// Creates a [ReverseGeocodeCache] backed by the shared, on-disk
  /// [SharedPreferences] instance.
  static Future<ReverseGeocodeCache> create({
    DateTime Function()? now,
    Duration ttl = const Duration(days: 30),
    double gridSize = 0.01,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return ReverseGeocodeCache(prefs, now: now, ttl: ttl, gridSize: gridSize);
  }

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// How long a cached entry is considered fresh.
  final Duration ttl;

  /// The side length, in degrees, of a grid cell. Two positions that round
  /// to the same cell share a cache entry — 0.01° is roughly 1.1 km at the
  /// equator, well within how far a device-location fix or a map tap can
  /// drift while still describing "the same place" by name.
  final double gridSize;

  static const String _keyPrefix = 'reverse_geocode_cache_v1:';

  /// Returns the cache key for the grid cell containing (`latitude`,
  /// `longitude`). Two coordinates that round to the same grid cell produce
  /// the same key.
  String gridKeyFor(double latitude, double longitude) {
    final gridLat = _roundToGrid(latitude);
    final gridLon = _roundToGrid(longitude);
    return '$_keyPrefix${gridLat.toStringAsFixed(3)}_${gridLon.toStringAsFixed(3)}';
  }

  double _roundToGrid(double value) {
    return (value / gridSize).round() * gridSize;
  }

  /// Returns the cached display name for (`latitude`, `longitude`) when a
  /// fresh (within [ttl]) entry exists; otherwise runs [fetch], caches its
  /// result (only when it's non-null/non-empty — a failed lookup is never
  /// cached, so it's retried on the next call rather than remembered), and
  /// returns it.
  Future<String?> get({
    required double latitude,
    required double longitude,
    required Future<String?> Function() fetch,
  }) async {
    final key = gridKeyFor(latitude, longitude);
    final cached = _readEntry(key);
    if (cached != null && _now().difference(cached.fetchedAt) <= ttl) {
      return cached.name;
    }

    final fetched = await fetch();
    if (fetched != null && fetched.trim().isNotEmpty) {
      await _writeEntry(key, fetched);
    }
    return fetched;
  }

  /// Writes [name] directly into the cache entry for (`latitude`,
  /// `longitude`), bypassing any fetch. Mainly useful for tests and for
  /// pre-seeding the cache.
  Future<void> put(double latitude, double longitude, String name) {
    return _writeEntry(gridKeyFor(latitude, longitude), name);
  }

  _CacheEntry? _readEntry(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.parse(decoded['fetchedAt'] as String);
      final name = decoded['name'] as String;
      return _CacheEntry(name: name, fetchedAt: fetchedAt);
    } catch (_) {
      // Corrupt or unrecognized entry: treat as if nothing were cached.
      return null;
    }
  }

  Future<void> _writeEntry(String key, String name) {
    final payload = json.encode({
      'fetchedAt': _now().toIso8601String(),
      'name': name,
    });
    return _prefs.setString(key, payload);
  }
}

class _CacheEntry {
  _CacheEntry({required this.name, required this.fetchedAt});

  final String name;
  final DateTime fetchedAt;
}
