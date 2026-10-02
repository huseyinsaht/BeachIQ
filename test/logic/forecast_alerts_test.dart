import 'package:beachiq/logic/forecast_alerts.dart';
import 'package:beachiq/logic/swim_suitability.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/builders.dart';

void main() {
  // A fixed "now" well before every hourly reading used below, so every
  // reading in these tests counts as a future hour unless a test says
  // otherwise.
  final now = DateTime(2024, 1, 1, 8, 30);
  DateTime h(int hour) => DateTime(2024, 1, 1, hour);

  group('buildForecastAlerts', () {
    group('wind rule', () {
      test(
        'given wind rising >= ${windRiseThresholdKmh}km/h within an hour '
        'without crossing a threshold, buildForecastAlerts -> one wind alert',
        () {
          final weather = [
            aWeatherHourly(time: h(9), windSpeed: 5),
            aWeatherHourly(time: h(10), windSpeed: 16), // +11, still < 20
          ];

          final alerts = buildForecastAlerts(
            weather: weather,
            sea: const [],
            now: now,
          );

          expect(alerts, hasLength(1));
          expect(alerts.single.type, ForecastAlertType.wind);
          expect(alerts.single.severity, ForecastAlertSeverity.moderate);
          expect(alerts.single.start, h(9));
          expect(alerts.single.end, h(10));
          expect(alerts.single.message, contains('09:00'));
          expect(alerts.single.message, contains('10:00'));
        },
      );

      test('given wind crossing the moderate or high threshold, '
          'buildForecastAlerts -> a wind alert with matching severity', () {
        final moderateCrossing = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(9), windSpeed: moderateWindSpeedKmh - 5),
            aWeatherHourly(time: h(10), windSpeed: moderateWindSpeedKmh + 1),
          ],
          sea: const [],
          now: now,
        );
        expect(moderateCrossing, hasLength(1));
        expect(
          moderateCrossing.single.severity,
          ForecastAlertSeverity.moderate,
        );
        expect(
          moderateCrossing.single.message,
          contains('${moderateWindSpeedKmh.round()}'),
        );

        final highCrossing = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(9), windSpeed: highWindSpeedKmh - 5),
            aWeatherHourly(time: h(10), windSpeed: highWindSpeedKmh + 1),
          ],
          sea: const [],
          now: now,
        );
        expect(highCrossing, hasLength(1));
        expect(highCrossing.single.severity, ForecastAlertSeverity.high);
        expect(
          highCrossing.single.message,
          contains('${highWindSpeedKmh.round()}'),
        );
      });

      test('given wind that neither rises enough nor crosses a threshold, '
          'buildForecastAlerts -> no wind alert', () {
        final alerts = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(9), windSpeed: 10),
            aWeatherHourly(time: h(10), windSpeed: 15),
          ],
          sea: const [],
          now: now,
        );

        expect(alerts, isEmpty);
      });
    });

    group('waves rule', () {
      test(
        'given waves rising >= ${waveRiseThresholdM}m within an hour without '
        'crossing a threshold, buildForecastAlerts -> one waves alert',
        () {
          final sea = [
            aSeaHourly(time: h(9), waveHeight: 0.2),
            aSeaHourly(time: h(10), waveHeight: 0.5), // +0.3, still < 0.6
          ];

          final alerts = buildForecastAlerts(
            weather: const [],
            sea: sea,
            now: now,
          );

          expect(alerts, hasLength(1));
          expect(alerts.single.type, ForecastAlertType.waves);
          expect(alerts.single.severity, ForecastAlertSeverity.moderate);
          expect(alerts.single.start, h(9));
          expect(alerts.single.end, h(10));
        },
      );

      test('given waves crossing the moderate or high threshold, '
          'buildForecastAlerts -> a waves alert with matching severity', () {
        final moderateCrossing = buildForecastAlerts(
          weather: const [],
          sea: [
            aSeaHourly(time: h(9), waveHeight: moderateWaveHeightM - 0.1),
            aSeaHourly(time: h(10), waveHeight: moderateWaveHeightM + 0.05),
          ],
          now: now,
        );
        expect(moderateCrossing, hasLength(1));
        expect(
          moderateCrossing.single.severity,
          ForecastAlertSeverity.moderate,
        );

        final highCrossing = buildForecastAlerts(
          weather: const [],
          sea: [
            aSeaHourly(time: h(9), waveHeight: highWaveHeightM - 0.1),
            aSeaHourly(time: h(10), waveHeight: highWaveHeightM + 0.05),
          ],
          now: now,
        );
        expect(highCrossing, hasLength(1));
        expect(highCrossing.single.severity, ForecastAlertSeverity.high);
      });
    });

    group('clouds rule', () {
      test(
        'given the weather code moving from clear/partly-cloudy into '
        'overcast/rain/thunderstorm, buildForecastAlerts -> one clouds alert',
        () {
          final alerts = buildForecastAlerts(
            weather: [
              aWeatherHourly(time: h(13), weatherCode: 1), // mainly clear
              aWeatherHourly(time: h(14), weatherCode: 61), // rain
            ],
            sea: const [],
            now: now,
          );

          expect(alerts, hasLength(1));
          expect(alerts.single.type, ForecastAlertType.clouds);
          expect(alerts.single.start, h(13));
          expect(alerts.single.end, h(14));
          expect(alerts.single.message, contains('14:00'));
        },
      );

      test('given the weather code stays clear, buildForecastAlerts -> no '
          'clouds alert', () {
        final alerts = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(13), weatherCode: 0),
            aWeatherHourly(time: h(14), weatherCode: 2),
          ],
          sea: const [],
          now: now,
        );

        expect(alerts, isEmpty);
      });
    });

    group('rain rule', () {
      test('given rain chance crossing the moderate or high threshold, '
          'buildForecastAlerts -> a rain alert with matching severity', () {
        final moderateCrossing = buildForecastAlerts(
          weather: [
            aWeatherHourly(
              time: h(9),
              rainChancePercent: moderateRainChancePercent - 5,
            ),
            aWeatherHourly(
              time: h(10),
              rainChancePercent: moderateRainChancePercent + 5,
            ),
          ],
          sea: const [],
          now: now,
        );
        expect(moderateCrossing, hasLength(1));
        expect(moderateCrossing.single.type, ForecastAlertType.rain);
        expect(
          moderateCrossing.single.severity,
          ForecastAlertSeverity.moderate,
        );
        expect(
          moderateCrossing.single.message,
          contains('$moderateRainChancePercent'),
        );

        final highCrossing = buildForecastAlerts(
          weather: [
            aWeatherHourly(
              time: h(9),
              rainChancePercent: highRainChancePercent - 5,
            ),
            aWeatherHourly(
              time: h(10),
              rainChancePercent: highRainChancePercent + 5,
            ),
          ],
          sea: const [],
          now: now,
        );
        expect(highCrossing, hasLength(1));
        expect(highCrossing.single.severity, ForecastAlertSeverity.high);
        expect(highCrossing.single.message, contains('$highRainChancePercent'));
      });
    });

    group('window merging', () {
      test('given two contiguous triggering hours of the same type, '
          'buildForecastAlerts -> one merged alert, not two', () {
        final alerts = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(9), windSpeed: 5),
            aWeatherHourly(time: h(10), windSpeed: 16), // rise, triggers
            aWeatherHourly(time: h(11), windSpeed: 27), // crosses 20, triggers
            aWeatherHourly(time: h(12), windSpeed: 27), // flat, no trigger
          ],
          sea: const [],
          now: now,
        );

        expect(alerts, hasLength(1));
        expect(alerts.single.type, ForecastAlertType.wind);
        expect(alerts.single.start, h(9));
        expect(alerts.single.end, h(11));
      });
    });

    group('past-hour filtering', () {
      test('given a qualifying transition entirely before now, '
          'buildForecastAlerts -> no alert for it', () {
        final pastNow = DateTime(2024, 1, 1, 12);
        final alerts = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(9), windSpeed: 5),
            aWeatherHourly(time: h(10), windSpeed: 30), // would cross+rise
          ],
          sea: const [],
          now: pastNow,
        );

        expect(alerts, isEmpty);
      });

      test('given one hour before now and one after, buildForecastAlerts -> '
          'only the future hour can start/extend a window', () {
        final midNow = DateTime(2024, 1, 1, 9, 30);
        final alerts = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(9), windSpeed: 5), // before midNow
            aWeatherHourly(time: h(10), windSpeed: 30), // after midNow
          ],
          sea: const [],
          now: midNow,
        );

        expect(alerts, hasLength(1));
        expect(alerts.single.start, h(9));
        expect(alerts.single.end, h(10));
      });
    });

    group('null handling', () {
      test('given a null wind reading, buildForecastAlerts -> that hour is '
          'skipped, never treated as 0 km/h', () {
        // If null were treated as 0, this would read as a rise of 30
        // km/h and a crossing of both thresholds.
        final alerts = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(9), windSpeed: null),
            aWeatherHourly(time: h(10), windSpeed: 30),
          ],
          sea: const [],
          now: now,
        );

        expect(alerts, isEmpty);
      });

      test('given a null wave reading, buildForecastAlerts -> that hour is '
          'skipped, never treated as 0m', () {
        final alerts = buildForecastAlerts(
          weather: const [],
          sea: [
            aSeaHourly(time: h(9), waveHeight: 1.0),
            aSeaHourly(time: h(10), waveHeight: null),
          ],
          now: now,
        );

        expect(alerts, isEmpty);
      });

      test('given a null rain chance reading, buildForecastAlerts -> that hour '
          'is skipped, never treated as 0%', () {
        final alerts = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(9), rainChancePercent: null),
            aWeatherHourly(time: h(10), rainChancePercent: 80),
          ],
          sea: const [],
          now: now,
        );

        expect(alerts, isEmpty);
      });
    });

    test('given no hourly data at all, buildForecastAlerts -> no alerts', () {
      final alerts = buildForecastAlerts(
        weather: const [],
        sea: const [],
        now: now,
      );

      expect(alerts, isEmpty);
    });
  });
}
