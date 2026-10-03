import 'package:beachiq/data/models/sea_condition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeaCondition', () {
    group('fromJson', () {
      test('given a full current response, fromJson -> parses every field', () {
        final condition = SeaCondition.fromJson({
          'wave_height': 1.2,
          'wave_direction': 180.0,
          'wave_period': 6.5,
          'sea_surface_temperature': 21.3,
          'ocean_current_velocity': 0.5,
          'ocean_current_direction': 90.0,
        });

        expect(condition.waveHeight, 1.2);
        expect(condition.waveDirection, 180.0);
        expect(condition.wavePeriod, 6.5);
        expect(condition.seaSurfaceTemperature, 21.3);
        // Open-Meteo's `ocean_current_velocity` is already km/h by default
        // (issue #191) -> passes through unchanged, no conversion.
        expect(condition.currentVelocity, 0.5);
        expect(condition.currentDirection, 90.0);
      });

      test(
        'given an empty response, fromJson -> every field is null, never 0',
        () {
          final condition = SeaCondition.fromJson({});

          expect(condition.waveHeight, isNull);
          expect(condition.waveDirection, isNull);
          expect(condition.wavePeriod, isNull);
          expect(condition.seaSurfaceTemperature, isNull);
          expect(condition.currentVelocity, isNull);
          expect(condition.currentDirection, isNull);
          expect(condition.hourly, isEmpty);
        },
      );

      test('given explicit null entries, fromJson -> stays null, not 0', () {
        final condition = SeaCondition.fromJson({
          'wave_height': null,
          'sea_surface_temperature': null,
          'ocean_current_velocity': null,
          'ocean_current_direction': null,
        });

        expect(condition.waveHeight, isNull);
        expect(condition.seaSurfaceTemperature, isNull);
        expect(condition.currentVelocity, isNull);
        expect(condition.currentDirection, isNull);
      });

      test('given no hourly section, fromJson -> hourly is an empty list', () {
        final condition = SeaCondition.fromJson({'wave_height': 1.0});

        expect(condition.hourly, isEmpty);
      });

      test(
        'given a full hourly section, fromJson -> populates SeaHourly for each entry',
        () {
          final condition = SeaCondition.fromJson({
            'hourly': {
              'time': ['2026-07-01T00:00', '2026-07-01T01:00'],
              'wave_height': [0.5, 0.6],
              'wave_direction': [180.0, 185.0],
              'wave_period': [5.0, 5.2],
              'sea_surface_temperature': [22.0, 22.1],
              'ocean_current_velocity': [0.2, null],
              'ocean_current_direction': [45.0, null],
            },
          });

          expect(condition.hourly, hasLength(2));
          expect(condition.hourly[0].time, DateTime.parse('2026-07-01T00:00'));
          expect(condition.hourly[0].waveHeight, 0.5);
          expect(condition.hourly[0].currentVelocity, 0.2);
          expect(condition.hourly[0].currentDirection, 45.0);
          expect(condition.hourly[1].currentVelocity, isNull);
          expect(condition.hourly[1].currentDirection, isNull);
        },
      );

      test(
        'given an hourly entry with an unparseable time, fromJson -> skips it rather than throwing',
        () {
          final condition = SeaCondition.fromJson({
            'hourly': {
              'time': ['not a time', '2026-07-01T01:00'],
              'wave_height': [0.5, 0.6],
            },
          });

          expect(condition.hourly, hasLength(1));
          expect(
            condition.hourly.single.time,
            DateTime.parse('2026-07-01T01:00'),
          );
          expect(condition.hourly.single.waveHeight, 0.6);
        },
      );

      test(
        'given an hourly list shorter than time, fromJson -> the missing values are null',
        () {
          final condition = SeaCondition.fromJson({
            'hourly': {
              'time': ['2026-07-01T00:00', '2026-07-01T01:00'],
              'wave_height': [0.5],
            },
          });

          expect(condition.hourly[0].waveHeight, 0.5);
          expect(condition.hourly[1].waveHeight, isNull);
        },
      );

      test(
        'given a malformed (non-numeric) value, fromJson -> that field is null rather than throwing',
        () {
          final condition = SeaCondition.fromJson({
            'wave_height': 'not a number',
            'sea_surface_temperature': 21.0,
          });

          expect(condition.waveHeight, isNull);
          expect(condition.seaSurfaceTemperature, 21.0);
        },
      );

      // Open-Meteo's ocean current direction follows the oceanographic
      // "flowing toward" convention (degrees clockwise from true north,
      // the direction the current is heading), not the meteorological
      // "coming from" convention used for wave/wind direction. This test
      // documents that assumption: a current carrying water due east is
      // 90°, matching the compass bearing of travel, not where it came
      // from (270°). See the convention note on SeaCondition.currentDirection.
      test(
        'given an eastward current, fromJson -> direction is 90 degrees (flowing-toward convention)',
        () {
          final condition = SeaCondition.fromJson({
            'ocean_current_direction': 90.0,
          });

          expect(condition.currentDirection, 90.0);
        },
      );
    });
  });
}
