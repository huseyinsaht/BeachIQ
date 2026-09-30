import 'package:beachiq/data/models/weather_condition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeatherCondition.fromJson', () {
    test('parses all fields', () {
      final condition = WeatherCondition.fromJson({
        'temperature_2m': 24.5,
        'wind_speed_10m': 12.3,
        'weather_code': 3,
      });

      expect(condition.temperature, 24.5);
      expect(condition.windSpeed, 12.3);
      expect(condition.weatherCode, 3);
    });

    test('defaults missing fields to 0', () {
      final condition = WeatherCondition.fromJson({});

      expect(condition.temperature, 0);
      expect(condition.windSpeed, 0);
      expect(condition.weatherCode, 0);
    });

    test('parses new forecast fields when present', () {
      final condition = WeatherCondition.fromJson({
        'temperature_2m': 24.5,
        'wind_speed_10m': 12.3,
        'weather_code': 3,
        'time': '2024-01-01T12:00',
        'hourly': {
          'time': [
            '2024-01-01T11:00',
            '2024-01-01T12:00',
            '2024-01-01T13:00',
          ],
          'temperature_2m': [20.0, 24.5, 25.0],
          'weather_code': [1, 3, 2],
          'uv_index': [2.0, 4.5, 5.0],
          'precipitation_probability': [10, 20, 30],
          'pressure_msl': [1010.0, 1012.0, 1013.0],
        },
        'daily': {
          'temperature_2m_max': [26.0],
          'temperature_2m_min': [18.0],
        },
      });

      expect(condition.pressureHpa, 1012.0);
      expect(condition.uvIndex, 4.5);
      expect(condition.rainChancePercent, 20);
      expect(condition.highTemperature, 26.0);
      expect(condition.lowTemperature, 18.0);
      expect(condition.hourly, hasLength(3));
      expect(condition.hourly[1].time, DateTime.parse('2024-01-01T12:00'));
      expect(condition.hourly[1].temperature, 24.5);
      expect(condition.hourly[1].weatherCode, 3);
    });

    test('defaults new forecast fields to null/empty when absent', () {
      final condition = WeatherCondition.fromJson({});

      expect(condition.pressureHpa, isNull);
      expect(condition.uvIndex, isNull);
      expect(condition.rainChancePercent, isNull);
      expect(condition.highTemperature, isNull);
      expect(condition.lowTemperature, isNull);
      expect(condition.hourly, isEmpty);
    });
  });
}
