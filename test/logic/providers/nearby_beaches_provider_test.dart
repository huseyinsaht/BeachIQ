import 'dart:async';
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
    test(
      'cache hit resolves to loaded state without calling Overpass',
      () async {
        final cache = await _emptyCache();
        final cachedBeach = Beach(
          name: 'Cached Beach',
          city: 'City',
          latitude: 38.30,
          longitude: 26.30,
        );
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
        expect(
          provider.seaConditionFor(provider.beaches.single)?.waveHeight,
          1.1,
        );
      },
    );

    test(
      'cache miss calls Overpass once, then marine batch once, and merges results',
      () async {
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

        final first = provider.beaches.firstWhere(
          (b) => b.name == 'First Beach',
        );
        final second = provider.beaches.firstWhere(
          (b) => b.name == 'Second Beach',
        );
        expect(provider.seaConditionFor(first)?.waveHeight, 0.5);
        expect(provider.seaConditionFor(second)?.waveHeight, 0.8);
      },
    );

    test(
      'rapid repeated picks only trigger one fetch after the debounce settles',
      () async {
        final cache = await _emptyCache();

        final overpassClient = _FakeClient((request) async {
          return http.Response(_overpassFixture([]), 200);
        });
        final overpassService = OverpassService(overpassClient);
        final marineBatchService = MarineBatchService(
          _FakeClient(
            (request) async => http.Response(_marineFixture([]), 200),
          ),
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
      },
    );

    test(
      'zero beaches found within radius sets an explicit empty state',
      () async {
        final cache = await _emptyCache();

        final overpassService = OverpassService(
          _FakeClient(
            (request) async => http.Response(_overpassFixture([]), 200),
          ),
        );
        final marineBatchService = MarineBatchService(
          _FakeClient(
            (request) async => http.Response(_marineFixture([]), 200),
          ),
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
      },
    );

    test(
      'a fetch failure with no fallback data available sets the error state',
      () async {
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
      },
    );

    test(
      'a fetch failure with fallback data available resolves to loaded, not error',
      () async {
        final cache = await _emptyCache();

        final overpassService = OverpassService(
          _FakeClient((request) async => http.Response('Server error', 500)),
          maxAttemptsPerEndpoint: 1,
        );
        final marineBatchService = MarineBatchService(
          _FakeClient(
            (request) async => http.Response(_marineFixture([]), 200),
          ),
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
      },
    );
  });

  group('NearbyBeachesProvider - stale requests, failures, and disposal', () {
    test(
      'an earlier pick that resolves after a later one does not overwrite its result',
      () async {
        final cache = await _emptyCache();

        final completerA = Completer<http.Response>();
        final completerB = Completer<http.Response>();
        final overpassClient = _FakeClient((request) async {
          final data = request.bodyFields['data'] ?? '';
          // The query embeds the requested lat/lon (fixed to 6 decimals), so
          // this tells the two picks' in-flight requests apart.
          if (data.contains('50.100000')) {
            return completerA.future;
          }
          return completerB.future;
        });
        final overpassService = OverpassService(
          overpassClient,
          endpoints: ['https://example.com/api'],
        );

        final marineBatchService = MarineBatchService(
          _FakeClient(
            (request) async => http.Response(
              _marineFixture([
                {'waveHeight': 2.0, 'seaSurfaceTemperature': 26.0},
              ]),
              200,
            ),
          ),
        );

        final provider = NearbyBeachesProvider(
          overpassService,
          cache,
          marineBatchService,
          debounceDuration: _debounce,
        );

        // First pick: debounce settles and the fetch starts, but its Overpass
        // call is left hanging on completerA.
        provider.pickLocation(const LatLng(50.10, 10.10));
        await Future.delayed(_debounce + const Duration(milliseconds: 20));

        // Second, later pick: its own fetch starts and hangs on completerB.
        provider.pickLocation(const LatLng(60.20, 20.20));
        await Future.delayed(_debounce + const Duration(milliseconds: 20));

        // The later pick resolves first.
        completerB.complete(
          http.Response(
            _overpassFixture([
              {'id': 2, 'lat': 60.20, 'lon': 20.20, 'name': 'Beach B'},
            ]),
            200,
          ),
        );
        await Future.delayed(_settle);

        expect(provider.status, NearbyBeachesStatus.loaded);
        expect(provider.beaches, hasLength(1));
        expect(provider.beaches.single.name, 'Beach B');

        // The earlier, stale pick resolves afterwards and must be discarded.
        completerA.complete(
          http.Response(
            _overpassFixture([
              {'id': 1, 'lat': 50.10, 'lon': 10.10, 'name': 'Beach A'},
            ]),
            200,
          ),
        );
        await Future.delayed(_settle);

        expect(provider.status, NearbyBeachesStatus.loaded);
        expect(provider.beaches, hasLength(1));
        expect(provider.beaches.single.name, 'Beach B');
      },
    );

    test(
      'a stale cache entry triggers a background refresh, showing the stale data '
      'immediately and swallowing a refresh failure',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        var clock = DateTime(2024, 1, 1);
        final cache = BeachCache(prefs, now: () => clock);

        final staleBeach = Beach(
          name: 'Stale Beach',
          city: 'City',
          latitude: 40.00,
          longitude: 27.00,
        );
        await cache.put(40.00, 27.00, [staleBeach]);

        // Move the clock past the cache's TTL so the entry above is stale.
        clock = clock.add(const Duration(days: 8));

        final overpassClient = _FakeClient((request) async {
          throw Exception('overpass refresh failed');
        });
        final overpassService = OverpassService(
          overpassClient,
          endpoints: ['https://example.com/api'],
        );

        final marineBatchService = MarineBatchService(
          _FakeClient(
            (request) async => http.Response(
              _marineFixture([
                {'waveHeight': 0.9, 'seaSurfaceTemperature': 25.0},
              ]),
              200,
            ),
          ),
        );

        final provider = NearbyBeachesProvider(
          overpassService,
          cache,
          marineBatchService,
          debounceDuration: _debounce,
        );

        provider.pickLocation(const LatLng(40.00, 27.00));
        await Future.delayed(_settle);

        // The stale-but-present cached data is shown right away, without
        // waiting on the background refresh.
        expect(provider.status, NearbyBeachesStatus.loaded);
        expect(provider.error, isNull);
        expect(provider.beaches, hasLength(1));
        expect(provider.beaches.single.name, 'Stale Beach');
        expect(
          provider.seaConditionFor(provider.beaches.single)?.waveHeight,
          0.9,
        );

        // Give the unawaited background refresh (which throws) time to run.
        await Future.delayed(_settle);

        expect(overpassClient.callCount, 1);
        // The refresh failure must not crash or flip the state to error.
        expect(provider.status, NearbyBeachesStatus.loaded);
        expect(provider.error, isNull);
        expect(provider.beaches.single.name, 'Stale Beach');
      },
    );

    test(
      'a MarineBatchService failure is swallowed: status is loaded and seaConditionFor is null',
      () async {
        final cache = await _emptyCache();

        final overpassService = OverpassService(
          _FakeClient(
            (request) async => http.Response(
              _overpassFixture([
                {
                  'id': 1,
                  'lat': 10.00,
                  'lon': 15.00,
                  'name': 'Marine Fail Beach',
                },
              ]),
              200,
            ),
          ),
          endpoints: ['https://example.com/api'],
        );
        final marineBatchService = MarineBatchService(
          _FakeClient((request) async {
            throw Exception('marine batch down');
          }),
        );

        final provider = NearbyBeachesProvider(
          overpassService,
          cache,
          marineBatchService,
          debounceDuration: _debounce,
        );

        provider.pickLocation(const LatLng(10.00, 15.00));
        await Future.delayed(_settle);

        expect(provider.status, NearbyBeachesStatus.loaded);
        expect(provider.error, isNull);
        expect(provider.beaches, hasLength(1));
        expect(provider.seaConditionFor(provider.beaches.single), isNull);
      },
    );

    test(
      'seaConditionFor distinguishes a present-but-null batch entry from missing data',
      () async {
        final cache = await _emptyCache();

        final overpassService = OverpassService(
          _FakeClient(
            (request) async => http.Response(
              _overpassFixture([
                {'id': 1, 'lat': 11.00, 'lon': 16.00, 'name': 'Has Data Beach'},
                {
                  'id': 2,
                  'lat': 11.50,
                  'lon': 16.50,
                  'name': 'Null Data Beach',
                },
              ]),
              200,
            ),
          ),
          endpoints: ['https://example.com/api'],
        );
        final marineBatchService = MarineBatchService(
          _FakeClient(
            (request) async => http.Response(
              _marineFixture([
                {'waveHeight': 1.4, 'seaSurfaceTemperature': 24.5},
                // Open-Meteo can return an entry whose 'current' object is
                // present but whose actual readings are null.
                {'waveHeight': null, 'seaSurfaceTemperature': null},
              ]),
              200,
            ),
          ),
        );

        final provider = NearbyBeachesProvider(
          overpassService,
          cache,
          marineBatchService,
          debounceDuration: _debounce,
        );

        provider.pickLocation(const LatLng(11.00, 16.00));
        await Future.delayed(_settle);

        expect(provider.status, NearbyBeachesStatus.loaded);
        expect(provider.beaches, hasLength(2));

        final hasData = provider.beaches.firstWhere(
          (b) => b.name == 'Has Data Beach',
        );
        final nullData = provider.beaches.firstWhere(
          (b) => b.name == 'Null Data Beach',
        );

        expect(provider.seaConditionFor(hasData)?.waveHeight, 1.4);
        expect(provider.seaConditionFor(nullData), isNull);
      },
    );

    test(
      'status transitions from loading to a terminal state as pickLocation resolves',
      () async {
        final cache = await _emptyCache();

        final overpassCompleter = Completer<http.Response>();
        final overpassService = OverpassService(
          _FakeClient((request) async => overpassCompleter.future),
          endpoints: ['https://example.com/api'],
        );
        final marineBatchService = MarineBatchService(
          _FakeClient(
            (request) async => http.Response(
              _marineFixture([
                {'waveHeight': 1.0, 'seaSurfaceTemperature': 20.0},
              ]),
              200,
            ),
          ),
        );

        final provider = NearbyBeachesProvider(
          overpassService,
          cache,
          marineBatchService,
          debounceDuration: _debounce,
        );

        final statuses = <NearbyBeachesStatus>[];
        provider.addListener(() => statuses.add(provider.status));

        provider.pickLocation(const LatLng(70.0, 30.0));
        await Future.delayed(_debounce + const Duration(milliseconds: 20));

        // Synchronously (post-debounce, pre-resolve) the state is loading.
        expect(provider.status, NearbyBeachesStatus.loading);
        expect(provider.isLoading, isTrue);
        expect(statuses, isNotEmpty);
        expect(statuses.first, NearbyBeachesStatus.loading);

        overpassCompleter.complete(
          http.Response(
            _overpassFixture([
              {'id': 1, 'lat': 70.0, 'lon': 30.0, 'name': 'Transition Beach'},
            ]),
            200,
          ),
        );
        await Future.delayed(_settle);

        expect(provider.status, NearbyBeachesStatus.loaded);
        expect(provider.isLoading, isFalse);
        expect(statuses, contains(NearbyBeachesStatus.loading));
        expect(statuses.last, NearbyBeachesStatus.loaded);
      },
    );

    test(
      'disposing while a fetch is in flight does not throw once that fetch later completes',
      () async {
        final cache = await _emptyCache();

        final overpassCompleter = Completer<http.Response>();
        final overpassService = OverpassService(
          _FakeClient((request) async => overpassCompleter.future),
          endpoints: ['https://example.com/api'],
        );
        final marineBatchService = MarineBatchService(
          _FakeClient(
            (request) async => http.Response(_marineFixture([]), 200),
          ),
        );

        final provider = NearbyBeachesProvider(
          overpassService,
          cache,
          marineBatchService,
          debounceDuration: _debounce,
        );

        provider.pickLocation(const LatLng(20.0, 20.0));
        await Future.delayed(_debounce + const Duration(milliseconds: 20));
        expect(provider.status, NearbyBeachesStatus.loading);

        provider.dispose();

        // The in-flight fetch resolves after disposal; this must not throw
        // "A ChangeNotifier was used after being disposed".
        overpassCompleter.complete(
          http.Response(
            _overpassFixture([
              {'id': 1, 'lat': 20.0, 'lon': 20.0, 'name': 'Late Beach'},
            ]),
            200,
          ),
        );
        await Future.delayed(_settle);
      },
    );
  });
}
