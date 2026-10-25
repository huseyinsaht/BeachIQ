import 'package:beachiq/logic/swim_suitability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scoreSwimSuitability', () {
    test('is good for calm conditions', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.2,
        windSpeedKmh: 8,
        rainChancePercent: 5,
      );

      expect(verdict.level, SwimSuitabilityLevel.good);
      expect(verdict.message, isNotEmpty);
    });

    test('is poor for high wave height', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 1.5,
        windSpeedKmh: 8,
        rainChancePercent: 5,
      );

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('is poor for high wind speed', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.2,
        windSpeedKmh: 45,
        rainChancePercent: 5,
      );

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('is poor for high rain chance', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.2,
        windSpeedKmh: 8,
        rainChancePercent: 80,
      );

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('is caution for moderate wave height', () {
      final verdict = scoreSwimSuitability(waveHeightM: 0.8);

      expect(verdict.level, SwimSuitabilityLevel.caution);
    });

    test('is caution for moderate wind speed', () {
      final verdict = scoreSwimSuitability(windSpeedKmh: 25);

      expect(verdict.level, SwimSuitabilityLevel.caution);
    });

    test('is caution for moderate rain chance', () {
      final verdict = scoreSwimSuitability(rainChancePercent: 50);

      expect(verdict.level, SwimSuitabilityLevel.caution);
    });

    test('takes the worst level across independently fine inputs', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.1, // calm
        windSpeedKmh: 45, // rough
        rainChancePercent: 5, // fine
      );

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('is unknown when every input is missing', () {
      final verdict = scoreSwimSuitability();

      expect(verdict.level, SwimSuitabilityLevel.unknown);
      expect(verdict.message, 'Not enough data to judge conditions.');
    });

    test('scores from a single available input without crashing', () {
      final verdict = scoreSwimSuitability(waveHeightM: 0.3);

      expect(verdict.level, SwimSuitabilityLevel.good);
    });

    test('is unknown, never good, when wave height is missing', () {
      final verdict = scoreSwimSuitability(
        windSpeedKmh: 8,
        rainChancePercent: 5,
      );

      expect(verdict.level, SwimSuitabilityLevel.unknown);
      expect(verdict.message, 'No sea data — check local flags.');
    });

    test('still warns about wind or rain when wave height is missing', () {
      expect(
        scoreSwimSuitability(windSpeedKmh: 45, rainChancePercent: 5).level,
        SwimSuitabilityLevel.poor,
      );
      expect(
        scoreSwimSuitability(windSpeedKmh: 25, rainChancePercent: 5).level,
        SwimSuitabilityLevel.caution,
      );
      expect(
        scoreSwimSuitability(windSpeedKmh: 8, rainChancePercent: 75).level,
        SwimSuitabilityLevel.poor,
      );
    });

    test('boundary wave height counts as poor, not caution', () {
      final verdict = scoreSwimSuitability(waveHeightM: 1.2);

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('boundary moderate wave height counts as caution, not good', () {
      final verdict = scoreSwimSuitability(waveHeightM: 0.6);

      expect(verdict.level, SwimSuitabilityLevel.caution);
    });

    test('just below the moderate wave height boundary is still good', () {
      final verdict = scoreSwimSuitability(waveHeightM: 0.59);

      expect(verdict.level, SwimSuitabilityLevel.good);
    });

    test('boundary wind speed counts as poor, not caution', () {
      final verdict = scoreSwimSuitability(windSpeedKmh: 40);

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('boundary moderate wind speed counts as caution, not good', () {
      final verdict = scoreSwimSuitability(windSpeedKmh: 20);

      expect(verdict.level, SwimSuitabilityLevel.caution);
    });

    test('just below the moderate wind speed boundary is still good', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.2,
        windSpeedKmh: 19.9,
      );

      expect(verdict.level, SwimSuitabilityLevel.good);
    });

    test('boundary rain chance counts as poor, not caution', () {
      final verdict = scoreSwimSuitability(rainChancePercent: 70);

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('boundary moderate rain chance counts as caution, not good', () {
      final verdict = scoreSwimSuitability(rainChancePercent: 40);

      expect(verdict.level, SwimSuitabilityLevel.caution);
    });

    test('just below the moderate rain chance boundary is still good', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.2,
        rainChancePercent: 39,
      );

      expect(verdict.level, SwimSuitabilityLevel.good);
    });

    group('current weather (weatherCode / airTemperatureC)', () {
      SwimVerdict score({int? code, double? temp, double wave = 0.2}) =>
          scoreSwimSuitability(
            waveHeightM: wave,
            windSpeedKmh: 8,
            rainChancePercent: 5,
            weatherCode: code,
            airTemperatureC: temp,
          );

      test('given clear to partly cloudy weather, stays good', () {
        for (final code in [0, 1, 2]) {
          expect(score(code: code, temp: 25).level, SwimSuitabilityLevel.good);
        }
      });

      test(
        'given a thunderstorm code, is poor with a thunderstorm message',
        () {
          for (final code in [95, 96, 99]) {
            final verdict = score(code: code, temp: 28);

            expect(verdict.level, SwimSuitabilityLevel.poor, reason: '$code');
            expect(verdict.message, 'Thunderstorms — stay out of the water.');
          }
        },
      );

      test('given snow or freezing precipitation, is poor', () {
        for (final code in [56, 57, 66, 67, 71, 73, 75, 77, 85, 86]) {
          final verdict = score(code: code);

          expect(verdict.level, SwimSuitabilityLevel.poor, reason: '$code');
          expect(verdict.message, 'Snow or freezing rain — stay out.');
        }
      });

      test('given drizzle, rain or showers right now, is caution', () {
        for (final code in [51, 53, 55, 61, 63, 65, 80, 81, 82]) {
          final verdict = score(code: code, temp: 24);

          expect(verdict.level, SwimSuitabilityLevel.caution, reason: '$code');
          expect(verdict.message, 'Rain right now — swim with care.');
        }
      });

      test('given fog, is caution', () {
        for (final code in [45, 48]) {
          final verdict = score(code: code, temp: 20);

          expect(verdict.level, SwimSuitabilityLevel.caution);
          expect(verdict.message, 'Foggy — swim with care.');
        }
      });

      test('given overcast and cool air, is caution (the reported bug)', () {
        final verdict = score(code: 3, temp: 18);

        expect(verdict.level, SwimSuitabilityLevel.caution);
        expect(verdict.message, 'Overcast and cool — less pleasant.');
      });

      test(
        'given overcast at exactly the cool limit or warmer, stays good',
        () {
          expect(score(code: 3, temp: 22).level, SwimSuitabilityLevel.good);
          expect(score(code: 3, temp: 31).level, SwimSuitabilityLevel.good);
        },
      );

      test('given overcast just below the cool limit, is caution', () {
        expect(score(code: 3, temp: 21.9).level, SwimSuitabilityLevel.caution);
      });

      test('given overcast but no air temperature, is not downgraded', () {
        expect(score(code: 3).level, SwimSuitabilityLevel.good);
      });

      test('given a thunderstorm and rough waves, poor wins with the '
          'thunderstorm message from the later, strictly worse input only '
          'when the earlier one was only caution', () {
        // Waves 0.8 m = caution (no custom message), thunderstorm = poor.
        final verdict = score(code: 95, wave: 0.8);

        expect(verdict.level, SwimSuitabilityLevel.poor);
        expect(verdict.message, 'Thunderstorms — stay out of the water.');
      });

      test('given caution from waves and caution from rain, keeps the wave '
          'message (first factor to set the level)', () {
        final verdict = score(code: 61, wave: 0.8);

        expect(verdict.level, SwimSuitabilityLevel.caution);
        expect(verdict.message, 'A bit choppy — swim with care.');
      });

      test('given rough waves and a thunderstorm, both poor: keeps the '
          'generic rough message', () {
        final verdict = score(code: 95, wave: 1.5);

        expect(verdict.level, SwimSuitabilityLevel.poor);
        expect(verdict.message, 'Rough conditions — skip swimming.');
      });

      test('given only a weather code, scores from it (a thunderstorm alone '
          'is poor even with no sea data)', () {
        final verdict = scoreSwimSuitability(weatherCode: 95);

        expect(verdict.level, SwimSuitabilityLevel.poor);
      });

      test('given only clear weather and nothing else, is unknown (no '
          'wave data)', () {
        final verdict = scoreSwimSuitability(weatherCode: 0);

        expect(verdict.level, SwimSuitabilityLevel.unknown);
      });
    });

    test('every verdict message fits the one-line pill (at most 40 '
        'characters), so none is cut off', () {
      final verdicts = <SwimVerdict>[
        scoreSwimSuitability(waveHeightM: 0.2, windSpeedKmh: 5),
        scoreSwimSuitability(waveHeightM: 0.8),
        scoreSwimSuitability(waveHeightM: 1.5),
        scoreSwimSuitability(),
        scoreSwimSuitability(windSpeedKmh: 5),
        for (final code in [95, 71, 61, 45])
          scoreSwimSuitability(waveHeightM: 0.2, weatherCode: code),
        scoreSwimSuitability(
          waveHeightM: 0.2,
          weatherCode: 3,
          airTemperatureC: 15,
        ),
      ];

      expect(verdicts.map((v) => v.message).toSet().length, greaterThan(8));
      for (final verdict in verdicts) {
        expect(
          verdict.message.length,
          lessThanOrEqualTo(40),
          reason: '"${verdict.message}"',
        );
      }
    });
  });
}
