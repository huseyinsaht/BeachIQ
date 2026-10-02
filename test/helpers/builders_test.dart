import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/models/beach_amenity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'builders.dart';

void main() {
  group('aBeach', () {
    test('given no overrides, build -> produces a valid default beach', () {
      final beach = aBeach();

      expect(beach.name, isNotEmpty);
      expect(beach.city, isNotEmpty);
      expect(beach.fee, BeachFee.unknown);
      expect(beach.amenities, isEmpty);
    });

    test('given a named override, build -> only that field changes', () {
      final beach = aBeach(name: 'Altinkum', hasToilets: true);

      expect(beach.name, 'Altinkum');
      expect(beach.hasToilets, isTrue);
      expect(beach.city, aBeach().city);
    });
  });

  group('anAmenity', () {
    test('given no overrides, build -> produces a valid default amenity', () {
      final amenity = anAmenity();

      expect(amenity.kind, AmenityKind.toilets);
    });

    test('given a named override, build -> only that field changes', () {
      final amenity = anAmenity(kind: AmenityKind.cafe, name: 'Beach Cafe');

      expect(amenity.kind, AmenityKind.cafe);
      expect(amenity.name, 'Beach Cafe');
    });
  });

  group('aSeaCondition', () {
    test(
      'given no overrides, build -> produces a valid default sea condition',
      () {
        final sea = aSeaCondition();

        expect(sea.waveHeight, greaterThanOrEqualTo(0));
        expect(sea.seaSurfaceTemperature, greaterThan(0));
      },
    );

    test('given a named override, build -> only that field changes', () {
      final sea = aSeaCondition(waveHeight: 2.5);

      expect(sea.waveHeight, 2.5);
      expect(sea.seaSurfaceTemperature, aSeaCondition().seaSurfaceTemperature);
    });
  });

  group('aWeatherCondition / aWeatherHourly', () {
    test(
      'given no overrides, build -> produces a valid default weather condition',
      () {
        final weather = aWeatherCondition();

        expect(weather.hourly, isEmpty);
        expect(weather.pressureHpa, isNull);
      },
    );

    test('given a named override, build -> only that field changes', () {
      final weather = aWeatherCondition(temperature: 30.0);

      expect(weather.temperature, 30.0);
      expect(weather.windSpeed, aWeatherCondition().windSpeed);
    });

    test('given a required time, build -> produces a valid hourly entry', () {
      final hourly = aWeatherHourly(time: DateTime(2026, 7, 1, 12));

      expect(hourly.time, DateTime(2026, 7, 1, 12));
      expect(hourly.windSpeed, isNull);
    });
  });
}
