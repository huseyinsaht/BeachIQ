import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../logic/transect.dart';
import '../models/beach.dart';
import '../models/depth_profile.dart';

/// Fetches a nearshore depth profile for a beach from the EMODnet
/// Bathymetry DTM's WMS `GetFeatureInfo` endpoint (issue #216, step-0
/// decision 2026-10-05): up to [defaultTransectDistancesMeters.length]
/// small requests per beach, one per transect point, run only once per
/// beach view (cache the result with `DepthCache` -- this service itself
/// has no cache).
///
/// Resilience: this **never throws into the UI**. Any failure --
/// no geometry/no seaward bearing to build a transect from, a network
/// error, a timeout, a non-200 response, or a response body that cannot be
/// parsed at all -- is caught and turned into [DepthProfile.unavailable],
/// never an exception and never a fabricated/zero reading.
class BathymetryService {
  BathymetryService(
    this._client, {
    this.baseUrl = defaultBaseUrl,
    this.layer = defaultLayer,
    this.timeout = const Duration(seconds: 8),
    this.halfCellDegrees = 0.0006,
  });

  /// EMODnet Bathymetry's public OGC WMS endpoint (~1/16 arc-minute, ~115 m
  /// cells), checked live against `GetFeatureInfo` (see issue #216 and
  /// its follow-up fix). No API key is required. Not
  /// `tiles.emodnet-bathymetry.eu`: that host serves WMTS tiles and
  /// answers WMS requests with 403.
  static const String defaultBaseUrl = 'https://ows.emodnet-bathymetry.eu/wms';

  /// The WMS layer name queried on [defaultBaseUrl]. `emodnet:mean` is the
  /// DTM's mean depth: `GetFeatureInfo` returns a `Depth` property that is
  /// a signed elevation in meters, negative below sea level and positive on
  /// land, and an empty feature list outside the dataset's extent -- see
  /// [_depthFromRawValue]. (`emodnet:mean_atlas_land` is a rendered RGB
  /// layer with no depth value.)
  static const String defaultLayer = 'emodnet:mean';

  static const String _userAgent =
      'BeachIQ/1.0 (+https://github.com/huseyinsaht/BeachIQ)';

  /// A GeoServer/WMS raster NoData sentinel is typically a large-magnitude
  /// value (e.g. -9999, -32768, -3.4e38) far outside any real elevation or
  /// nearshore depth. Anything at or below this is treated as NoData
  /// rather than a genuine (absurdly deep) reading.
  static const double _noDataSentinelThreshold = -9000;

  final http.Client _client;

  /// The WMS base URL to query. Injectable for tests and for switching to
  /// a mirror without a code change.
  final String baseUrl;

  /// The WMS layer name to query (`LAYERS`/`QUERY_LAYERS`).
  final String layer;

  /// Per-request timeout. A `GetFeatureInfo` request against a single
  /// pixel is small, so this is deliberately short -- a slow/overloaded
  /// endpoint should fail fast rather than stall the first view of a
  /// beach's detail screen.
  final Duration timeout;

  /// Half the side length (in degrees) of the tiny bounding box queried
  /// around each transect point. Kept close to half of EMODnet's own
  /// ~1/16 arc-minute (~0.0010°) cell size so the single returned pixel
  /// corresponds to roughly one real grid cell, not several averaged
  /// together.
  final double halfCellDegrees;

  /// Fetches a nearshore depth profile for [beach]: builds its seaward
  /// transect (see `lib/logic/transect.dart`) and issues one
  /// `GetFeatureInfo` request per transect point, in order.
  ///
  /// Returns [DepthProfile.unavailable] when [beach] has no usable
  /// geometry/seaward bearing to build a transect from, or when every
  /// transect point came back with no usable depth (every request failed,
  /// every point is land, or both) -- a profile of nothing but nulls
  /// carries no information, so it is reported the same way as "could not
  /// fetch at all" rather than as a technically-non-empty but useless
  /// profile.
  Future<DepthProfile> fetchProfile(Beach beach) async {
    try {
      final points = seawardTransectFor(beach);
      if (points == null || points.isEmpty) {
        return const DepthProfile.unavailable();
      }

      final samples = <DepthSample>[];
      for (var i = 0; i < points.length; i++) {
        final depthMeters = await _fetchDepthAt(points[i]);
        samples.add(
          DepthSample(
            distanceMeters: defaultTransectDistancesMeters[i],
            depthMeters: depthMeters,
          ),
        );
      }

      final hasAnyUsableSample = samples.any(
        (sample) => sample.depthMeters != null,
      );
      if (!hasAnyUsableSample) {
        return const DepthProfile.unavailable();
      }

      return DepthProfile(samples: samples, available: true);
    } catch (_) {
      // Belt-and-braces: every expected failure path above already
      // resolves to null/unavailable rather than throwing, but this
      // service's contract is "never throws into the UI", so nothing
      // unexpected should be able to escape either.
      return const DepthProfile.unavailable();
    }
  }

