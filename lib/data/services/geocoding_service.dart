import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place.dart';

/// Looks up places by name via the free Open-Meteo Geocoding API (no API
/// key), so the app can offer real place search instead of a hard-coded
/// city list.
class GeocodingService {
  GeocodingService(this._client, {this.timeout = const Duration(seconds: 10)});

  static const String _baseUrl =
      'https://geocoding-api.open-meteo.com/v1/search';

  /// A query shorter than this is treated the same as an empty query (no
  /// request sent, empty result), matching a typical "start typing" UX and
  /// avoiding a flood of near-useless single-character requests.
  static const int _minQueryLength = 2;

  final http.Client _client;
  final Duration timeout;

  /// Returns places matching [query]. An empty/too-short query or a
  /// response without a `results` list yields `[]`, never an error. A
  /// network failure or a non-200 response throws an [Exception] with a
  /// clear message (mirrors `WeatherApiService.getWeatherData`'s style).
  Future<List<Place>> search(String query, {int count = 10}) async {
    final trimmed = query.trim();
    if (trimmed.length < _minQueryLength) return const [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'name': trimmed,
        'count': count.toString(),
        'language': 'en',
        'format': 'json',
      },
    );

    http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } catch (e) {
      throw Exception('Network Error: $e');
    }

    if (response.statusCode != 200) {
      throw Exception('Server Error: ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final results = decoded is Map<String, dynamic> ? decoded['results'] : null;
    if (results is! List) return const [];

    return [
      for (final entry in results)
        if (entry is Map<String, dynamic>) Place.tryFromJson(entry),
    ].whereType<Place>().toList();
  }
}
