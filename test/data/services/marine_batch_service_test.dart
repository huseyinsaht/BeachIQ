import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/fake_http_client.dart';

void main() {
  group('MarineBatchService', () {
    group('fetchBatch', () {
      final coordinates = [const LatLng(38.3, 26.3), const LatLng(39.1, 27.0)];

      Object multiLocationFixture() => [
        {
          'latitude': 38.3,
          'longitude': 26.3,
          'current': {'wave_height': 1.2, 'sea_surface_temperature': 24.5},
        },
        {
          'latitude': 39.1,
          'longitude': 27.0,
          'current': {'wave_height': null, 'sea_surface_temperature': null},
        },
      ];

      test(
        'given a successful response, fetchBatch -> issues a single request and maps each coordinate',
        () async {
          final client = FakeHttpClient()
            ..queueJson(
              host: 'marine-api.open-meteo.com',
              json: multiLocationFixture(),
            );

          final service = MarineBatchService(client);
          final result = await service.fetchBatch(coordinates);

          expect(client.requests, hasLength(1));
          expect(result['38.3,26.3']!.waveHeight, 1.2);
          expect(result['38.3,26.3']!.seaSurfaceTemperature, 24.5);
        },
      );

      test(
        'given a coordinate with null marine data, fetchBatch -> maps it to null, not 0',
        () async {
          final client = FakeHttpClient()
            ..queueJson(
              host: 'marine-api.open-meteo.com',
              json: multiLocationFixture(),
            );

          final service = MarineBatchService(client);
          final result = await service.fetchBatch(coordinates);

          expect(result['39.1,27.0'], isNull);
        },
      );

      test(
        'given coordinates, fetchBatch -> sends comma-separated latitude/longitude for all of them',
        () async {
          final client = FakeHttpClient()
            ..queueJson(
              host: 'marine-api.open-meteo.com',
              json: multiLocationFixture(),
            );

          final service = MarineBatchService(client);
          await service.fetchBatch(coordinates);

          final uri = client.requests.single.url;
          expect(uri.host, 'marine-api.open-meteo.com');
          expect(uri.queryParameters['latitude'], '38.3,39.1');
          expect(uri.queryParameters['longitude'], '26.3,27.0');
        },
      );

      test(
        'given a non-200 response, fetchBatch -> throws a clear error',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(
              host: 'marine-api.open-meteo.com',
              body: 'Service Unavailable',
              statusCode: 503,
            );

          final service = MarineBatchService(client);

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
        },
      );

      test(
        'given malformed JSON, fetchBatch -> throws a clear error',
        () async {
          final client = FakeHttpClient()
            ..queueResponse(
              host: 'marine-api.open-meteo.com',
              body: 'not json',
            );

          final service = MarineBatchService(client);

          await expectLater(
            () => service.fetchBatch(coordinates),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'given a location entry with no current field, fetchBatch -> throws a clear error',
        () async {
          final client = FakeHttpClient()
            ..queueJson(
              host: 'marine-api.open-meteo.com',
              json: [
                {'latitude': 38.3, 'longitude': 26.3},
                {'latitude': 39.1, 'longitude': 27.0, 'current': {}},
              ],
            );

          final service = MarineBatchService(client);

          await expectLater(
            () => service.fetchBatch(coordinates),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'given an empty coordinate list, fetchBatch -> returns an empty map without calling the client',
        () async {
          final client = FakeHttpClient();
          final service = MarineBatchService(client);

          final result = await service.fetchBatch(const []);

          expect(result, isEmpty);
          expect(client.requests, isEmpty);
        },
      );

      test(
        'given a single-location response as a JSON object (not a list), fetchBatch -> maps the one coordinate',
        () async {
          final client = FakeHttpClient()
            ..queueJson(
              host: 'marine-api.open-meteo.com',
              json: {
                'latitude': 38.3,
                'longitude': 26.3,
                'current': {
                  'wave_height': 0.8,
                  'sea_surface_temperature': 23.1,
                },
              },
            );

          final service = MarineBatchService(client);
          final result = await service.fetchBatch(const [LatLng(38.3, 26.3)]);

          expect(result['38.3,26.3']!.waveHeight, 0.8);
          expect(result['38.3,26.3']!.seaSurfaceTemperature, 23.1);
        },
      );

      test(
        'given a response that is neither a list nor an object, fetchBatch -> throws a clear error',
        () async {
          final client = FakeHttpClient()
            ..queueJson(host: 'marine-api.open-meteo.com', json: 42);

          final service = MarineBatchService(client);

          await expectLater(
            () => service.fetchBatch(coordinates),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('expected a list of locations'),
              ),
            ),
          );
        },
      );

      test(
        'given a location entry that is not a JSON object, fetchBatch -> throws a clear error',
        () async {
          final client = FakeHttpClient()
            ..queueJson(
              host: 'marine-api.open-meteo.com',
              json: [
                'not an object',
                {
                  'latitude': 39.1,
                  'longitude': 27.0,
                  'current': {
                    'wave_height': 1.0,
                    'sea_surface_temperature': 22.0,
                  },
                },
              ],
            );

          final service = MarineBatchService(client);

          await expectLater(
            () => service.fetchBatch(coordinates),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('location entry is not an object'),
              ),
            ),
          );
        },
      );

      test(
        'given a repeat call within 1 hour, fetchBatch -> does not re-invoke the client',
        () async {
          final client = FakeHttpClient()
            ..queueJson(
              host: 'marine-api.open-meteo.com',
              json: multiLocationFixture(),
            );

          var now = DateTime(2026, 1, 1, 12);
          final service = MarineBatchService(client, now: () => now);

          final first = await service.fetchBatch(coordinates);
          expect(client.requests, hasLength(1));

          now = now.add(const Duration(minutes: 30));
          final second = await service.fetchBatch(coordinates);

          expect(client.requests, hasLength(1));
          expect(
            second['38.3,26.3']!.waveHeight,
            first['38.3,26.3']!.waveHeight,
          );
        },
      );

      test(
        'given a call after cache expiry, fetchBatch -> re-invokes the client',
        () async {
          final client = FakeHttpClient()
            ..queueJson(
              host: 'marine-api.open-meteo.com',
              json: multiLocationFixture(),
            );

          var now = DateTime(2026, 1, 1, 12);
          final service = MarineBatchService(client, now: () => now);

          await service.fetchBatch(coordinates);
          expect(client.requests, hasLength(1));

          now = now.add(const Duration(hours: 1, minutes: 1));
          await service.fetchBatch(coordinates);

          expect(client.requests, hasLength(2));
        },
      );
    });
  });
}
