import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/depth_profile.dart';

/// A persistent cache of [DepthProfile]s, keyed by a coarse grid cell so
/// that a beach's depth transect is only fetched once per 90-day window
/// (issue #216's step-0 decision: "up to 5 small requests per beach, first
/// view only, behind a 90-day cache" -- EMODnet's bathymetry grid does not
/// change on any shorter timescale that matters here).
///
/// Mirrors `beach_cache.dart`'s [SharedPreferences]-backed, grid-keyed
/// cache pattern, with one deliberate difference: an expired entry is
/// simply treated as a miss (triggering [fetch] again) rather than
/// returned stale-while-revalidate -- there is no "still useful but
/// should refresh in the background" state for a dataset this slow-moving,
/// so a single `get` call is enough for a caller to end up with fresh
/// data, unlike [BeachCache]'s two-step `get`/`refresh`.
class DepthCache {
  DepthCache(
    this._prefs, {
    DateTime Function()? now,
    this.ttl = const Duration(days: 90),
    this.gridSize = 0.001,
  }) : _now = now ?? DateTime.now;

  /// Creates a [DepthCache] backed by the shared, on-disk
  /// [SharedPreferences] instance.
  static Future<DepthCache> create({
    DateTime Function()? now,
    Duration ttl = const Duration(days: 90),
    double gridSize = 0.001,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return DepthCache(prefs, now: now, ttl: ttl, gridSize: gridSize);
  }

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// How long a cached entry is considered fresh. Per issue #216: 90 days.
  final Duration ttl;

  /// The side length, in degrees, of a grid cell. Two positions that round
  /// to the same cell share a cache entry -- 0.001° is roughly 111 m at
  /// the equator, close to EMODnet's own ~115 m grid cell, so this neither
  /// merges two genuinely different beaches nor creates a separate entry
  /// per pixel-sized jitter in a beach's stored coordinates.
  final double gridSize;

  static const String _keyPrefix = 'depth_cache_v1:';

  /// Returns the cache key for the grid cell containing (`latitude`,
  /// `longitude`). Two coordinates that round to the same grid cell
  /// produce the same key.
  String gridKeyFor(double latitude, double longitude) {
    final gridLat = _roundToGrid(latitude);
    final gridLon = _roundToGrid(longitude);
    return '$_keyPrefix${gridLat.toStringAsFixed(4)}_${gridLon.toStringAsFixed(4)}';
  }

  double _roundToGrid(double value) {
    return (value / gridSize).round() * gridSize;
  }

  /// Returns the cached [DepthProfile] for (`latitude`, `longitude`) when
  /// a fresh (within [ttl]) entry exists; otherwise runs [fetch], caches
  /// its result (only when [DepthProfile.available] -- an "unavailable"
  /// result is never cached, so a transient failure is retried on the
  /// next call rather than remembered for 90 days), and returns it.
  Future<DepthProfile> get({
    required double latitude,
    required double longitude,
    required Future<DepthProfile> Function() fetch,
  }) async {
    final key = gridKeyFor(latitude, longitude);
    final cached = _readEntry(key);
    if (cached != null && _now().difference(cached.fetchedAt) <= ttl) {
      return cached.profile;
    }

    final fetched = await fetch();
    if (fetched.available) {
      await _writeEntry(key, fetched);
    }
    return fetched;
  }

  /// Writes [profile] directly into the cache entry for (`latitude`,
  /// `longitude`), bypassing any fetch. Mainly useful for tests and for
  /// pre-seeding the cache.
  Future<void> put(double latitude, double longitude, DepthProfile profile) {
    return _writeEntry(gridKeyFor(latitude, longitude), profile);
  }

  _CacheEntry? _readEntry(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.parse(decoded['fetchedAt'] as String);
      final profile = _profileFromJson(
        decoded['profile'] as Map<String, dynamic>,
      );
      return _CacheEntry(profile: profile, fetchedAt: fetchedAt);
    } catch (_) {
      // Corrupt or unrecognized entry: treat as if nothing were cached.
      return null;
    }
  }

  Future<void> _writeEntry(String key, DepthProfile profile) {
    final payload = json.encode({
      'fetchedAt': _now().toIso8601String(),
      'profile': _profileToJson(profile),
    });
    return _prefs.setString(key, payload);
  }

  static Map<String, dynamic> _profileToJson(DepthProfile profile) => {
    'available': profile.available,
    'approximate': profile.approximate,
    'samples': profile.samples
        .map(
          (sample) => {
            'distanceMeters': sample.distanceMeters,
            'depthMeters': sample.depthMeters,
          },
        )
        .toList(),
  };

  static DepthProfile _profileFromJson(Map<String, dynamic> json) {
    final rawSamples = (json['samples'] as List?) ?? const [];
    return DepthProfile(
      samples: rawSamples
          .cast<Map<String, dynamic>>()
          .map(
            (sample) => DepthSample(
              distanceMeters: (sample['distanceMeters'] as num).toDouble(),
              depthMeters: (sample['depthMeters'] as num?)?.toDouble(),
            ),
          )
          .toList(),
      available: json['available'] as bool? ?? false,
      approximate: json['approximate'] as bool? ?? true,
    );
  }
}

class _CacheEntry {
  _CacheEntry({required this.profile, required this.fetchedAt});

  final DepthProfile profile;
  final DateTime fetchedAt;
}
