import 'package:beachiq/presentation/screens/detail/rain_chance_detail_screen.dart';
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

  group('RainChanceDetailScreen', () {
    testWidgets('renders the hero value from currentRainChancePercent', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          RainChanceDetailScreen(
            hourly: const [],
            currentRainChancePercent: 35,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      expect(find.text('35%'), findsWidgets);
    });

    testWidgets(
      'falls back to the nearest hourly entry when '
      'currentRainChancePercent is not supplied',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            RainChanceDetailScreen(
              hourly: [
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 12),
                  rainChancePercent: 60,
                ),
              ],
              now: () => DateTime(2026, 1, 1, 12, 30),
            ),
          ),
        );

        expect(find.text('60%'), findsWidgets);
      },
    );

    testWidgets(
      'shows a "--" hero value when there is no rain data at all',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            RainChanceDetailScreen(
              hourly: const [],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.text('--'), findsWidgets);
      },
    );

    testWidgets(
      'shows "No rain expected today." when no upcoming hour qualifies',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            RainChanceDetailScreen(
              hourly: [
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 12),
                  rainChancePercent: 10,
                ),
              ],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.text('No rain expected today.'), findsOneWidget);
      },
    );

    testWidgets(
      'shows the actual upcoming window in the summary',
      (tester) async {
        final now = DateTime(2026, 1, 1, 12);
        await tester.pumpWidget(
          wrap(
            RainChanceDetailScreen(
              hourly: [
                aWeatherHourly(time: now, rainChancePercent: 10),
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 14),
                  rainChancePercent: 55,
                ),
              ],
              now: () => now,
            ),
          ),
        );

        expect(
          find.text('Rain likely between 14:00 and 15:00.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'includes the current hour\'s own qualifying reading in the summary '
      'even when "now" is mid-hour (not dropped just because its '
      'timestamp is before "now")',
      (tester) async {
        // now (14:30) falls inside the 14:00 hour's bucket (14:00-15:00),
        // so that entry is still "now", not "the past" - the same entry
        // nowHourIndex/the hero value already treat as current.
        final now = DateTime(2026, 1, 1, 14, 30);
        await tester.pumpWidget(
          wrap(
            RainChanceDetailScreen(
              hourly: [
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 14),
                  rainChancePercent: 80,
                ),
              ],
              now: () => now,
            ),
          ),
        );

        expect(
          find.text('Rain likely between 14:00 and 15:00.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ignores a qualifying window that is entirely before now',
      (tester) async {
        final now = DateTime(2026, 1, 1, 15);
        await tester.pumpWidget(
          wrap(
            RainChanceDetailScreen(
              hourly: [
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 9),
                  rainChancePercent: 80,
                ),
              ],
              now: () => now,
            ),
          ),
        );

        expect(find.text('No rain expected today.'), findsOneWidget);
      },
    );

    testWidgets('shows min/now/max summary labels from the hourly series', (
      tester,
    ) async {
      final now = DateTime(2026, 1, 1, 15);
      await tester.pumpWidget(
        wrap(
          RainChanceDetailScreen(
            hourly: [
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 2)),
                rainChancePercent: 5,
              ),
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 1)),
                rainChancePercent: 80,
              ),
              aWeatherHourly(time: now, rainChancePercent: 20),
            ],
            now: () => now,
          ),
        ),
      );

      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets(
      'passes the hourly rain chance series (gaps included), the "Now" '
      'index and the two threshold lines to the chart',
      (tester) async {
        final now = DateTime(2026, 1, 1, 14);
        await tester.pumpWidget(
          wrap(
            RainChanceDetailScreen(
              hourly: [
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 12),
                  rainChancePercent: 20,
                ),
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 13),
                  rainChancePercent: null,
                ),
                aWeatherHourly(time: now, rainChancePercent: 60),
              ],
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.points.map((p) => p.value), [20.0, null, 60.0]);
        expect(chart.nowIndex, 2);
        expect(chart.thresholds, hasLength(2));
        expect(chart.thresholds[0].value, 40.0);
        expect(chart.thresholds[1].value, 70.0);
      },
    );

    testWidgets(
      'passes a y-axis value formatter and unit (%) to the chart (issue '
      '#212)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            RainChanceDetailScreen(
              hourly: [
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 12),
                  rainChancePercent: 40,
                ),
              ],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.unitLabel, '%');
        expect(chart.valueFormatter!(40), '40');
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
                    builder: (_) => RainChanceDetailScreen(
                      hourly: const [],
                      currentRainChancePercent: 35,
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
      expect(find.byType(RainChanceDetailScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(RainChanceDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
