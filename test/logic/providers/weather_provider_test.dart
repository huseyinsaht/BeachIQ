import 'dart:async';

import 'package:beachiq/data/models/weather_condition.dart';
import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:beachiq/logic/providers/weather_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWeatherRepository extends WeatherRepository {
  _FakeWeatherRepository({this.data, this.error, this.whenReady})
    : super(WeatherApiService());

  final WeatherCondition? data;
  final Object? error;

  /// When set, [getWeatherData] waits on this future before resolving —
  /// lets a test control exactly when an in-flight fetch completes.
  final Future<void>? whenReady;

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async {
    if (whenReady != null) await whenReady;
    if (error != null) {
      throw error!;
    }
    return data!;
  }
}

/// A [WeatherRepository] whose calls each get their own [Completer], kept
/// in [calls] in call order, so a test can resolve them in a different
/// order than they were made (#213's "last tap wins" guarantee).
class _SequentialWeatherRepository extends WeatherRepository {
  _SequentialWeatherRepository() : super(WeatherApiService());

  final List<Completer<WeatherCondition>> calls = [];

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) {
    final completer = Completer<WeatherCondition>();
    calls.add(completer);
    return completer.future;
  }
}

WeatherCondition _condition(double temperature) =>
    WeatherCondition(temperature: temperature, windSpeed: 10, weatherCode: 1);

void main() {
  group('WeatherProvider.fetchData', () {
    test('starts in a non-loading state with no data or error', () {
      final provider = WeatherProvider(_FakeWeatherRepository());

      expect(provider.isLoading, false);
      expect(provider.currentData, isNull);
      expect(provider.error, isNull);
    });

    test('sets loading, then data, on a successful fetch', () async {
      final condition = WeatherCondition(
        temperature: 27.5,
        windSpeed: 12.0,
        weatherCode: 1,
      );
      final provider = WeatherProvider(_FakeWeatherRepository(data: condition));

      final future = provider.fetchData(38.3, 26.3);
      expect(provider.isLoading, true);

      await future;

      expect(provider.isLoading, false);
      expect(provider.currentData, condition);
      expect(provider.error, isNull);
    });

    test(
      'sets error, and clears loading, when the repository throws',
      () async {
        final provider = WeatherProvider(
          _FakeWeatherRepository(error: Exception('Network Error: boom')),
        );

        await provider.fetchData(38.3, 26.3);

        expect(provider.isLoading, false);
        expect(provider.currentData, isNull);
        expect(provider.error, contains('boom'));
      },
    );

    test('disposing while a fetch is in flight does not throw once that '
        'fetch later completes', () async {
      final completer = Completer<void>();
      final condition = WeatherCondition(
        temperature: 27.5,
        windSpeed: 12.0,
        weatherCode: 1,
      );
      final provider = WeatherProvider(
        _FakeWeatherRepository(data: condition, whenReady: completer.future),
      );

      final future = provider.fetchData(38.3, 26.3);
      provider.dispose();

      completer.complete();
      await expectLater(future, completes);
    });

    test('given a different location than the currently loaded data, '
        'fetchData clears currentData and sets isLoading immediately, '
        'synchronously before the network call resolves (#213)', () async {
      final repository = _SequentialWeatherRepository();
      final provider = WeatherProvider(repository);

      // First load, for location A.
      final first = provider.fetchData(10, 10);
      repository.calls[0].complete(_condition(27));
      await first;
      expect(provider.currentData, isNotNull);
      expect(provider.currentData!.temperature, 27);

      // A pick for a DIFFERENT location (B) must clear the old data and
      // flip isLoading *before* its own network call has resolved — the
      // old place's values must never be visible under the new pick.
      final second = provider.fetchData(20, 20);
      expect(provider.currentData, isNull);
      expect(provider.isLoading, isTrue);

      repository.calls[1].complete(_condition(31));
      await second;
      expect(provider.currentData!.temperature, 31);
    });

    test('given the same location as the currently loaded data (a '
        'pull-to-refresh), fetchData keeps currentData visible while it '
        'reloads (#213)', () async {
      final repository = _SequentialWeatherRepository();
      final provider = WeatherProvider(repository);

      final first = provider.fetchData(10, 10);
      repository.calls[0].complete(_condition(27));
      await first;

      final second = provider.fetchData(10, 10);
      // Same (lat, lon) as the already-loaded data: still shown while
      // the refresh is in flight, not cleared like a new pick.
      expect(provider.currentData, isNotNull);
      expect(provider.currentData!.temperature, 27);
      expect(provider.isLoading, isTrue);

      repository.calls[1].complete(_condition(29));
      await second;
      expect(provider.currentData!.temperature, 29);
    });

    test(
      'given two overlapping fetchData calls for different locations that '
      'resolve out of order, the result of the most recently started call '
      '("last tap wins") wins, even though it resolved first (#213)',
      () async {
        final repository = _SequentialWeatherRepository();
        final provider = WeatherProvider(repository);

        final older = provider.fetchData(10, 10); // tap A
        final newer = provider.fetchData(20, 20); // tap B, right after

        // Resolve the NEWER request (B) first.
        repository.calls[1].complete(_condition(31));
        await newer;
        expect(provider.currentData!.temperature, 31);
        expect(provider.isLoading, isFalse);

        // The OLDER request (A) resolving late must be discarded entirely:
        // it must not overwrite B's already-displayed data nor flip
        // isLoading back to true.
        repository.calls[0].complete(_condition(27));
        await older;
        expect(provider.currentData!.temperature, 31);
        expect(provider.isLoading, isFalse);
      },
    );

    test('given a fetch for a new location that fails, currentData stays '
        'null (the error state is for the new place, never the previous '
        "place's stale data) (#213)", () async {
      final repository = _SequentialWeatherRepository();
      final provider = WeatherProvider(repository);

      final first = provider.fetchData(10, 10);
      repository.calls[0].complete(_condition(27));
      await first;
      expect(provider.currentData, isNotNull);

      final second = provider.fetchData(20, 20);
      expect(provider.currentData, isNull); // cleared immediately
      repository.calls[1].completeError(Exception('boom'));
      await second;

      expect(provider.currentData, isNull);
      expect(provider.error, contains('boom'));
    });

    test(
      'given a same-location refresh that fails, currentData from the '
      'previous successful fetch is kept rather than cleared (#213)',
      () async {
        final repository = _SequentialWeatherRepository();
        final provider = WeatherProvider(repository);

        final first = provider.fetchData(10, 10);
        repository.calls[0].complete(_condition(27));
        await first;

        final second = provider.fetchData(10, 10);
        repository.calls[1].completeError(Exception('boom'));
        await second;

        expect(provider.currentData, isNotNull);
        expect(provider.currentData!.temperature, 27);
        expect(provider.error, contains('boom'));
      },
    );

    test('lastLat/lastLon are null before the first fetch, then track the '
        'most recent call\'s coordinates', () async {
      final condition = WeatherCondition(
        temperature: 27.5,
        windSpeed: 12.0,
        weatherCode: 1,
      );
      final provider = WeatherProvider(_FakeWeatherRepository(data: condition));

      expect(provider.lastLat, isNull);
      expect(provider.lastLon, isNull);

      await provider.fetchData(38.3, 26.3);
      expect(provider.lastLat, 38.3);
      expect(provider.lastLon, 26.3);

      await provider.fetchData(40.0, 29.0);
      expect(provider.lastLat, 40.0);
      expect(provider.lastLon, 29.0);
    });
  });
}
