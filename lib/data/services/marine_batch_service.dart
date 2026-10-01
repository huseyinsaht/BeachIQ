import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:beachiq/data/models/sea_condition.dart';

class _CachedBatch {
  final Map<String, SeaCondition?> data;
  final DateTime fetchedAt;

  _CachedBatch(this.data, this.fetchedAt);
}

/// Fetches wave height and sea surface temperature for many beach
/// coordinates in a single Open-Meteo Marine API request, using its
/// multi-location comma-separated `latitude`/`longitude` parameters.
///
/// This is a separate, batched path from [MarineApiService]/
/// `MarineRepository`, which stay dedicated to the single-location home
/// screen lookup.
class MarineBatchService {
  static const String _baseUrl = "https://marine-api.open-meteo.com/v1/marine";
  static const Duration _cacheDuration = Duration(hours: 1);

  final http.Client client;
  final DateTime Function() _now;

  final Map<String, _CachedBatch> _cache = {};

  MarineBatchService(this.client, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  Future<Map<String, SeaCondition?>> fetchBatch(
    List<LatLng> coordinates,
  ) async {
    if (coordinates.isEmpty) {
      return {};
    }

    final cacheKey = _cacheKeyFor(coordinates);
    final now = _now();
    final cached = _cache[cacheKey];
    if (cached != null && now.difference(cached.fetchedAt) < _cacheDuration) {
      return cached.data;
    }

    final queryParams = {
      'latitude': coordinates.map((c) => c.latitude.toString()).join(','),
      'longitude': coordinates.map((c) => c.longitude.toString()).join(','),
      'current': 'wave_height,sea_surface_temperature',
      'timezone': 'auto',
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

    http.Response response;
    try {
      response = await client.get(uri);
    } catch (e) {
      throw Exception("Network Error: $e");
    }

    if (response.statusCode != 200) {
      throw Exception("Server Error: ${response.statusCode}");
    }

    dynamic decoded;
    try {
      decoded = json.decode(response.body);
    } catch (e) {
      throw Exception("Malformed marine batch response: $e");
    }

    final List<dynamic> entries;
    if (decoded is List) {
      entries = decoded;
    } else if (decoded is Map<String, dynamic>) {
      // Open-Meteo may return a single object instead of a list when only
      // one location is requested.
      entries = [decoded];
    } else {
      throw Exception(
        "Malformed marine batch response: expected a list of locations",
      );
    }

    if (entries.length != coordinates.length) {
      throw Exception(
        "Malformed marine batch response: expected ${coordinates.length} "
        "locations, got ${entries.length}",
      );
    }

    final result = <String, SeaCondition?>{};
    for (var i = 0; i < coordinates.length; i++) {
      final coordinate = coordinates[i];
      final entry = entries[i];

      if (entry is! Map<String, dynamic>) {
        throw Exception(
          "Malformed marine batch response: location entry is not an object",
        );
      }

      final current = entry['current'];
      if (current is! Map<String, dynamic>) {
        throw Exception(
          "Malformed marine batch response: missing 'current' field",
        );
      }

      final waveHeight = current['wave_height'];
      final seaSurfaceTemperature = current['sea_surface_temperature'];

      if (waveHeight == null || seaSurfaceTemperature == null) {
        result[_keyFor(coordinate)] = null;
      } else {
        result[_keyFor(coordinate)] = SeaCondition.fromJson(current);
      }
    }

    _cache[cacheKey] = _CachedBatch(result, now);

    return result;
  }

  String _keyFor(LatLng coordinate) =>
      '${coordinate.latitude},${coordinate.longitude}';

  String _cacheKeyFor(List<LatLng> coordinates) {
    final rounded = coordinates
        .map(
          (c) =>
              '${c.latitude.toStringAsFixed(4)}:${c.longitude.toStringAsFixed(4)}',
        )
        .toList()
      ..sort();
    return rounded.join('|');
  }
}
