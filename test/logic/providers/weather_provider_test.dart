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

    test('sets error, and clears loading, when the repository throws', () async {
      final provider = WeatherProvider(
        _FakeWeatherRepository(error: Exception('Network Error: boom')),
      );

      await provider.fetchData(38.3, 26.3);

      expect(provider.isLoading, false);
      expect(provider.currentData, isNull);
      expect(provider.error, contains('boom'));
    });

    test(
      'disposing while a fetch is in flight does not throw once that '
      'fetch later completes',
      () async {
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
      },
    );
  });
}