  Future<double?> _fetchDepthAt(LatLng point) async {
    try {
      final response = await _client
          .get(_requestUriFor(point), headers: const {'User-Agent': _userAgent})
          .timeout(timeout);

      if (response.statusCode != 200) return null;
      return _parseDepth(response.body);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Uri _requestUriFor(LatLng point) {
    final latMin = point.latitude - halfCellDegrees;
    final latMax = point.latitude + halfCellDegrees;
    final lonMin = point.longitude - halfCellDegrees;
    final lonMax = point.longitude + halfCellDegrees;

    final queryParameters = {
      'SERVICE': 'WMS',
      'VERSION': '1.3.0',
      'REQUEST': 'GetFeatureInfo',
      'LAYERS': layer,
      'QUERY_LAYERS': layer,
      'STYLES': '',
      'CRS': 'EPSG:4326',
      // WMS 1.3.0 with CRS=EPSG:4326 orders BBOX by that CRS's own axis
      // order -- latitude, then longitude -- unlike WMS 1.1.1's always
      // lon/lat order. Getting this backwards would silently query the
      // wrong point.
      'BBOX': '$latMin,$lonMin,$latMax,$lonMax',
      'WIDTH': '1',
      'HEIGHT': '1',
      'I': '0',
      'J': '0',
      'FEATURE_COUNT': '1',
      'INFO_FORMAT': 'application/json',
    };

    return Uri.parse(baseUrl).replace(queryParameters: queryParameters);
  }

  /// Tolerantly parses a `GetFeatureInfo` response body as either JSON
  /// (the requested `INFO_FORMAT`) or GeoServer's plain-text format (in
  /// case a mirror/proxy ignores the request and answers with text
  /// anyway). Never throws -- any shape this does not recognize resolves
  /// to `null`, exactly like a confirmed NoData/land cell.
  double? _parseDepth(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    try {
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return _parseJsonDepth(trimmed);
      }
      return _parseTextDepth(trimmed);
    } catch (_) {
      return null;
    }
  }

  double? _parseJsonDepth(String body) {
    Object? decoded;
    try {
      decoded = json.decode(body);
    } on FormatException {
      return null;
    }

    if (decoded is! Map<String, dynamic>) return null;

    final features = decoded['features'];
    if (features is! List || features.isEmpty) {
      // No feature at this point: outside the dataset's extent, or a
      // NoData pixel that GeoServer reports as "no feature" rather than a
      // feature with a sentinel value.
      return null;
    }

    final firstFeature = features.first;
    if (firstFeature is! Map<String, dynamic>) return null;

    final properties = firstFeature['properties'];
    if (properties is! Map<String, dynamic>) return null;

    return _depthFromRawValue(_extractRawValue(properties));
  }

  /// The `emodnet:mean` layer reports its value as `Depth`; GeoServer's
  /// default raster key is `GRAY_INDEX` for a single-band layer. This tries
  /// both, then a few other common names, rather than assuming one exact
  /// server config.
  Object? _extractRawValue(Map<String, dynamic> properties) {
    for (final key in const [
      'Depth',
      'GRAY_INDEX',
      'value',
      'VALUE',
      'band1',
      'elevation',
    ]) {
      if (properties.containsKey(key)) return properties[key];
    }
    if (properties.isEmpty) return null;
    return properties.values.first;
  }

  /// GeoServer's plain-text `GetFeatureInfo` format looks like:
  /// ```
  /// Results for FeatureType 'emodnet:mean':
  ///    GRAY_INDEX = -45.2
  /// ```
  /// or has no `key = value` line at all when there is no feature at that
  /// point. This looks for the first such line and parses its number,
  /// tolerant of whichever key name precedes it.
  double? _parseTextDepth(String body) {
    final match = RegExp(r'=\s*(-?\d+(?:\.\d+)?)').firstMatch(body);
    if (match == null) return null;
    return _depthFromRawValue(double.tryParse(match.group(1)!));
  }

  /// Converts a raw WMS pixel value into a usable depth, or `null` for
  /// land/NoData -- the one place this service's "never 0, never a
  /// fabricated value" rule is enforced.
  ///
  /// [defaultLayer] encodes land as a non-negative elevation and the sea
  /// floor as a negative one (meters relative to mean sea level), so only
  /// a strictly negative value is a real nearshore depth; `0` itself (sea
  /// level/the waterline) is treated as land/no-depth rather than guessed
  /// at either way.
  double? _depthFromRawValue(Object? raw) {
    double? value;
    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String) {
      value = double.tryParse(raw.trim());
    }
    if (value == null || value.isNaN || value.isInfinite) return null;
    if (value <= _noDataSentinelThreshold) return null;
    if (value >= 0) return null;

    return -value;
  }
}
