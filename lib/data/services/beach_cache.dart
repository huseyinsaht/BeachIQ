import 'dart:convert';
import 'dart:math' as math;

import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/models/beach_amenity.dart';
import 'package:beachiq/data/static_beaches.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The outcome of a [BeachCache] lookup.
class BeachCacheResult {
  const BeachCacheResult({
    required this.beaches,
    required this.isStale,
    this.isFallback = false,
  });

  /// The beaches to show. Never empty unless both the cache and the
  /// static fallback have nothing for the area.
  final List<Beach> beaches;

  /// True when [beaches] came from a cache entry older than the TTL.
  /// The data is still returned (stale-while-revalidate), but the caller
  /// may want to trigger [BeachCache.refresh] in the background.
  final bool isStale;

  /// True when [beaches] came from the static beach list rather than a
  /// live or cached Overpass query (offline, and nothing cached yet).
  final bool isFallback;
}

/// A persistent cache of OSM beach query results, keyed by a coarse grid
/// cell so that nearby picks reuse the same cached data instead of
/// re-querying Overpass every time.
///
/// Entries are stored via [SharedPreferences] so they survive app
/// restarts. Each entry has a fixed TTL; once expired it is still
/// returned (stale-while-revalidate) so the UI never has to wait on a
/// network round-trip, but [BeachCacheResult.isStale] tells the caller a
/// background refresh is worth triggering.
///
/// When there is nothing cached for the relevant grid cell and the fetch
/// fails (e.g. offline, or every Overpass endpoint is down), this falls
/// back to [staticBeaches] filtered to a reasonable radius so the app
/// never shows a blank screen.
class BeachCache {
  BeachCache(
    this._prefs, {
    DateTime Function()? now,
    this.ttl = const Duration(days: 7),
    this.gridSize = 0.25,
    this.fallbackRadiusKm = 100,
  }) : _now = now ?? DateTime.now;

  /// Creates a [BeachCache] backed by the shared, on-disk
  /// [SharedPreferences] instance.
  static Future<BeachCache> create({
    DateTime Function()? now,
    Duration ttl = const Duration(days: 7),
    double gridSize = 0.25,
    double fallbackRadiusKm = 100,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return BeachCache(
      prefs,
      now: now,
      ttl: ttl,
      gridSize: gridSize,
      fallbackRadiusKm: fallbackRadiusKm,
    );
  }

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// How long a cached entry is considered fresh.
  final Duration ttl;

  /// The side length, in degrees, of a grid cell. Picks that round to the
  /// same cell share a cache entry.
  final double gridSize;

  /// Radius, in kilometers, used to filter [staticBeaches] when falling
  /// back to the static list.
  final double fallbackRadiusKm;

  static const String _keyPrefix = 'beach_cache_v1:';

  /// Returns the cache key for the grid cell containing (`latitude`,
  /// `longitude`). Two coordinates that round to the same grid cell
  /// produce the same key.
  String gridKeyFor(double latitude, double longitude) {
    final gridLat = _roundToGrid(latitude);
    final gridLon = _roundToGrid(longitude);
    return '$_keyPrefix${gridLat.toStringAsFixed(3)}_${gridLon.toStringAsFixed(3)}';
  }

  double _roundToGrid(double value) {
    return (value / gridSize).round() * gridSize;
  }

  /// Returns the cached beaches for (`latitude`, `longitude`) if present,
  /// otherwise runs [fetch], caches the result, and returns it. If
  /// [fetch] throws and nothing is cached, falls back to [staticBeaches]
  /// filtered to [fallbackRadiusKm].
  ///
  /// A cached entry is always returned immediately, even if it is stale;
  /// [BeachCacheResult.isStale] tells the caller whether it is worth
  /// calling [refresh] in the background.
  Future<BeachCacheResult> get({
    required double latitude,
    required double longitude,
    required Future<List<Beach>> Function() fetch,
  }) async {
    final key = gridKeyFor(latitude, longitude);
    final cached = _readEntry(key);
    if (cached != null) {
      final isStale = _now().difference(cached.fetchedAt) > ttl;
      return BeachCacheResult(beaches: cached.beaches, isStale: isStale);
    }

    try {
      final fetched = await fetch();
      await _writeEntry(key, fetched);
      return BeachCacheResult(beaches: fetched, isStale: false);
    } catch (_) {
      return BeachCacheResult(
        beaches: _fallbackBeaches(latitude, longitude),
        isStale: false,
        isFallback: true,
      );
    }
  }

  /// Runs [fetch] and overwrites the cache entry for (`latitude`,
  /// `longitude`) with its result. Intended for callers to invoke as the
  /// background refresh half of stale-while-revalidate, after [get]
  /// reports a stale entry.
  Future<List<Beach>> refresh({
    required double latitude,
    required double longitude,
    required Future<List<Beach>> Function() fetch,
  }) async {
    final fetched = await fetch();
    await _writeEntry(gridKeyFor(latitude, longitude), fetched);
    return fetched;
  }

  /// Writes [beaches] directly into the cache entry for (`latitude`,
  /// `longitude`), bypassing any fetch. Mainly useful for tests and for
  /// pre-seeding the cache.
  Future<void> put(double latitude, double longitude, List<Beach> beaches) {
    return _writeEntry(gridKeyFor(latitude, longitude), beaches);
  }

  _CacheEntry? _readEntry(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.parse(decoded['fetchedAt'] as String);
      final beaches = (decoded['beaches'] as List)
          .cast<Map<String, dynamic>>()
          .map(_beachFromJson)
          .toList();
      return _CacheEntry(beaches: beaches, fetchedAt: fetchedAt);
    } catch (_) {
      // Corrupt or unrecognized entry: treat as if nothing were cached.
      return null;
    }
  }

