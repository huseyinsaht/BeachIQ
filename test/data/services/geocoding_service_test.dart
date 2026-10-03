import 'dart:convert';

import 'package:beachiq/data/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GeocodingService.search', () {
    test('returns a parsed Place list for a successful response', () async {
      final client = MockClient((request) async {
        return http.Response(
          json.encode({
            'results': [
              {
                'name': 'Cesme',
                'admin1': 'Izmir',
                'country': 'Turkey',
                'latitude': 38.3220,
                'longitude': 26.3260,
              },
            ],
          }),
          200,
        );
      });

      final results = await GeocodingService(client).search('Cesme');

      expect(results, hasLength(1));
      expect(results.first.name, 'Cesme');
      expect(results.first.latitude, 38.3220);
    });

    test('returns an empty list when the response has no results key', () async {
      final client = MockClient((request) async {
        return http.Response(json.encode({}), 200);
      });

      final results = await GeocodingService(client).search('Cesme');

      expect(results, isEmpty);
    });

    test('returns an empty list for a query shorter than 2 characters '
        'without making a request', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response(json.encode({'results': []}), 200);
      });

      final results = await GeocodingService(client).search('c');

      expect(results, isEmpty);
      expect(callCount, 0);
    });

    test('skips malformed entries instead of throwing', () async {
      final client = MockClient((request) async {
        return http.Response(
          json.encode({
            'results': [
              {'name': 'Valid', 'latitude': 1.0, 'longitude': 2.0},
              {'name': 'Missing coordinates'},
              'not even a map',
            ],
          }),
          200,
        );
      });

      final results = await GeocodingService(client).search('Valid');

      expect(results, hasLength(1));
      expect(results.first.name, 'Valid');
    });

    test('throws a clear error on a non-200 response', () async {
      final client = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      await expectLater(
        () => GeocodingService(client).search('Cesme'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('503'),
          ),
        ),
      );
    });

    test('wraps a network error in a clear exception', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      await expectLater(
        () => GeocodingService(client).search('Cesme'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Network Error'),
          ),
        ),
      );
    });

    test('sends the expected query parameters', () async {
      http.Request? capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(json.encode({'results': []}), 200);
      });

      await GeocodingService(client).search('Cesme', count: 5);

      final uri = capturedRequest!.url;
      expect(uri.host, 'geocoding-api.open-meteo.com');
      expect(uri.queryParameters['name'], 'Cesme');
      expect(uri.queryParameters['count'], '5');
    });
  });
}
