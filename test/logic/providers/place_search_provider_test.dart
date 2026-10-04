import 'dart:async';
import 'dart:convert';

import 'package:beachiq/data/services/geocoding_service.dart';
import 'package:beachiq/logic/providers/place_search_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _debounce = Duration(milliseconds: 20);
const _settle = Duration(milliseconds: 100);

/// A fake [http.Client] whose response (or thrown error) is produced by a
/// callback, counting how many requests were made. Mirrors the
/// `_FakeClient` used by `nearby_beaches_provider_test.dart`.
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

String _resultsFixture(List<Map<String, Object?>> places) {
  return json.encode({
    'results': [
      for (final p in places)
        {
          'name': p['name'],
          'latitude': p['latitude'],
          'longitude': p['longitude'],
        },
    ],
  });
}

void main() {
  group('PlaceSearchProvider.search', () {
    test('rapid keystrokes only trigger one request after the debounce '
        'settles', () async {
      final client = _FakeClient((request) async {
        return http.Response(_resultsFixture([]), 200);
      });
      final provider = PlaceSearchProvider(
        GeocodingService(client),
        debounceDuration: _debounce,
      );

      for (final query in ['C', 'Ce', 'Ces', 'Cesm', 'Cesme']) {
        provider.search(query);
        await Future.delayed(const Duration(milliseconds: 5));
      }

      await Future.delayed(_settle);

      expect(client.callCount, 1);
    });

    test('resolves to loaded state with results on success', () async {
      final client = _FakeClient((request) async {
        return http.Response(
          _resultsFixture([
            {'name': 'Cesme', 'latitude': 38.32, 'longitude': 26.33},
          ]),
          200,
        );
      });
      final provider = PlaceSearchProvider(
        GeocodingService(client),
        debounceDuration: _debounce,
      );

      provider.search('Cesme');
      await Future.delayed(_settle);

      expect(provider.status, PlaceSearchStatus.loaded);
      expect(provider.results, hasLength(1));
      expect(provider.error, isNull);
    });

    test(
      'resolves to an explicit empty state when there are no results',
      () async {
        final client = _FakeClient((request) async {
          return http.Response(_resultsFixture([]), 200);
        });
        final provider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: _debounce,
        );

        provider.search('Nowhereville');
        await Future.delayed(_settle);

        expect(provider.status, PlaceSearchStatus.empty);
        expect(provider.results, isEmpty);
      },
    );

    test('resolves to an error state on failure, never throwing', () async {
      final client = _FakeClient((request) async {
        return http.Response('Service Unavailable', 503);
      });
      final provider = PlaceSearchProvider(
        GeocodingService(client),
        debounceDuration: _debounce,
      );

      provider.search('Cesme');
      await Future.delayed(_settle);

      expect(provider.status, PlaceSearchStatus.error);
      expect(provider.error, isNotNull);
      expect(provider.results, isEmpty);
    });

    test(
      'a blank query clears results immediately without a network call',
      () async {
        final client = _FakeClient((request) async {
          return http.Response(
            _resultsFixture([
              {'name': 'Cesme', 'latitude': 38.32, 'longitude': 26.33},
            ]),
            200,
          );
        });
        final provider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: _debounce,
        );

        provider.search('Cesme');
        await Future.delayed(_settle);
        expect(provider.results, hasLength(1));

        provider.search('   ');

        expect(provider.status, PlaceSearchStatus.idle);
        expect(provider.results, isEmpty);
        expect(client.callCount, 1);
      },
    );

    test('an earlier search that resolves after a later one does not '
        'overwrite its result', () async {
      final completerA = Completer<http.Response>();
      final completerB = Completer<http.Response>();
      final client = _FakeClient((request) async {
        final query = request.url.queryParameters['name'] ?? '';
        return query == 'first query' ? completerA.future : completerB.future;
      });
      final provider = PlaceSearchProvider(
        GeocodingService(client),
        debounceDuration: _debounce,
      );

      // First search: debounce settles and the request starts, but it is
      // left hanging on completerA.
      provider.search('first query');
      await Future.delayed(_debounce + const Duration(milliseconds: 20));

      // Second, later search: its own request starts and hangs on
      // completerB.
      provider.search('second query');
      await Future.delayed(_debounce + const Duration(milliseconds: 20));

      // The later (second) request resolves first...
      completerB.complete(
        http.Response(
          _resultsFixture([
            {'name': 'Fresh', 'latitude': 1.0, 'longitude': 2.0},
          ]),
          200,
        ),
      );
      await Future.delayed(_settle);

      // ...then the earlier (first) request resolves. Its result must be
      // discarded as stale, not overwrite the fresher one.
      completerA.complete(
        http.Response(
          _resultsFixture([
            {'name': 'Stale', 'latitude': 3.0, 'longitude': 4.0},
          ]),
          200,
        ),
      );
      await Future.delayed(_settle);

      expect(provider.results, hasLength(1));
      expect(provider.results.first.name, 'Fresh');
    });
  });
}
