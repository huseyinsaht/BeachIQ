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

      test('given wind rising >= ${windRiseThresholdKmh}km/h gradually over 2 '
          'hours with no single hour-to-hour step reaching the threshold, '
          'buildForecastAlerts -> one wind alert', () {
        final alerts = buildForecastAlerts(
          weather: [
            aWeatherHourly(time: h(9), windSpeed: 5),
            aWeatherHourly(time: h(10), windSpeed: 11), // +6, under alone
            aWeatherHourly(time: h(11), windSpeed: 17), // +6, under alone
            // but hour 11 vs hour 9 (two back) is +12, over the threshold
          ],
          sea: const [],
          now: now,
        );

        expect(alerts, hasLength(1));
        expect(alerts.single.type, ForecastAlertType.wind);
        expect(alerts.single.severity, ForecastAlertSeverity.moderate);
        expect(alerts.single.end, h(11));
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

    group('current rule', () {
      test('given current speed rising >= ${currentRiseThresholdKmh}km/h '
          'within an hour, buildForecastAlerts -> one current alert', () {
        final sea = [
          aSeaHourly(time: h(9), currentVelocity: 1.0),
          aSeaHourly(time: h(10), currentVelocity: 3.5), // +2.5
        ];

        final alerts = buildForecastAlerts(
          weather: const [],
          sea: sea,
          now: now,
        );

        expect(alerts, hasLength(1));
        expect(alerts.single.type, ForecastAlertType.current);
        expect(alerts.single.severity, ForecastAlertSeverity.moderate);
        expect(alerts.single.start, h(9));
        expect(alerts.single.end, h(10));
      });

      test('given current speed rising gradually over 2 hours with no single '
          'hour-to-hour step reaching the threshold, buildForecastAlerts -> '
          'one current alert', () {
        final alerts = buildForecastAlerts(
          weather: const [],
          sea: [
            aSeaHourly(time: h(9), currentVelocity: 1.0),
            aSeaHourly(time: h(10), currentVelocity: 2.2), // +1.2, under
            aSeaHourly(time: h(11), currentVelocity: 3.4), // +1.2, under
            // but hour 11 vs hour 9 (two back) is +2.4, over threshold
          ],
          now: now,
        );

        expect(alerts, hasLength(1));
        expect(alerts.single.type, ForecastAlertType.current);
      });

      test('given current speed that does not rise enough, '
          'buildForecastAlerts -> no current alert', () {
        final alerts = buildForecastAlerts(
          weather: const [],
          sea: [
            aSeaHourly(time: h(9), currentVelocity: 1.0),
            aSeaHourly(time: h(10), currentVelocity: 1.5),
          ],
          now: now,
        );

        expect(alerts, isEmpty);
      });

      test('given a null current reading, buildForecastAlerts -> that hour '
          'is skipped, never treated as 0 km/h', () {
        final alerts = buildForecastAlerts(
          weather: const [],
          sea: [
            aSeaHourly(time: h(9)), // currentVelocity null
            aSeaHourly(time: h(10), currentVelocity: 5.0),
          ],
          now: now,
        );

        expect(alerts, isEmpty);
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
            // +0 vs hour 11 and +9 vs hour 10 (two back): neither reaches
            // the rise threshold, so this hour does not extend the window.
            aWeatherHourly(time: h(12), windSpeed: 25),
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

  group('buildForecastAlerts daylight filter (issue #229)', () {
    test('given an alert window entirely outside every daylight window, '
        'buildForecastAlerts -> drops it', () {
      final alerts = buildForecastAlerts(
        weather: [
          // A night-time wind crossing: 23:00 -> 00:00, well outside the
          // day's 06:00-20:00 daylight window below.
          aWeatherHourly(time: DateTime(2024, 1, 1, 23), windSpeed: 10),
          aWeatherHourly(time: DateTime(2024, 1, 2, 0), windSpeed: 45),
        ],
        sea: const [],
        daylight: [
          aDaylightWindow(
            sunrise: DateTime(2024, 1, 1, 6),
            sunset: DateTime(2024, 1, 1, 20),
          ),
          aDaylightWindow(
            sunrise: DateTime(2024, 1, 2, 6),
            sunset: DateTime(2024, 1, 2, 20),
          ),
        ],
        now: now,
      );

      expect(alerts, isEmpty);
    });

    test('given an alert window entirely inside a daylight window, '
        'buildForecastAlerts -> keeps it', () {
      final alerts = buildForecastAlerts(
        weather: [
          aWeatherHourly(time: h(9), windSpeed: 10),
          aWeatherHourly(time: h(10), windSpeed: 45),
        ],
        sea: const [],
        daylight: [
          aDaylightWindow(
            sunrise: DateTime(2024, 1, 1, 6),
            sunset: DateTime(2024, 1, 1, 20),
          ),
        ],
        now: now,
      );

      expect(alerts, hasLength(1));
    });

    test('given an alert window exactly at the sunrise/sunset boundary, '
        'buildForecastAlerts -> keeps it (inclusive bounds)', () {
      final alerts = buildForecastAlerts(
        weather: [
          aWeatherHourly(time: DateTime(2024, 1, 1, 6), windSpeed: 10),
          aWeatherHourly(time: DateTime(2024, 1, 1, 7), windSpeed: 45),
        ],
        sea: const [],
        daylight: [
          aDaylightWindow(
            sunrise: DateTime(2024, 1, 1, 6),
            sunset: DateTime(2024, 1, 1, 20),
          ),
        ],
        now: DateTime(2024, 1, 1, 5, 30),
      );

      expect(alerts, hasLength(1));
    });

    test('given today\'s sunset has already passed, buildForecastAlerts -> '
        'still matches an alert inside the next day\'s daylight window', () {
      final alerts = buildForecastAlerts(
        weather: [
          // 05:00 -> 06:00 the next day, inside day 2's 06:00-20:00
          // window below (day 1's window ended at 20:00 the day before).
          aWeatherHourly(time: DateTime(2024, 1, 2, 6), windSpeed: 10),
          aWeatherHourly(time: DateTime(2024, 1, 2, 7), windSpeed: 45),
        ],
        sea: const [],
        daylight: [
          aDaylightWindow(
            sunrise: DateTime(2024, 1, 1, 6),
            sunset: DateTime(2024, 1, 1, 20),
          ),
          aDaylightWindow(
            sunrise: DateTime(2024, 1, 2, 6),
            sunset: DateTime(2024, 1, 2, 20),
          ),
        ],
        // Already past day 1's sunset.
        now: DateTime(2024, 1, 1, 21),
      );

      expect(alerts, hasLength(1));
    });

    test('given an empty daylight list (API returned no sunrise/sunset), '
        'buildForecastAlerts -> falls back to unfiltered behaviour', () {
      final alerts = buildForecastAlerts(
        weather: [
          aWeatherHourly(time: DateTime(2024, 1, 1, 23), windSpeed: 10),
          aWeatherHourly(time: DateTime(2024, 1, 2, 0), windSpeed: 45),
        ],
        sea: const [],
        now: now,
      );

      expect(alerts, hasLength(1));
    });
  });

  group('buildNextHourNote (issue #229)', () {
    test('given a wind crossing between the current hour and the next, '
        'buildNextHourNote -> a note for it', () {
      final note = buildNextHourNote(
        weather: [
          aWeatherHourly(time: h(8), windSpeed: 10),
          aWeatherHourly(time: h(9), windSpeed: 45),
        ],
        sea: const [],
        now: DateTime(2024, 1, 1, 8, 30),
      );

      expect(note, isNotNull);
      expect(note!.type, ForecastAlertType.wind);
      expect(note.start, h(8));
      expect(note.end, h(9));
    });

    test('given no notable change between the current hour and the next, '
        'buildNextHourNote -> null', () {
      final note = buildNextHourNote(
        weather: [
          aWeatherHourly(time: h(8), windSpeed: 10),
          aWeatherHourly(time: h(9), windSpeed: 11),
        ],
        sea: const [],
        now: DateTime(2024, 1, 1, 8, 30),
      );

      expect(note, isNull);
    });

    test('given no hourly entry at or before now, buildNextHourNote -> null '
        '(nothing to anchor "the next hour" to yet)', () {
      final note = buildNextHourNote(
        weather: [
          aWeatherHourly(time: h(9), windSpeed: 10),
          aWeatherHourly(time: h(10), windSpeed: 45),
        ],
        sea: const [],
        now: DateTime(2024, 1, 1, 8, 30),
      );

      expect(note, isNull);
    });

    test('given a null reading on either side of the current/next hour pair, '
        'buildNextHourNote -> that rule is skipped, never treated as 0', () {
      final note = buildNextHourNote(
        weather: const [],
        sea: [
          aSeaHourly(time: h(8), waveHeight: null),
          aSeaHourly(time: h(9), waveHeight: 2.0),
        ],
        now: DateTime(2024, 1, 1, 8, 30),
      );

      expect(note, isNull);
    });

    test('given both a wind and a wave change for the same hour pair, '
        'buildNextHourNote -> picks the most severe one', () {
      final note = buildNextHourNote(
        weather: [
          // Moderate: rises by >= windRiseThresholdKmh without crossing.
          aWeatherHourly(time: h(8), windSpeed: 5),
          aWeatherHourly(time: h(9), windSpeed: 16),
        ],
        sea: [
          // High: crosses highWaveHeightM.
          aSeaHourly(time: h(8), waveHeight: 0.5),
          aSeaHourly(time: h(9), waveHeight: highWaveHeightM + 0.5),
        ],
        now: DateTime(2024, 1, 1, 8, 30),
      );

      expect(note, isNotNull);
      expect(note!.type, ForecastAlertType.waves);
      expect(note.severity, ForecastAlertSeverity.high);
    });

    test(
      'given the same inputs and now, buildNextHourNote -> is deterministic',
      () {
        final weather = [
          aWeatherHourly(time: h(8), windSpeed: 10),
          aWeatherHourly(time: h(9), windSpeed: 45),
        ];

        final first = buildNextHourNote(
          weather: weather,
          sea: const [],
          now: DateTime(2024, 1, 1, 8, 30),
        );
        final second = buildNextHourNote(
          weather: weather,
          sea: const [],
          now: DateTime(2024, 1, 1, 8, 30),
        );

        expect(first!.message, second!.message);
        expect(first.start, second.start);
        expect(first.end, second.end);
      },
    );

    test('given it is still shown after sunset, buildNextHourNote -> does not '
        'take a daylight parameter and is unaffected by time of day', () {
      // 22:00 -> 23:00, well after any plausible sunset, still produces a
      // note — buildNextHourNote has no daylight filtering at all.
      final note = buildNextHourNote(
        weather: [
          aWeatherHourly(time: DateTime(2024, 1, 1, 22), windSpeed: 10),
          aWeatherHourly(time: DateTime(2024, 1, 1, 23), windSpeed: 45),
        ],
        sea: const [],
        now: DateTime(2024, 1, 1, 22, 15),
      );

      expect(note, isNotNull);
    });
  });
}
