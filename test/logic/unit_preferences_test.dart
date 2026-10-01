import 'package:beachiq/logic/unit_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('metersToFeet', () {
    test('converts a typical wave height', () {
      expect(metersToFeet(1), closeTo(3.28084, 1e-9));
    });

    test('is zero at zero', () {
      expect(metersToFeet(0), 0);
    });

    test('handles negative values (e.g. below-sea-level depth)', () {
      expect(metersToFeet(-2), closeTo(-6.56168, 1e-9));
    });
  });

  group('celsiusToFahrenheit', () {
    test('freezing point', () {
      expect(celsiusToFahrenheit(0), 32);
    });

    test('boiling point', () {
      expect(celsiusToFahrenheit(100), 212);
    });

    test('a typical air temperature', () {
      expect(celsiusToFahrenheit(25), 77);
    });

    test('a negative temperature', () {
      expect(celsiusToFahrenheit(-10), 14);
    });
  });

  group('kmhToMph', () {
    test('converts a typical wind speed', () {
      expect(kmhToMph(100), closeTo(62.1371, 1e-9));
    });

    test('is zero at zero', () {
      expect(kmhToMph(0), 0);
    });
  });

  group('formatWaveHeight', () {
    test('metric renders meters with one decimal', () {
      expect(formatWaveHeight(1.2, UnitSystem.metric), '1.2 m');
    });

    test('imperial renders feet with one decimal', () {
      expect(formatWaveHeight(1, UnitSystem.imperial), '3.3 ft');
    });

    test('zero renders cleanly in both systems', () {
      expect(formatWaveHeight(0, UnitSystem.metric), '0.0 m');
      expect(formatWaveHeight(0, UnitSystem.imperial), '0.0 ft');
    });
  });

  group('formatTemperature', () {
    test('metric renders rounded celsius with a degree-C suffix', () {
      expect(formatTemperature(23.4, UnitSystem.metric), '23°C');
    });

    test('imperial renders rounded fahrenheit with a degree-F suffix', () {
      expect(formatTemperature(25, UnitSystem.imperial), '77°F');
    });

    test('a negative temperature converts correctly', () {
      expect(formatTemperature(-10, UnitSystem.imperial), '14°F');
    });
  });

  group('formatWindSpeed', () {
    test('metric renders rounded km/h', () {
      expect(formatWindSpeed(12.6, UnitSystem.metric), '13 km/h');
    });

    test('imperial renders rounded mph', () {
      expect(formatWindSpeed(100, UnitSystem.imperial), '62 mph');
    });

    test('is zero at zero in both systems', () {
      expect(formatWindSpeed(0, UnitSystem.metric), '0 km/h');
      expect(formatWindSpeed(0, UnitSystem.imperial), '0 mph');
    });
  });
}
