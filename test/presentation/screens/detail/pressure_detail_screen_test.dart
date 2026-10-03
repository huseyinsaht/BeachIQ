import 'package:beachiq/presentation/screens/detail/pressure_detail_screen.dart';
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

    test('given a time between two entries, nowHourIndex -> the one at or '
        'before it', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 11)),
        aWeatherHourly(time: DateTime(2026, 1, 1, 12)),
      ];

      expect(nowHourIndex(hourly, DateTime(2026, 1, 1, 12, 45)), 1);
    });

    test('given a time before every entry, nowHourIndex -> 0', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 11)),
        aWeatherHourly(time: DateTime(2026, 1, 1, 12)),
      ];

      expect(nowHourIndex(hourly, DateTime(2026, 1, 1, 0)), 0);
    });

    test('given a time after every entry, nowHourIndex -> the last index', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 11)),
        aWeatherHourly(time: DateTime(2026, 1, 1, 12)),
      ];

      expect(nowHourIndex(hourly, DateTime(2026, 1, 1, 23)), 1);
    });
  });

  group('PressureDetailScreen', () {
    testWidgets('renders the hero value and unit from currentPressureHpa', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          PressureDetailScreen(
            hourly: const [],
            currentPressureHpa: 1013,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      expect(find.text('1013'), findsOneWidget);
      expect(find.text('hPa'), findsOneWidget);
    });

    testWidgets(
      'falls back to the nearest hourly entry when currentPressureHpa is '
      'not supplied',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            PressureDetailScreen(
              hourly: [
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 12),
                  pressureHpa: 1009,
                ),
              ],
              now: () => DateTime(2026, 1, 1, 12, 30),
            ),
          ),
        );

        expect(find.text('1009'), findsOneWidget);
      },
    );

    testWidgets(
      'shows a "--" hero value and no unit when there is no pressure data '
      'at all',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            PressureDetailScreen(
              hourly: const [],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        // '--' also appears in the min/now/max summary row (there's no
        // data for any of those either), so this only asserts that the
        // hero value/unit don't render a fabricated number.
        expect(find.text('--'), findsWidgets);
        expect(find.text('hPa'), findsNothing);
      },
    );

    testWidgets('shows a rising trend when pressure climbed over the '
        'lookback window', (tester) async {
      final now = DateTime(2026, 1, 1, 15);
      await tester.pumpWidget(
        wrap(
          PressureDetailScreen(
            hourly: [
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 3)),
                pressureHpa: 1008,
              ),
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 2)),
                pressureHpa: 1010,
              ),
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 1)),
                pressureHpa: 1012,
              ),
              aWeatherHourly(time: now, pressureHpa: 1014),
            ],
            now: () => now,
          ),
        ),
      );

      // The explanation paragraph also mentions "Rising pressure..." in
      // prose, so this matches the trend line's own "Rising — " wording
      // specifically rather than any text containing the word.
      expect(find.textContaining('Rising — '), findsOneWidget);
    });

    testWidgets('shows a falling trend when pressure dropped over the '
        'lookback window', (tester) async {
      final now = DateTime(2026, 1, 1, 15);
      await tester.pumpWidget(
        wrap(
          PressureDetailScreen(
            hourly: [
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 3)),
                pressureHpa: 1014,
              ),
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 2)),
                pressureHpa: 1012,
              ),
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 1)),
                pressureHpa: 1010,
              ),
              aWeatherHourly(time: now, pressureHpa: 1008),
            ],
            now: () => now,
          ),
        ),
      );

      expect(find.textContaining('Falling'), findsOneWidget);
    });

    testWidgets('shows a steady trend when pressure barely moved over the '
        'lookback window', (tester) async {
      final now = DateTime(2026, 1, 1, 15);
      await tester.pumpWidget(
        wrap(
          PressureDetailScreen(
            hourly: [
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 3)),
                pressureHpa: 1013.2,
              ),
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 2)),
                pressureHpa: 1013.3,
              ),
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 1)),
                pressureHpa: 1013.1,
              ),
              aWeatherHourly(time: now, pressureHpa: 1013.0),
            ],
            now: () => now,
          ),
        ),
      );

      expect(find.textContaining('Steady'), findsOneWidget);
    });

    testWidgets(
      'shows a "not enough data" trend message when there is no earlier '
      'reading to compare against',
      (tester) async {
        final now = DateTime(2026, 1, 1, 15);
        await tester.pumpWidget(
          wrap(
            PressureDetailScreen(
              hourly: [aWeatherHourly(time: now, pressureHpa: 1013)],
              now: () => now,
            ),
          ),
        );

        expect(find.textContaining('Not enough data'), findsOneWidget);
      },
    );

    testWidgets('shows min/now/max summary labels from the hourly series', (
      tester,
    ) async {
      final now = DateTime(2026, 1, 1, 15);
      await tester.pumpWidget(
        wrap(
          PressureDetailScreen(
            hourly: [
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 2)),
                pressureHpa: 1005,
              ),
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 1)),
                pressureHpa: 1020,
              ),
              aWeatherHourly(time: now, pressureHpa: 1013),
            ],
            now: () => now,
          ),
        ),
      );

      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('1005 hPa'), findsOneWidget);
      expect(find.text('1020 hPa'), findsOneWidget);
    });

    testWidgets(
      'passes the hourly pressure series (gaps included) and the "Now" '
      'index to the chart',
      (tester) async {
        final now = DateTime(2026, 1, 1, 14);
        await tester.pumpWidget(
          wrap(
            PressureDetailScreen(
              hourly: [
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 12),
                  pressureHpa: 1010,
                ),
                aWeatherHourly(
                  time: DateTime(2026, 1, 1, 13),
                  pressureHpa: null,
                ),
                aWeatherHourly(time: now, pressureHpa: 1013),
              ],
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.points.map((p) => p.value), [1010.0, null, 1013.0]);
        expect(chart.nowIndex, 2);
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
                    builder: (_) => PressureDetailScreen(
                      hourly: const [],
                      currentPressureHpa: 1013,
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
      expect(find.byType(PressureDetailScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(PressureDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
