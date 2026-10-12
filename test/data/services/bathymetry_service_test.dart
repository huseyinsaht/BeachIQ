import 'package:beachiq/data/services/bathymetry_service.dart';
import 'package:beachiq/data/services/depth_cache.dart';
import 'package:beachiq/logic/transect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_http_client.dart';

const _host = 'ows.emodnet-bathymetry.eu';

Object _validDepthFixture(double grayIndex) => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'id': '',
      'geometry': null,
      'properties': {'Depth': grayIndex},
    },
  ],
};

const Object _noFeatureFixture = {'type': 'FeatureCollection', 'features': []};

/// A beach with geometry + amenities, so [seawardTransectFor] can derive a
/// transect from it (see `transect_test.dart` for the geometry/amenity
/// heuristic itself).
final _transectableBeach = aBeach(
  geometry: const [LatLng(36.900, 30.650), LatLng(36.902, 30.652)],
  amenities: [anAmenity(position: const LatLng(36.890, 30.640))],
);

void main() {
  group('BathymetryService.fetchProfile', () {
    test('given a beach with no geometry, fetchProfile -> returns unavailable '
        'without making any request', () async {
      final client = FakeHttpClient();
      final service = BathymetryService(client);
      final beach = aBeach(geometry: null);

      final result = await service.fetchProfile(beach);

      expect(result.available, isFalse);
      expect(result.samples, isEmpty);
      expect(client.requests, isEmpty);
    });

    test(
      'given a valid transect, fetchProfile -> issues one request per '
      'transect point (up to 5) and returns their parsed depths in order',
      () async {
        final client = FakeHttpClient()
          ..queueJson(
            host: _host,
            json: _validDepthFixture(-0.3),
            consumeOnce: true,
          )
          ..queueJson(
            host: _host,
            json: _validDepthFixture(-1.0),
            consumeOnce: true,
          )
          ..queueJson(
            host: _host,
            json: _validDepthFixture(-1.8),
            consumeOnce: true,
          )
          ..queueJson(
            host: _host,
            json: _validDepthFixture(-2.6),
            consumeOnce: true,
          )
          ..queueJson(
            host: _host,
            json: _validDepthFixture(-3.4),
            consumeOnce: true,
          );
        final service = BathymetryService(client);

        final result = await service.fetchProfile(_transectableBeach);

        expect(
          client.requests,
          hasLength(defaultTransectDistancesMeters.length),
        );
        expect(result.available, isTrue);
        expect(
          result.samples.map((s) => s.distanceMeters).toList(),
          defaultTransectDistancesMeters,
        );
        expect(result.samples.map((s) => s.depthMeters).toList(), [
          0.3,
          1.0,
          1.8,
          2.6,
          3.4,
        ]);
      },
    );

    test('given every request targets the configured layer, fetchProfile -> '
        'sends GetFeatureInfo with the EMODnet layer name', () async {
      final client = FakeHttpClient()
        ..queueJson(host: _host, json: _validDepthFixture(-1.0));
      final service = BathymetryService(client);

      await service.fetchProfile(_transectableBeach);

      for (final request in client.requests) {
        expect(request.url.queryParameters['REQUEST'], 'GetFeatureInfo');
        expect(
          request.url.queryParameters['LAYERS'],
          BathymetryService.defaultLayer,
        );
      }
    });

    test('given the default endpoint, defaultBaseUrl/defaultLayer -> are the '
        'OGC WMS host and the depth layer (not the WMTS tile host, which '
        'answers 403)', () {
      final uri = Uri.parse(BathymetryService.defaultBaseUrl);

      expect(uri.host, 'ows.emodnet-bathymetry.eu');
      expect(uri.path, '/wms');
      expect(BathymetryService.defaultLayer, 'emodnet:mean');
    });

    test('given the real emodnet:mean response shape (a Depth property, an '
        'empty feature list outside coverage), fetchProfile -> parses the '
        'depth and treats no feature as unavailable', () async {
      final client = FakeHttpClient()
        ..queueJson(host: _host, json: _validDepthFixture(-8.19921875));
      final service = BathymetryService(client);

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.available, isTrue);
      expect(result.samples.first.depthMeters, closeTo(8.19921875, 1e-9));
    });

    test('given every request, fetchProfile -> sends a User-Agent header '
        'identifying the app', () async {
      final client = FakeHttpClient()
        ..queueJson(host: _host, json: _validDepthFixture(-1.0));
      final service = BathymetryService(client);

      await service.fetchProfile(_transectableBeach);

      final userAgent = client.requests.first.headers['User-Agent'];
      expect(userAgent, isNotNull);
      expect(userAgent, contains('BeachIQ'));
    });

    test('given a land cell (no GetFeatureInfo feature) mixed with valid '
        'depths, fetchProfile -> that sample is null, never 0', () async {
      final client = FakeHttpClient()
        ..queueJson(host: _host, json: _noFeatureFixture, consumeOnce: true)
        ..queueJson(host: _host, json: _validDepthFixture(-1.0));
      final service = BathymetryService(client);

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.available, isTrue);
      expect(result.samples.first.depthMeters, isNull);
      expect(result.samples.first.distanceMeters, 0);
      expect(result.samples.skip(1).every((s) => s.depthMeters == 1.0), isTrue);
    });

    test('given a land cell reported as a positive elevation, fetchProfile -> '
        'that sample is null, never a negative-of-a-positive depth', () async {
      final client = FakeHttpClient()
        ..queueJson(
          host: _host,
          json: _validDepthFixture(12.0),
          consumeOnce: true,
        )
        ..queueJson(host: _host, json: _validDepthFixture(-1.0));
      final service = BathymetryService(client);

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.samples.first.depthMeters, isNull);
    });

    test('given a GRAY_INDEX at a common NoData sentinel magnitude, '
        'fetchProfile -> that sample is null', () async {
      final client = FakeHttpClient()
        ..queueJson(
          host: _host,
          json: _validDepthFixture(-9999),
          consumeOnce: true,
        )
        ..queueJson(host: _host, json: _validDepthFixture(-1.0));
      final service = BathymetryService(client);

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.samples.first.depthMeters, isNull);
    });

    test(
      'given a malformed JSON response for one point mixed with valid '
      'responses, fetchProfile -> that sample is null, the rest unaffected',
      () async {
        final client = FakeHttpClient()
          ..queueResponse(
            host: _host,
            body: 'not valid json {',
            consumeOnce: true,
          )
          ..queueJson(host: _host, json: _validDepthFixture(-1.5));
        final service = BathymetryService(client);

        final result = await service.fetchProfile(_transectableBeach);

        expect(result.available, isTrue);
        expect(result.samples.first.depthMeters, isNull);
        expect(
          result.samples.skip(1).every((s) => s.depthMeters == 1.5),
          isTrue,
        );
      },
    );

    test('given every response is malformed JSON, fetchProfile -> returns '
        'unavailable (every sample came back unusable)', () async {
      final client = FakeHttpClient()
        ..queueResponse(host: _host, body: 'not valid json {');
      final service = BathymetryService(client);

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.available, isFalse);
      expect(result.samples, isEmpty);
    });

    test(
      'given a response that looks like JSON (starts with "{") but fails to '
      'parse, fetchProfile -> that sample is null rather than throwing',
      () async {
        final client = FakeHttpClient()
          ..queueResponse(
            host: _host,
            body: '{not actually valid json',
            consumeOnce: true,
          )
          ..queueJson(host: _host, json: _validDepthFixture(-1.0));
        final service = BathymetryService(client);

        final result = await service.fetchProfile(_transectableBeach);

        expect(result.available, isTrue);
        expect(result.samples.first.depthMeters, isNull);
        expect(
          result.samples.skip(1).every((s) => s.depthMeters == 1.0),
          isTrue,
        );
      },
    );

    test(
      'given a feature whose properties use none of the known depth key '
      'names, fetchProfile -> falls back to the first property value',
      () async {
        final client = FakeHttpClient()
          ..queueJson(
            host: _host,
            json: {
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'id': '',
                  'geometry': null,
                  'properties': {'unexpected_key': -2.5},
                },
              ],
            },
          );
        final service = BathymetryService(client);

        final result = await service.fetchProfile(_transectableBeach);

        expect(result.available, isTrue);
        expect(result.samples.every((s) => s.depthMeters == 2.5), isTrue);
      },
    );

    test('given a feature with no properties at all, fetchProfile -> that '
        'sample is null rather than throwing', () async {
      final client = FakeHttpClient()
        ..queueJson(
          host: _host,
          json: {
            'type': 'FeatureCollection',
            'features': [
              {'type': 'Feature', 'id': '', 'geometry': null, 'properties': {}},
            ],
          },
        );
      final service = BathymetryService(client);

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.available, isFalse);
    });

    test('given the depth value is encoded as a numeric string rather than a '
        'number, fetchProfile -> still parses it', () async {
      final client = FakeHttpClient()
        ..queueJson(
          host: _host,
          json: {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'id': '',
                'geometry': null,
                'properties': {'Depth': '-3.4'},
              },
            ],
          },
        );
      final service = BathymetryService(client);

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.available, isTrue);
      expect(result.samples.every((s) => s.depthMeters == 3.4), isTrue);
    });

    test('given every request returns a non-200 status, fetchProfile -> '
        'returns unavailable, never throws', () async {
      final client = FakeHttpClient()
        ..queueResponse(
          host: _host,
          body: 'Service Unavailable',
          statusCode: 503,
        );
      final service = BathymetryService(client);

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.available, isFalse);
    });

    test('given every request times out, fetchProfile -> returns unavailable, '
        'never throws', () async {
      final client = FakeHttpClient()
        ..queueJson(
          host: _host,
          json: _validDepthFixture(-1.0),
          delay: const Duration(milliseconds: 50),
        );
      final service = BathymetryService(
        client,
        timeout: const Duration(milliseconds: 5),
      );

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.available, isFalse);
    });

    test('given a plain-text GetFeatureInfo response, fetchProfile -> parses '
        'the GRAY_INDEX value out of it', () async {
      final client = FakeHttpClient()
        ..queueResponse(
          host: _host,
          body:
              "Results for FeatureType 'emodnet:mean':\n"
              '   GRAY_INDEX = -4.75',
        );
      final service = BathymetryService(client);

      final result = await service.fetchProfile(_transectableBeach);

      expect(result.available, isTrue);
      expect(result.samples.every((s) => s.depthMeters == 4.75), isTrue);
    });

    test(
      'given a plain-text response with no feature found, fetchProfile -> '
      'returns unavailable rather than crashing on the unexpected format',
      () async {
        final client = FakeHttpClient()
          ..queueResponse(
            host: _host,
            body:
                "Results for FeatureType 'emodnet:mean':\n"
                '   (no features were found)',
          );
        final service = BathymetryService(client);

        final result = await service.fetchProfile(_transectableBeach);

        expect(result.available, isFalse);
      },
    );
  });

  group('BathymetryService + DepthCache integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'given a second fetch for the same beach within the cache TTL, '
      'the depth cache -> serves it without any additional HTTP call',
      () async {
        final client = FakeHttpClient()
          ..queueJson(host: _host, json: _validDepthFixture(-1.0));
        final service = BathymetryService(client);
        final cache = DepthCache(await SharedPreferences.getInstance());

        final first = await cache.get(
          latitude: _transectableBeach.latitude,
          longitude: _transectableBeach.longitude,
          fetch: () => service.fetchProfile(_transectableBeach),
        );
        final requestCountAfterFirst = client.requests.length;

        final second = await cache.get(
          latitude: _transectableBeach.latitude,
          longitude: _transectableBeach.longitude,
          fetch: () => service.fetchProfile(_transectableBeach),
        );

        expect(requestCountAfterFirst, defaultTransectDistancesMeters.length);
        expect(client.requests.length, requestCountAfterFirst);
        expect(first.available, isTrue);
        expect(second.available, isTrue);
        expect(
          second.samples.map((s) => s.depthMeters).toList(),
          first.samples.map((s) => s.depthMeters).toList(),
        );
      },
    );
  });
}
