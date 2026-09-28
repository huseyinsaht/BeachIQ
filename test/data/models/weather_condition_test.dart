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
  });
}