  Future<void> _writeEntry(String key, List<Beach> beaches) {
    final payload = json.encode({
      'fetchedAt': _now().toIso8601String(),
      'beaches': beaches.map(_beachToJson).toList(),
    });
    return _prefs.setString(key, payload);
  }

  List<Beach> _fallbackBeaches(double latitude, double longitude) {
    final withinRadius = staticBeaches.where((beach) {
      final distanceKm = _haversineKm(
        latitude,
        longitude,
        beach.latitude,
        beach.longitude,
      );
      return distanceKm <= fallbackRadiusKm;
    }).toList();
    return withinRadius;
  }

  static Map<String, dynamic> _beachToJson(Beach beach) => {
    'name': beach.name,
    'city': beach.city,
    'latitude': beach.latitude,
    'longitude': beach.longitude,
    'surface': beach.surface,
    'hasLifeguard': beach.hasLifeguard,
    'fee': beach.fee.name,
    'hasShower': beach.hasShower,
    'hasToilets': beach.hasToilets,
    'hasChangingRoom': beach.hasChangingRoom,
    'hasParking': beach.hasParking,
    'hasCafe': beach.hasCafe,
    'hasBeachResort': beach.hasBeachResort,
    'geometry': beach.geometry
        ?.map((point) => [point.latitude, point.longitude])
        .toList(),
    'amenities': beach.amenities.map(_amenityToJson).toList(),
  };

  static Map<String, dynamic> _amenityToJson(BeachAmenity amenity) => {
    'kind': amenity.kind.name,
    'latitude': amenity.position.latitude,
    'longitude': amenity.position.longitude,
    'name': amenity.name,
  };

  static Beach _beachFromJson(Map<String, dynamic> json) => Beach(
    name: json['name'] as String,
    city: json['city'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    surface: json['surface'] as String?,
    hasLifeguard: json['hasLifeguard'] as bool?,
    fee: BeachFee.values.firstWhere(
      (value) => value.name == json['fee'],
      orElse: () => BeachFee.unknown,
    ),
    hasShower: json['hasShower'] as bool? ?? false,
    hasToilets: json['hasToilets'] as bool? ?? false,
    hasChangingRoom: json['hasChangingRoom'] as bool? ?? false,
    hasParking: json['hasParking'] as bool? ?? false,
    hasCafe: json['hasCafe'] as bool? ?? false,
    hasBeachResort: json['hasBeachResort'] as bool? ?? false,
    geometry: (json['geometry'] as List?)
        ?.cast<List<dynamic>>()
        .map(
          (point) => LatLng(
            (point[0] as num).toDouble(),
            (point[1] as num).toDouble(),
          ),
        )
        .toList(),
    // Absent in a cache entry written before this field existed: an
    // old entry still loads, just with no amenities (empty list).
    amenities:
        (json['amenities'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map(_amenityFromJson)
            .whereType<BeachAmenity>()
            .toList() ??
        const [],
  );

  /// Returns `null` for an entry with an unrecognized `kind` instead of
  /// throwing, so one corrupt amenity does not fail the whole cache read.
  static BeachAmenity? _amenityFromJson(Map<String, dynamic> json) {
    AmenityKind? kind;
    for (final value in AmenityKind.values) {
      if (value.name == json['kind']) {
        kind = value;
        break;
      }
    }
    if (kind == null) return null;
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (latitude is! num || longitude is! num) return null;
    return BeachAmenity(
      kind: kind,
      position: LatLng(latitude.toDouble(), longitude.toDouble()),
      name: json['name'] as String?,
    );
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}

class _CacheEntry {
  _CacheEntry({required this.beaches, required this.fetchedAt});

  final List<Beach> beaches;
  final DateTime fetchedAt;
}
