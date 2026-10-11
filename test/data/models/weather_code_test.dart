import 'package:beachiq/data/models/weather_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weatherCodeDescription', () {
    test('maps clear sky', () {
      expect(weatherCodeDescription(0), 'Clear');
    });

    test('maps mainly clear', () {
      expect(weatherCodeDescription(1), 'Mainly Clear');
    });

    test('maps partly cloudy', () {
      expect(weatherCodeDescription(2), 'Partly Cloudy');
    });

    test('maps overcast', () {
      expect(weatherCodeDescription(3), 'Overcast');
    });

    test('maps fog', () {
      expect(weatherCodeDescription(45), 'Fog');
      expect(weatherCodeDescription(48), 'Fog');
    });

    test('maps drizzle', () {
      expect(weatherCodeDescription(51), 'Drizzle');
      expect(weatherCodeDescription(53), 'Drizzle');
      expect(weatherCodeDescription(55), 'Drizzle');
    });

    test('maps freezing drizzle', () {
      expect(weatherCodeDescription(56), 'Freezing Drizzle');
      expect(weatherCodeDescription(57), 'Freezing Drizzle');
    });

    test('maps rain', () {
      expect(weatherCodeDescription(61), 'Rain');
      expect(weatherCodeDescription(63), 'Rain');
      expect(weatherCodeDescription(65), 'Rain');
    });

    test('maps freezing rain', () {
      expect(weatherCodeDescription(66), 'Freezing Rain');
      expect(weatherCodeDescription(67), 'Freezing Rain');
    });

    test('maps snow', () {
      expect(weatherCodeDescription(71), 'Snow');
      expect(weatherCodeDescription(73), 'Snow');
      expect(weatherCodeDescription(75), 'Snow');
    });

    test('maps snow grains', () {
      expect(weatherCodeDescription(77), 'Snow Grains');
    });

    test('maps rain showers', () {
      expect(weatherCodeDescription(80), 'Rain Showers');
      expect(weatherCodeDescription(81), 'Rain Showers');
      expect(weatherCodeDescription(82), 'Rain Showers');
    });

    test('maps snow showers', () {
      expect(weatherCodeDescription(85), 'Snow Showers');
      expect(weatherCodeDescription(86), 'Snow Showers');
    });

    test('maps thunderstorm', () {
      expect(weatherCodeDescription(95), 'Thunderstorm');
    });

    test('maps thunderstorm with hail', () {
      expect(weatherCodeDescription(96), 'Thunderstorm');
      expect(weatherCodeDescription(99), 'Thunderstorm');
    });

    test('falls back to a sensible default for an unrecognized code', () {
      expect(weatherCodeDescription(-1), 'Unknown');
    });
  });
}
