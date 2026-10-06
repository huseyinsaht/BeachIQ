import 'package:beachiq/data/services/bathymetry_service.dart';
import 'package:beachiq/data/services/depth_cache.dart';
import 'package:beachiq/logic/providers/depth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_http_client.dart';

const _host = 'tiles.emodnet-bathymetry.eu';

Object _validDepthFixture(double grayIndex) => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {'GRAY_INDEX': grayIndex},
    },
  ],
};

final _transectableBeach = aBeach(
  name: 'Transectable Beach',
  geometry: const [LatLng(36.900, 30.650), LatLng(36.902, 30.652)],
  amenities: [anAmenity(position: const LatLng(36.890, 30.640))],
);

final _otherTransectableBeach = aBeach(
  name: 'Other Beach',
  latitude: 37.0,
  longitude: 31.0,
  geometry: const [LatLng(37.000, 31.000), LatLng(37.002, 31.002)],
  amenities: [anAmenity(position: const LatLng(36.990, 30.990))],
);

DepthProvider _buildProvider(FakeHttpClient client, SharedPreferences prefs) {
  return DepthProvider(BathymetryService(client), DepthCache(prefs));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DepthProvider.fetchForBeach', () {
    test('given a beach with a valid transect, fetchForBeach -> resolves an '
        'available profile and stops loading', () async {
      final client = FakeHttpClient()
        ..queueJson(host: _host, json: _validDepthFixture(-1.0));
      final provider = _buildProvider(
        client,
        await SharedPreferences.getInstance(),
      );

      await provider.fetchForBeach(_transectableBeach);

      expect(provider.isLoading, isFalse);
      expect(provider.profile?.available, isTrue);
      expect(provider.profile?.samples, isNotEmpty);
    });

    test('given a null beach, fetchForBeach -> resolves to unavailable '
        'without any HTTP request', () async {
      final client = FakeHttpClient();
      final provider = _buildProvider(
        client,
        await SharedPreferences.getInstance(),
      );

      await provider.fetchForBeach(null);

      expect(provider.profile?.available, isFalse);
      expect(provider.isLoading, isFalse);
      expect(client.requests, isEmpty);
    });

    test('given the same beach twice (by isSameBeach), fetchForBeach -> only '
        'fetches once', () async {
      final client = FakeHttpClient()
        ..queueJson(host: _host, json: _validDepthFixture(-1.0));
      final provider = _buildProvider(
        client,
        await SharedPreferences.getInstance(),
      );

      await provider.fetchForBeach(_transectableBeach);
      final requestCountAfterFirst = client.requests.length;
      await provider.fetchForBeach(_transectableBeach);

      expect(client.requests.length, requestCountAfterFirst);
    });

    test('given a different beach after a first fetch, fetchForBeach -> '
        'fetches again and replaces the profile', () async {
      final client = FakeHttpClient()
        ..queueJson(host: _host, json: _validDepthFixture(-1.0));
      final provider = _buildProvider(
        client,
        await SharedPreferences.getInstance(),
      );

      await provider.fetchForBeach(_transectableBeach);
      final requestCountAfterFirst = client.requests.length;
      await provider.fetchForBeach(_otherTransectableBeach);

      expect(client.requests.length, greaterThan(requestCountAfterFirst));
      expect(provider.profile?.available, isTrue);
    });

    test('given a beach with no usable geometry, fetchForBeach -> resolves '
        'unavailable, never throws', () async {
      final client = FakeHttpClient();
      final provider = _buildProvider(
        client,
        await SharedPreferences.getInstance(),
      );
      final beach = aBeach(geometry: null);

      await provider.fetchForBeach(beach);

      expect(provider.profile?.available, isFalse);
      expect(client.requests, isEmpty);
    });

    test('given a slower fetch for beach A superseded by a faster fetch for '
        'beach B, fetchForBeach -> B wins (last request wins, like '
        'MarineProvider)', () async {
      final client = FakeHttpClient()
        ..queueJson(
          matcher: (request) =>
              request.url.host == _host &&
              request.url.queryParameters['BBOX']!.startsWith('36.9'),
          json: _validDepthFixture(-1.0),
          delay: const Duration(milliseconds: 30),
        )
        ..queueJson(
          matcher: (request) =>
              request.url.host == _host &&
              request.url.queryParameters['BBOX']!.startsWith('37.0'),
          json: _validDepthFixture(-2.0),
        );
      final provider = _buildProvider(
        client,
        await SharedPreferences.getInstance(),
      );

      final slow = provider.fetchForBeach(_transectableBeach);
      // Give the slow fetch a moment to start before superseding it.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final fast = provider.fetchForBeach(_otherTransectableBeach);

      await Future.wait([slow, fast]);

      expect(provider.profile?.samples.first.depthMeters, 2.0);
    });
  });
}
