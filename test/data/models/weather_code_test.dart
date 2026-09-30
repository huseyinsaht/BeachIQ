import 'package:beachiq/data/models/weather_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weatherCodeDescription', () {
    test('maps clear sky', () {
      expect(weatherCodeDescription(0), 'Clear');
    });

    test('maps partly cloudy', () {
      expect(weatherCodeDescription(2), 'Partly Cloudy');
    });

    test('maps rain', () {
      expect(weatherCodeDescription(61), 'Rain');
    });

    test('maps thunderstorm', () {
      expect(weatherCodeDescription(95), 'Thunderstorm');
    });

    test('falls back to a sensible default for an unrecognized code', () {
      expect(weatherCodeDescription(-1), 'Unknown');
    });
  });
}
