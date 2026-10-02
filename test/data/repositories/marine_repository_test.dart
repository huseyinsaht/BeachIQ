import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMarineApiService extends MarineApiService {
  _FakeMarineApiService(this.response);

  final Map<String, dynamic> response;

  @override
  Future<Map<String, dynamic>> getSeaData(double lat, double lon) async {
    return response;
  }
}

void main() {
  group('MarineRepository', () {
    group('getMarineData', () {
      test(
        'given a well-formed response, getMarineData -> parses the current fields',
        () async {
          final repository = MarineRepository(
            _FakeMarineApiService({
              'current': {
                'wave_height': 1.2,
                'wave_direction': 180.0,
                'wave_period': 6.5,
                'sea_surface_temperature': 21.3,
              },
            }),
          );

          final condition = await repository.getMarineData(38.3, 26.3);

          expect(condition.waveHeight, 1.2);
          expect(condition.seaSurfaceTemperature, 21.3);
        },
      );

      test(
        'given a response without hourly, getMarineData -> hourly is an empty list',
        () async {
          final repository = MarineRepository(
            _FakeMarineApiService({
              'current': {'wave_height': 1.2},
            }),
          );

          final condition = await repository.getMarineData(38.3, 26.3);

          expect(condition.hourly, isEmpty);
        },
      );

      test(
        'given a response with hourly, getMarineData -> populates the hourly series',
        () async {
          final repository = MarineRepository(
            _FakeMarineApiService({
              'current': {'wave_height': 1.2},
              'hourly': {
                'time': ['2026-07-01T00:00'],
                'wave_height': [0.9],
              },
            }),
          );

          final condition = await repository.getMarineData(38.3, 26.3);

          expect(condition.hourly, hasLength(1));
          expect(condition.hourly.single.waveHeight, 0.9);
        },
      );

      test(
        'given null current entries, getMarineData -> stays null, never 0',
        () async {
          final repository = MarineRepository(
            _FakeMarineApiService({
              'current': {'wave_height': null, 'sea_surface_temperature': null},
            }),
          );

          final condition = await repository.getMarineData(38.3, 26.3);

          expect(condition.waveHeight, isNull);
          expect(condition.seaSurfaceTemperature, isNull);
        },
      );

      test(
        'given no current field, getMarineData -> throws a clear error',
        () async {
          final repository = MarineRepository(_FakeMarineApiService({}));

          expect(
            () => repository.getMarineData(38.3, 26.3),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'given a current field with an unexpected shape, getMarineData -> throws a clear error',
        () async {
          final repository = MarineRepository(
            _FakeMarineApiService({'current': 'not a map'}),
          );

          expect(
            () => repository.getMarineData(38.3, 26.3),
            throwsA(isA<Exception>()),
          );
        },
      );
    });
  });
}
