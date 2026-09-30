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

    test('passes extended forecast fields through from a fixture response', () async {
      final repository = WeatherRepository(
        _FakeWeatherApiService({
          'current': {
            'temperature_2m': 27.5,
            'wind_speed_10m': 12.0,
            'weather_code': 1,
            'time': '2024-01-01T12:00',
          },
          'hourly': {
            'time': ['2024-01-01T12:00'],
            'temperature_2m': [27.5],
            'weather_code': [1],
            'uv_index': [5.0],
            'precipitation_probability': [15],
            'pressure_msl': [1015.0],
          },
          'daily': {
            'temperature_2m_max': [29.0],
            'temperature_2m_min': [21.0],
          },
        }),
      );

      final condition = await repository.getWeatherData(38.3, 26.3);

      expect(condition.pressureHpa, 1015.0);
      expect(condition.uvIndex, 5.0);
      expect(condition.rainChancePercent, 15);
      expect(condition.highTemperature, 29.0);
      expect(condition.lowTemperature, 21.0);
      expect(condition.hourly, hasLength(1));
      expect(condition.hourly.first.temperature, 27.5);
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
