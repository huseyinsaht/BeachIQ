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
          'time': ['2024-01-01T11:00', '2024-01-01T12:00', '2024-01-01T13:00'],
          'temperature_2m': [20.0, 24.5, 25.0],
          'weather_code': [1, 3, 2],
          'uv_index': [2.0, 4.5, 5.0],
          'precipitation_probability': [10, 20, 30],
          'pressure_msl': [1010.0, 1012.0, 1013.0],
          'wind_speed_10m': [10.0, 15.0, 20.0],
          'wind_gusts_10m': [18.0, 25.0, 32.0],
          'cloud_cover': [10.0, 40.0, 90.0],
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
      expect(condition.hourly[1].windSpeed, 15.0);
      expect(condition.hourly[1].windGusts, 25.0);
      expect(condition.hourly[1].cloudCoverPercent, 40.0);
      expect(condition.hourly[1].rainChancePercent, 20.0);
      expect(condition.hourly[1].pressureHpa, 1012.0);
    });

    test('hourly pressure and rain chance default to null when absent from '
        'the response', () {
      final condition = WeatherCondition.fromJson({
        'hourly': {
          'time': ['2024-01-01T11:00'],
          'temperature_2m': [20.0],
          'weather_code': [1],
        },
      });

      expect(condition.hourly, hasLength(1));
      expect(condition.hourly.first.pressureHpa, isNull);
      expect(condition.hourly.first.rainChancePercent, isNull);
    });

    test('hourly wind speed, gusts, cloud cover and rain chance default to '
        'null when absent from the response', () {
      final condition = WeatherCondition.fromJson({
        'hourly': {
          'time': ['2024-01-01T11:00'],
          'temperature_2m': [20.0],
          'weather_code': [1],
        },
      });

      expect(condition.hourly, hasLength(1));
      expect(condition.hourly.first.windSpeed, isNull);
      expect(condition.hourly.first.windGusts, isNull);
      expect(condition.hourly.first.cloudCoverPercent, isNull);
      expect(condition.hourly.first.rainChancePercent, isNull);
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

    test('picks the current hourly entry when current.time has minute '
        'resolution and hourly.time is on the hour', () {
      // Open-Meteo's `current.time` (e.g. 12:15) does not exactly match any
      // `hourly.time` entry (on the hour) — the latest hourly entry at or
      // before current.time should be used, not the first entry.
      final condition = WeatherCondition.fromJson({
        'temperature_2m': 24.5,
        'wind_speed_10m': 12.3,
        'weather_code': 3,
        'time': '2024-01-01T12:15',
        'hourly': {
          'time': ['2024-01-01T11:00', '2024-01-01T12:00', '2024-01-01T13:00'],
          'temperature_2m': [20.0, 24.5, 25.0],
          'weather_code': [1, 3, 2],
          'uv_index': [2.0, 4.5, 5.0],
          'precipitation_probability': [10, 20, 30],
          'pressure_msl': [1010.0, 1012.0, 1013.0],
        },
      });

      expect(condition.uvIndex, 4.5);
      expect(condition.rainChancePercent, 20);
      expect(condition.pressureHpa, 1012.0);
    });

    test('falls back to the first hourly entry when current.time is '
        'missing or unparseable', () {
      final condition = WeatherCondition.fromJson({
        'hourly': {
          'time': ['2024-01-01T11:00', '2024-01-01T12:00'],
          'uv_index': [2.0, 4.5],
        },
      });

      expect(condition.uvIndex, 2.0);
    });

    test('skips hourly entries with a null temperature or weather code '
        'instead of fabricating 0', () {
      final condition = WeatherCondition.fromJson({
        'hourly': {
          'time': ['2024-01-01T11:00', '2024-01-01T12:00'],
          'temperature_2m': [null, 24.5],
          'weather_code': [1, null],
        },
      });

      expect(condition.hourly, isEmpty);
    });

    test('ignores non-numeric values in hourly/daily arrays instead of '
        'throwing', () {
      final condition = WeatherCondition.fromJson({
        'hourly': {
          'time': ['2024-01-01T12:00'],
          'uv_index': ['not a number'],
        },
        'daily': {
          'temperature_2m_max': ['not a number'],
        },
      });

      expect(condition.uvIndex, isNull);
      expect(condition.highTemperature, isNull);
    });
  });
}
