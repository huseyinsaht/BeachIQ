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

/// A [MarineRepository] whose calls each get their own [Completer], kept
/// in [calls] in call order, so a test can resolve them in a different
/// order than they were made (#213's "last tap wins" guarantee).
class _SequentialMarineRepository extends MarineRepository {
  _SequentialMarineRepository() : super(MarineApiService());

  final List<Completer<SeaCondition>> calls = [];

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) {
    final completer = Completer<SeaCondition>();
    calls.add(completer);
    return completer.future;
  }
}

SeaCondition _condition(double waveHeight) => SeaCondition(
  waveHeight: waveHeight,
  waveDirection: 90,
  wavePeriod: 5,
  seaSurfaceTemperature: 22,
);

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

    test('disposing while a fetch is in flight does not throw once that '
        'fetch later completes', () async {
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
    });

    test('given a different location than the currently loaded data, '
        'fetchData clears currentData and sets isLoading immediately, '
        'synchronously before the network call resolves (#213)', () async {
      final repository = _SequentialMarineRepository();
      final provider = MarineProvider(repository);

      final first = provider.fetchData(10, 10);
      repository.calls[0].complete(_condition(0.3));
      await first;
      expect(provider.currentData, isNotNull);
      expect(provider.currentData!.waveHeight, 0.3);

      // A pick for a DIFFERENT location (B) must clear the old data and
      // flip isLoading *before* its own network call has resolved — the
      // old place's values must never be visible under the new pick.
      final second = provider.fetchData(20, 20);
      expect(provider.currentData, isNull);
      expect(provider.isLoading, isTrue);

      repository.calls[1].complete(_condition(1.6));
      await second;
      expect(provider.currentData!.waveHeight, 1.6);
    });

    test('given the same location as the currently loaded data (a '
        'pull-to-refresh), fetchData keeps currentData visible while it '
        'reloads (#213)', () async {
      final repository = _SequentialMarineRepository();
      final provider = MarineProvider(repository);

      final first = provider.fetchData(10, 10);
      repository.calls[0].complete(_condition(0.3));
      await first;

      final second = provider.fetchData(10, 10);
      expect(provider.currentData, isNotNull);
      expect(provider.currentData!.waveHeight, 0.3);
      expect(provider.isLoading, isTrue);

      repository.calls[1].complete(_condition(0.5));
      await second;
      expect(provider.currentData!.waveHeight, 0.5);
    });

    test(
      'given two overlapping fetchData calls for different locations that '
      'resolve out of order, the result of the most recently started call '
      '("last tap wins") wins, even though it resolved first (#213)',
      () async {
        final repository = _SequentialMarineRepository();
        final provider = MarineProvider(repository);

        final older = provider.fetchData(10, 10); // tap A
        final newer = provider.fetchData(20, 20); // tap B, right after

        // Resolve the NEWER request (B) first.
        repository.calls[1].complete(_condition(1.6));
        await newer;
        expect(provider.currentData!.waveHeight, 1.6);
        expect(provider.isLoading, isFalse);

        // The OLDER request (A) resolving late must be discarded entirely:
        // it must not overwrite B's already-displayed data nor flip
        // isLoading back to true.
        repository.calls[0].complete(_condition(0.3));
        await older;
        expect(provider.currentData!.waveHeight, 1.6);
        expect(provider.isLoading, isFalse);
      },
    );

    test('given a fetch for a new location that fails, currentData stays '
        'null (the error state is for the new place, never the previous '
        "place's stale data) (#213)", () async {
      final repository = _SequentialMarineRepository();
      final provider = MarineProvider(repository);

      final first = provider.fetchData(10, 10);
      repository.calls[0].complete(_condition(0.3));
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
        final repository = _SequentialMarineRepository();
        final provider = MarineProvider(repository);

        final first = provider.fetchData(10, 10);
        repository.calls[0].complete(_condition(0.3));
        await first;

        final second = provider.fetchData(10, 10);
        repository.calls[1].completeError(Exception('boom'));
        await second;

        expect(provider.currentData, isNotNull);
        expect(provider.currentData!.waveHeight, 0.3);
        expect(provider.error, contains('boom'));
      },
    );

    test('lastLat/lastLon are null before the first fetch, then track the '
        'most recent call\'s coordinates', () async {
      final condition = SeaCondition(
        waveHeight: 0.8,
        waveDirection: 180,
        wavePeriod: 6,
        seaSurfaceTemperature: 23.5,
      );
      final provider = MarineProvider(_FakeMarineRepository(data: condition));

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
