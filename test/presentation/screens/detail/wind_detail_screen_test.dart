import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/screens/detail/wind_detail_screen.dart';
import 'package:beachiq/presentation/widgets/hourly_metric_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  group('nowHourIndex', () {
    test('given an empty list, nowHourIndex -> null', () {
      expect(nowHourIndex(const [], DateTime(2026, 1, 1, 12)), isNull);
    });

    test('given a time exactly matching an entry, nowHourIndex -> that '
        'entry', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 11)),
        aWeatherHourly(time: DateTime(2026, 1, 1, 12)),
        aWeatherHourly(time: DateTime(2026, 1, 1, 13)),
      ];

      expect(nowHourIndex(hourly, DateTime(2026, 1, 1, 12)), 1);
    });
  });

  group('WindDetailScreen', () {
    testWidgets('renders the hero value from currentWindSpeedKmh', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WindDetailScreen(
            hourly: const [],
            currentWindSpeedKmh: 18,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      expect(find.text('18'), findsWidgets);
      expect(find.text('km/h'), findsOneWidget);
    });

    testWidgets(
      'falls back to the nearest hourly entry when currentWindSpeedKmh is '
      'not supplied',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            WindDetailScreen(
              hourly: [
                aWeatherHourly(time: DateTime(2026, 1, 1, 12), windSpeed: 25),
              ],
              now: () => DateTime(2026, 1, 1, 12, 30),
            ),
          ),
        );

        expect(find.text('25'), findsWidgets);
      },
    );

    testWidgets(
      'shows a "--" hero value when there is no wind data at all',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            WindDetailScreen(
              hourly: const [],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.text('--'), findsWidgets);
      },
    );

    testWidgets('shows a "Calm" status below the moderate threshold', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WindDetailScreen(
            hourly: const [],
            currentWindSpeedKmh: 10,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      expect(find.textContaining('Calm — '), findsOneWidget);
    });

    testWidgets(
      'shows a "Moderate" status between the two thresholds',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            WindDetailScreen(
              hourly: const [],
              currentWindSpeedKmh: 25,
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.textContaining('Moderate — '), findsOneWidget);
      },
    );

    testWidgets('shows a "Strong" status above the high threshold', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WindDetailScreen(
            hourly: const [],
            currentWindSpeedKmh: 45,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      expect(find.textContaining('Strong — '), findsOneWidget);
    });

    testWidgets('converts the hero value and thresholds to mph in the '
        'imperial unit system', (tester) async {
      await tester.pumpWidget(
        wrap(
          WindDetailScreen(
            hourly: const [],
            currentWindSpeedKmh: 40, // ~25 mph
            unitSystem: UnitSystem.imperial,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      expect(find.text('25'), findsWidgets);
      expect(find.text('mph'), findsOneWidget);
    });

    testWidgets(
      'passes the hourly wind speed series (gaps included), the "Now" '
      'index and the two threshold lines to the chart',
      (tester) async {
        final now = DateTime(2026, 1, 1, 14);
        await tester.pumpWidget(
          wrap(
            WindDetailScreen(
              hourly: [
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 12),
                  windSpeed: 10,
                ),
                aWeatherHourly(time: DateTime(2026, 1, 1, 13), windSpeed: null),
                aWeatherHourly(time: now, windSpeed: 30),
              ],
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart).first,
        );
        expect(chart.points.map((p) => p.value), [10.0, null, 30.0]);
        expect(chart.nowIndex, 2);
        expect(chart.thresholds, hasLength(2));
        expect(chart.thresholds[0].value, 20.0);
        expect(chart.thresholds[1].value, 40.0);
      },
    );

    testWidgets(
      'renders a second chart for gusts (with null gaps), keyed separately '
      'from the speed chart',
      (tester) async {
        final now = DateTime(2026, 1, 1, 12);
        await tester.pumpWidget(
          wrap(
            WindDetailScreen(
              hourly: [
                aWeatherHourly(time: now, windSpeed: 10, windGusts: 20),
                aWeatherHourly(
                  time: now.add(const Duration(hours: 1)),
                  windSpeed: 12,
                  windGusts: null,
                ),
              ],
              now: () => now,
            ),
          ),
        );

        expect(find.text('Gusts'), findsOneWidget);
        final gustChart = tester.widget<HourlyMetricChart>(
          find.byKey(const Key('wind-gusts-chart')),
        );
        expect(gustChart.points.map((p) => p.value), [20.0, null]);
      },
    );

    testWidgets(
      'omits the gusts chart entirely when no hour has gust data',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            WindDetailScreen(
              hourly: [
                aWeatherHourly(time: DateTime(2026, 1, 1, 12), windSpeed: 10),
              ],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.text('Gusts'), findsNothing);
        expect(find.byKey(const Key('wind-gusts-chart')), findsNothing);
      },
    );

    testWidgets(
      'passes a y-axis value formatter and unit (km/h) to both charts '
      '(issue #212)',
      (tester) async {
        final now = DateTime(2026, 1, 1, 12);
        await tester.pumpWidget(
          wrap(
            WindDetailScreen(
              hourly: [
                aWeatherHourly(time: now, windSpeed: 10, windGusts: 20),
              ],
              now: () => now,
            ),
          ),
        );

        final speedChart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart).first,
        );
        expect(speedChart.unitLabel, 'km/h');
        expect(speedChart.valueFormatter!(12), '12');

        final gustChart = tester.widget<HourlyMetricChart>(
          find.byKey(const Key('wind-gusts-chart')),
        );
        expect(gustChart.unitLabel, 'km/h');
      },
    );

    testWidgets(
      'given imperial units, passes a unit (mph) to the chart (issue #212)',
      (tester) async {
        final now = DateTime(2026, 1, 1, 12);
        await tester.pumpWidget(
          wrap(
            WindDetailScreen(
              hourly: [aWeatherHourly(time: now, windSpeed: 10)],
              unitSystem: UnitSystem.imperial,
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart).first,
        );
        expect(chart.unitLabel, 'mph');
      },
    );

    testWidgets('back button returns to the previous screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WindDetailScreen(
                      hourly: const [],
                      currentWindSpeedKmh: 18,
                      now: () => DateTime(2026, 1, 1, 12),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(WindDetailScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(WindDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
