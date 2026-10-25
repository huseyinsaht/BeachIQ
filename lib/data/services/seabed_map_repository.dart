import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Half of the seabed map's side length, in meters: the map shows a square
/// window of `2 * seabedMapHalfSpanMeters` (4 km) centred on the beach.
const double seabedMapHalfSpanMeters = 2000;

/// Pixel size (square) requested for the seabed map image.
const int seabedMapImageSizePx = 512;

/// Fetches and caches the EMODnet Bathymetry seabed image for the Water
/// depth detail screen (issue #293): one WMS `GetMap` image per beach
/// (shaded relief + labelled depth contours) and one `GetLegendGraphic`
/// image shared by all beaches.
///
/// Same data and terms as `BathymetryService` (EMODnet Bathymetry DTM,
/// CC BY 4.0, ~115 m grid, not for navigation). Images are cached in
/// [SharedPreferences] for [ttl] (90 days, like the depth profile), keyed
/// by the beach's coordinates rounded to ~110 m. Every failure -- network
/// error, non-200 reply, an XML `ServiceException` instead of a PNG, a
/// timeout -- resolves to `null`; this class never throws and never
/// substitutes another provider.
class SeabedMapRepository {
  SeabedMapRepository(
    this._client,
    this._prefs, {
    DateTime Function()? now,
    this.ttl = const Duration(days: 90),
    this.timeout = const Duration(seconds: 20),
  }) : _now = now ?? DateTime.now;

  final http.Client _client;
  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final Duration ttl;
  final Duration timeout;

  static const String _host = 'ows.emodnet-bathymetry.eu';
  static const String _userAgent =
      'BeachIQ/1.0 (+https://github.com/huseyinsaht/BeachIQ)';
  static const String _mapKeyPrefix = 'seabed_map_v1:';
  static const String _legendKey = 'seabed_legend_v1';

  /// The WMS 1.3.0 `GetMap` URL for the window around ([latitude],
  /// [longitude]). In WMS 1.3.0 with EPSG:4326 the bbox axis order is
  /// `minLat,minLon,maxLat,maxLon`.
  static Uri mapUri(double latitude, double longitude) {
    const metersPerDegreeLat = 111320.0;
    final dLat = seabedMapHalfSpanMeters / metersPerDegreeLat;
    final cosLat = math.cos(latitude * math.pi / 180).abs().clamp(0.01, 1.0);
    final dLon = seabedMapHalfSpanMeters / (metersPerDegreeLat * cosLat);
    final bbox = [
      latitude - dLat,
      longitude - dLon,
      latitude + dLat,
      longitude + dLon,
    ].map((v) => v.toStringAsFixed(5)).join(',');
    return Uri.https(_host, '/wms', {
      'service': 'WMS',
      'version': '1.3.0',
      'request': 'GetMap',
      'layers': 'emodnet:mean_atlas_land,emodnet:contours',
      'styles': ',',
      'crs': 'EPSG:4326',
      'bbox': bbox,
      'width': '$seabedMapImageSizePx',
      'height': '$seabedMapImageSizePx',
      'format': 'image/png',
    });
  }

  /// The official depth legend for the shaded-relief layer.
  static Uri get legendUri => Uri.https(_host, '/wms', {
    'service': 'WMS',
    'version': '1.3.0',
    'request': 'GetLegendGraphic',
    'layer': 'emodnet:mean_atlas_land',
    'format': 'image/png',
  });

  /// PNG bytes of the seabed around ([latitude], [longitude]), from the
  /// cache when fresh, else from the network; `null` when unavailable.
  Future<Uint8List?> getMap(double latitude, double longitude) {
    final key =
        '$_mapKeyPrefix${latitude.toStringAsFixed(3)}_'
        '${longitude.toStringAsFixed(3)}';
    return _cachedOrFetch(key, mapUri(latitude, longitude));
  }

  /// PNG bytes of the depth legend; `null` when unavailable.
  Future<Uint8List?> getLegend() => _cachedOrFetch(_legendKey, legendUri);

  Future<Uint8List?> _cachedOrFetch(String key, Uri uri) async {
    final cached = _readCache(key);
    if (cached != null) return cached;
    final bytes = await _fetchPng(uri);
    if (bytes != null) await _writeCache(key, bytes);
    return bytes;
  }

  Future<Uint8List?> _fetchPng(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      return _isPng(response.bodyBytes) ? response.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  static bool _isPng(Uint8List bytes) =>
      bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;

  Uint8List? _readCache(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.parse(decoded['t'] as String);
      if (_now().difference(fetchedAt) > ttl) return null;
      final bytes = base64Decode(decoded['b'] as String);
      return _isPng(bytes) ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, Uint8List bytes) async {
    try {
      await _prefs.setString(
        key,
        jsonEncode({'t': _now().toIso8601String(), 'b': base64Encode(bytes)}),
      );
    } catch (_) {
      // A full or unavailable cache must never break the screen.
    }
  }
}
