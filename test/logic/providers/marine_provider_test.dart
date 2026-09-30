import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMarineRepository extends MarineRepository {
  _FakeMarineRepository({this.data, this.error}) : super(MarineApiService());

  final SeaCondition? data;
  final Object? error;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
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
  });
}
