import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWeatherApiService extends WeatherApiService {
  _FakeWeatherApiService(this.response);

  final Map<String, dynamic> response;

  @override
  Future<Map<String, dynamic>> getWeatherData(double lat, double lon) async {
    return response;
  }
}

void main() {
  group('WeatherRepository.getWeatherData', () {
    test('parses a well-formed response', () async {
      final repository = WeatherRepository(
        _FakeWeatherApiService({
          'current': {
            'temperature_2m': 27.5,
            'wind_speed_10m': 12.0,
            'weather_code': 1,
          },
        }),
      );

      final condition = await repository.getWeatherData(38.3, 26.3);

      expect(condition.temperature, 27.5);
      expect(condition.windSpeed, 12.0);
      expect(condition.weatherCode, 1);
    });

    test('throws a clear error when the current field is missing', () async {
      final repository = WeatherRepository(_FakeWeatherApiService({}));

      expect(
        () => repository.getWeatherData(38.3, 26.3),
        throwsA(isA<Exception>()),
      );
    });

    test('throws a clear error when the current field has an unexpected shape', () async {
      final repository = WeatherRepository(
        _FakeWeatherApiService({'current': 'not a map'}),
      );

      expect(
        () => repository.getWeatherData(38.3, 26.3),
        throwsA(isA<Exception>()),
      );
    });
  });
}
