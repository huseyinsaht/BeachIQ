import 'package:beachiq/logic/daily_outlook.dart';
import 'package:beachiq/logic/swim_suitability.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/builders.dart';

void main() {
  group('buildDailyOutlook', () {
    test('given matching weather and sea daily entries, buildDailyOutlook -> '
        'one combined entry per day, in order', () {
      final entries = buildDailyOutlook(
        weatherDaily: [
          aDailyWeatherForecast(
            date: DateTime(2026, 7, 1),
            highTemperature: 28.0,
            lowTemperature: 20.0,
            windSpeedMaxKmh: 10.0,
            rainChanceMaxPercent: 5,
          ),
          aDailyWeatherForecast(
            date: DateTime(2026, 7, 2),
            highTemperature: 29.0,
            lowTemperature: 21.0,
          ),
        ],
        seaDaily: [
          aSeaDailyForecast(date: DateTime(2026, 7, 1), waveHeightMax: 0.3),
          aSeaDailyForecast(date: DateTime(2026, 7, 2), waveHeightMax: 1.5),
        ],
      );

      expect(entries, hasLength(2));
      expect(entries[0].date, DateTime(2026, 7, 1));
      expect(entries[0].highTemperature, 28.0);
      expect(entries[0].lowTemperature, 20.0);
      expect(entries[0].waveHeightMax, 0.3);
      expect(entries[0].verdict.level, SwimSuitabilityLevel.good);
      expect(entries[1].waveHeightMax, 1.5);
      expect(entries[1].verdict.level, SwimSuitabilityLevel.poor);
    });

    test('given a weather day with no matching sea entry, buildDailyOutlook -> '
        'waveHeightMax is null but the day still scores from wind/rain', () {
      final entries = buildDailyOutlook(
        weatherDaily: [
          aDailyWeatherForecast(
            date: DateTime(2026, 7, 1),
            windSpeedMaxKmh: 45.0,
          ),
        ],
        seaDaily: const [],
      );

      expect(entries, hasLength(1));
      expect(entries.single.waveHeightMax, isNull);
      expect(entries.single.verdict.level, SwimSuitabilityLevel.poor);
    });

    test(
      'given no weather daily entries at all, buildDailyOutlook -> an empty list',
      () {
        final entries = buildDailyOutlook(
          weatherDaily: const [],
          seaDaily: [
            aSeaDailyForecast(date: DateTime(2026, 7, 1), waveHeightMax: 0.3),
          ],
        );

        expect(entries, isEmpty);
      },
    );

    test('given a day with no wave/wind/rain data at all, buildDailyOutlook -> '
        'that day is unknown, not a guessed good', () {
      final entries = buildDailyOutlook(
        weatherDaily: [aDailyWeatherForecast(date: DateTime(2026, 7, 1))],
        seaDaily: const [],
      );

      expect(entries.single.verdict.level, SwimSuitabilityLevel.unknown);
    });
  });
}
