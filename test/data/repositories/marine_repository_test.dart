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
  group('MarineRepository.getMarineData', () {
    test('parses a well-formed response', () async {
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
    });

    test('throws a clear error when the current field is missing', () async {
      final repository = MarineRepository(_FakeMarineApiService({}));

      expect(
        () => repository.getMarineData(38.3, 26.3),
        throwsA(isA<Exception>()),
      );
    });

    test('throws a clear error when the current field has an unexpected shape', () async {
      final repository = MarineRepository(
        _FakeMarineApiService({'current': 'not a map'}),
      );

      expect(
        () => repository.getMarineData(38.3, 26.3),
        throwsA(isA<Exception>()),
      );
    });
  });
}
