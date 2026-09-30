import 'dart:convert';

import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:beachiq/data/services/overpass_service.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _debounce = Duration(milliseconds: 20);
const _settle = Duration(milliseconds: 100);

/// A fake [http.Client] whose response (or thrown error) is produced by a
/// callback, counting how many requests were made.
class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.Response> Function(http.Request request) _handler;
  int callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    final req = request as http.Request;
    final response = await _handler(req);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

String _overpassFixture(List<Map<String, Object?>> beaches) {
  return json.encode({
    'elements': [
      for (final b in beaches)
        {
          'type': 'way',
          'id': b['id'],
          'center': {'lat': b['lat'], 'lon': b['lon']},
          'tags': {'natural': 'beach', 'name': b['name']},
        },
    ],
  });
}

String _marineFixture(List<Map<String, Object?>> entries) {
  return json.encode([
    for (final e in entries)
      {
        'current': {
          'wave_height': e['waveHeight'],
          'sea_surface_temperature': e['seaSurfaceTemperature'],
        },
      },
  ]);
}

Future<BeachCache> _emptyCache({double fallbackRadiusKm = 100}) async {
  SharedPreferences.setMockInitialValues({});
  return BeachCache(
    await SharedPreferences.getInstance(),
    fallbackRadiusKm: fallbackRadiusKm,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NearbyBeachesProvider.pickLocation', () {
    test('cache hit resolves to loaded state without calling Overpass', () async {
      final cache = await _emptyCache();
      final cachedBeach = Beach(name: 'Cached Beach', city: 'City', latitude: 38.30, longitude: 26.30);
      await cache.put(38.30, 26.30, [cachedBeach]);

      final overpassClient = _FakeClient((request) async {
        fail('Overpass should not be called on a cache hit');
      });
      final overpassService = OverpassService(overpassClient);

      final marineClient = _FakeClient((request) async {
        return http.Response(
          _marineFixture([
            {'waveHeight': 1.1, 'seaSurfaceTemperature': 22.0},
          ]),
          200,
        );
      });
      final marineBatchService = MarineBatchService(marineClient);

      final provider = NearbyBeachesProvider(
        overpassService,
        cache,
        marineBatchService,
        debounceDuration: _debounce,
      );

      provider.pickLocation(const LatLng(38.30, 26.30));
      await Future.delayed(_settle);

      expect(overpassClient.callCount, 0);
      expect(provider.status, NearbyBeachesStatus.loaded);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.beaches, hasLength(1));
      expect(provider.beaches.single.name, 'Cached Beach');
      expect(provider.seaConditionFor(provider.beaches.single)?.waveHeight, 1.1);
    });

    test('cache miss calls Overpass once, then marine batch once, and merges results', () async {
      final cache = await _emptyCache();

      final overpassClient = _FakeClient((request) async {
        return http.Response(
          _overpassFixture([
            {'id': 1, 'lat': 38.30, 'lon': 26.30, 'name': 'First Beach'},
            {'id': 2, 'lat': 38.35, 'lon': 26.35, 'name': 'Second Beach'},
          ]),
          200,
        );
      });
      final overpassService = OverpassService(overpassClient);

      final marineClient = _FakeClient((request) async {
        return http.Response(
          _marineFixture([
            {'waveHeight': 0.5, 'seaSurfaceTemperature': 21.0},
            {'waveHeight': 0.8, 'seaSurfaceTemperature': 23.5},
          ]),
          200,
        );
      });
      final marineBatchService = MarineBatchService(marineClient);

      final provider = NearbyBeachesProvider(
        overpassService,
        cache,
        marineBatchService,
        debounceDuration: _debounce,
      );

      provider.pickLocation(const LatLng(38.30, 26.30));
      await Future.delayed(_settle);

      expect(overpassClient.callCount, 1);
      expect(marineClient.callCount, 1);
      expect(provider.status, NearbyBeachesStatus.loaded);
      expect(provider.beaches, hasLength(2));

      final first = provider.beaches.firstWhere((b) => b.name == 'First Beach');
      final second = provider.beaches.firstWhere((b) => b.name == 'Second Beach');
      expect(provider.seaConditionFor(first)?.waveHeight, 0.5);
      expect(provider.seaConditionFor(second)?.waveHeight, 0.8);
    });

    test('rapid repeated picks only trigger one fetch after the debounce settles', () async {
      final cache = await _emptyCache();

      final overpassClient = _FakeClient((request) async {
        return http.Response(_overpassFixture([]), 200);
      });
      final overpassService = OverpassService(overpassClient);
      final marineBatchService = MarineBatchService(
        _FakeClient((request) async => http.Response(_marineFixture([]), 200)),
      );

      final provider = NearbyBeachesProvider(
        overpassService,
        cache,
        marineBatchService,
        debounceDuration: _debounce,
      );

      for (var i = 0; i < 5; i++) {
        provider.pickLocation(const LatLng(38.30, 26.30));
        await Future.delayed(const Duration(milliseconds: 5));
      }

      await Future.delayed(_settle);

      expect(overpassClient.callCount, 1);
    });

    test('zero beaches found within radius sets an explicit empty state', () async {
      final cache = await _emptyCache();

      final overpassService = OverpassService(
        _FakeClient((request) async => http.Response(_overpassFixture([]), 200)),
      );
      final marineBatchService = MarineBatchService(
        _FakeClient((request) async => http.Response(_marineFixture([]), 200)),
      );

      final provider = NearbyBeachesProvider(
        overpassService,
        cache,
        marineBatchService,
        debounceDuration: _debounce,
      );

      provider.pickLocation(const LatLng(38.30, 26.30));
      await Future.delayed(_settle);

      expect(provider.status, NearbyBeachesStatus.empty);
      expect(provider.isEmpty, isTrue);
      expect(provider.error, isNull);
      expect(provider.beaches, isEmpty);
    });

    test('a fetch failure with no fallback data available sets the error state', () async {
      // A tiny fallback radius guarantees the static beach list has nothing
      // close enough to fall back to, so the failure has nothing to show.
      final cache = await _emptyCache(fallbackRadiusKm: 0.001);

      final overpassService = OverpassService(
        _FakeClient((request) async => http.Response('Server error', 500)),
        maxAttemptsPerEndpoint: 1,
      );
      final marineBatchService = MarineBatchService(
        _FakeClient((request) async {
          fail('marine batch should not be called when there are no beaches');
        }),
      );

      final provider = NearbyBeachesProvider(
        overpassService,
        cache,
        marineBatchService,
        debounceDuration: _debounce,
      );

      // Middle of the ocean: no static fallback beach is anywhere nearby.
      provider.pickLocation(const LatLng(0, 0));
      await Future.delayed(_settle);

      expect(provider.status, NearbyBeachesStatus.error);
      expect(provider.error, isNotNull);
      expect(provider.beaches, isEmpty);
    });

    test('a fetch failure with fallback data available resolves to loaded, not error', () async {
      final cache = await _emptyCache();

      final overpassService = OverpassService(
        _FakeClient((request) async => http.Response('Server error', 500)),
        maxAttemptsPerEndpoint: 1,
      );
      final marineBatchService = MarineBatchService(
        _FakeClient((request) async => http.Response(_marineFixture([]), 200)),
      );

      final provider = NearbyBeachesProvider(
        overpassService,
        cache,
        marineBatchService,
        debounceDuration: _debounce,
      );

      // Close to Konyaaltı Plajı in the static fallback list.
      provider.pickLocation(const LatLng(36.90, 30.65));
      await Future.delayed(_settle);

      expect(provider.status, NearbyBeachesStatus.loaded);
      expect(provider.error, isNull);
      expect(provider.beaches, isNotEmpty);
    });
  });
}
