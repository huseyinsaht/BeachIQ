import 'dart:async';

import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMarineRepository extends MarineRepository {
  _FakeMarineRepository({this.data, this.error, this.whenReady})
    : super(MarineApiService());

  final SeaCondition? data;
  final Object? error;

  /// When set, [getMarineData] waits on this future before resolving —
  /// lets a test control exactly when an in-flight fetch completes.
  final Future<void>? whenReady;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    if (whenReady != null) await whenReady;
    if (error != null) {
      throw error!;
    }
    return data!;
  }
}

void main() {
  group('MarineProvider.fetchData', () {
    test('starts in a non-loading state with no data or error', () {
      final provider = MarineProvider(_FakeMarineRepository());

      expect(provider.isLoading, false);
      expect(provider.currentData, isNull);
      expect(provider.error, isNull);
    });

    test('sets loading, then data, on a successful fetch', () async {
      final condition = SeaCondition(
        waveHeight: 0.8,
        waveDirection: 180,
        wavePeriod: 6,
        seaSurfaceTemperature: 23.5,
      );
      final provider = MarineProvider(_FakeMarineRepository(data: condition));

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
        final provider = MarineProvider(
          _FakeMarineRepository(error: Exception('Network Error: boom')),
        );

        await provider.fetchData(38.3, 26.3);

        expect(provider.isLoading, false);
        expect(provider.currentData, isNull);
        expect(provider.error, contains('boom'));
      },
    );

    test('notifies listeners on both the loading and settled edges', () async {
      final condition = SeaCondition(
        waveHeight: 0.3,
        waveDirection: 45,
        wavePeriod: 4,
        seaSurfaceTemperature: 21,
      );
      final provider = MarineProvider(_FakeMarineRepository(data: condition));
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.fetchData(38.3, 26.3);

      // Once for entering the loading state, once for the resolved state.
      expect(notifyCount, 2);
    });

    test(
      'disposing while a fetch is in flight does not throw once that '
      'fetch later completes',
      () async {
        final completer = Completer<void>();
        final condition = SeaCondition(
          waveHeight: 0.8,
          waveDirection: 180,
          wavePeriod: 6,
          seaSurfaceTemperature: 23.5,
        );
        final provider = MarineProvider(
          _FakeMarineRepository(data: condition, whenReady: completer.future),
        );

        final future = provider.fetchData(38.3, 26.3);
        provider.dispose();

        completer.complete();
        await expectLater(future, completes);
      },
    );
  });
}
