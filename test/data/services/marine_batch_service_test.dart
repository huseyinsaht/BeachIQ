import 'dart:convert';

import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('MarineBatchService.fetchBatch', () {
    final coordinates = [
      const LatLng(38.3, 26.3),
      const LatLng(39.1, 27.0),
    ];

    String multiLocationFixture() => json.encode([
          {
            'latitude': 38.3,
            'longitude': 26.3,
            'current': {
              'wave_height': 1.2,
              'sea_surface_temperature': 24.5,
            },
          },
          {
            'latitude': 39.1,
            'longitude': 27.0,
            'current': {
              'wave_height': null,
              'sea_surface_temperature': null,
            },
          },
        ]);

    test('issues a single request and maps each coordinate', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(multiLocationFixture(), 200);
      });

      final service = MarineBatchService(mockClient);
      final result = await service.fetchBatch(coordinates);

      expect(callCount, 1);
      expect(result['38.3,26.3']!.waveHeight, 1.2);
      expect(result['38.3,26.3']!.seaSurfaceTemperature, 24.5);
    });

    test('maps a coordinate with null marine data to null, not 0', () async {
      final mockClient = MockClient((request) async {
        return http.Response(multiLocationFixture(), 200);
      });

      final service = MarineBatchService(mockClient);
      final result = await service.fetchBatch(coordinates);

      expect(result['39.1,27.0'], isNull);
    });

    test('sends comma-separated latitude/longitude for all coordinates',
        () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(multiLocationFixture(), 200);
      });

      final service = MarineBatchService(mockClient);
      await service.fetchBatch(coordinates);

      final uri = capturedRequest!.url;
      expect(uri.host, 'marine-api.open-meteo.com');
      expect(uri.queryParameters['latitude'], '38.3,39.1');
      expect(uri.queryParameters['longitude'], '26.3,27.0');
    });

    test('throws a clear error on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      final service = MarineBatchService(mockClient);

      await expectLater(
        () => service.fetchBatch(coordinates),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('503'),
          ),
        ),
      );
    });

    test('throws a clear error on malformed JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not json', 200);
      });

      final service = MarineBatchService(mockClient);

      await expectLater(
        () => service.fetchBatch(coordinates),
        throwsA(isA<Exception>()),
      );
    });

    test('throws a clear error when a location entry has no current field',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode([
            {'latitude': 38.3, 'longitude': 26.3},
            {'latitude': 39.1, 'longitude': 27.0, 'current': {}},
          ]),
          200,
        );
      });

      final service = MarineBatchService(mockClient);

      await expectLater(
        () => service.fetchBatch(coordinates),
        throwsA(isA<Exception>()),
      );
    });

    test('does not re-invoke the client for a repeat call within 1 hour',
        () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(multiLocationFixture(), 200);
      });

      var now = DateTime(2026, 1, 1, 12);
      final service = MarineBatchService(mockClient, now: () => now);

      final first = await service.fetchBatch(coordinates);
      expect(callCount, 1);

      now = now.add(const Duration(minutes: 30));
      final second = await service.fetchBatch(coordinates);

      expect(callCount, 1);
      expect(second['38.3,26.3']!.waveHeight, first['38.3,26.3']!.waveHeight);
    });

    test('re-invokes the client for a call after cache expiry', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(multiLocationFixture(), 200);
      });

      var now = DateTime(2026, 1, 1, 12);
      final service = MarineBatchService(mockClient, now: () => now);

      await service.fetchBatch(coordinates);
      expect(callCount, 1);

      now = now.add(const Duration(hours: 1, minutes: 1));
      await service.fetchBatch(coordinates);

      expect(callCount, 2);
    });
  });
}
