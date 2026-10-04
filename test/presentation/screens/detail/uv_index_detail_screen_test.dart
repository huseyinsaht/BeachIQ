import 'package:beachiq/presentation/screens/detail/uv_index_detail_screen.dart';
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

    test('given a time after every entry, nowHourIndex -> the last index', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 11)),
        aWeatherHourly(time: DateTime(2026, 1, 1, 12)),
      ];

      expect(nowHourIndex(hourly, DateTime(2026, 1, 1, 23)), 1);
    });
  });

  group('UvIndexDetailScreen', () {
    testWidgets('renders the hero value from currentUvIndex', (tester) async {
      await tester.pumpWidget(
        wrap(
          UvIndexDetailScreen(
            hourly: const [],
            currentUvIndex: 4.5,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      // With no hourly series at all, the "Now" summary entry falls back
      // to the same reading as the hero value, so "4.5" legitimately
      // renders twice (hero + summary) - this only asserts it renders,
      // not that it's unique, mirroring how the pressure screen's own
      // "--" test handles the same kind of expected duplicate.
      expect(find.text('4.5'), findsWidgets);
    });

    testWidgets(
      'falls back to the nearest hourly entry when currentUvIndex is not '
      'supplied',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            UvIndexDetailScreen(
              hourly: [
                aWeatherHourly(time: DateTime(2026, 1, 1, 12), uvIndex: 6.0),
              ],
              now: () => DateTime(2026, 1, 1, 12, 30),
            ),
          ),
        );

        // A single hourly entry means hero/min/now/max all collapse to
        // the same "6.0" reading, so it renders more than once.
        expect(find.text('6.0'), findsWidgets);
      },
    );

    testWidgets(
      'shows a "--" hero value and a "not enough data" tip when there is '
      'no UV data at all',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            UvIndexDetailScreen(
              hourly: const [],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        // '--' also appears in the min/now/max summary row (there's no
        // data for any of those either), so this only asserts it renders
        // somewhere, and separately asserts the "not enough data" copy.
        expect(find.text('--'), findsWidgets);
        expect(
          find.textContaining(
            'Not enough data yet to show a '
            'sun-protection tip.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows a "Low" hint when the current UV index is in the '
        'low band', (tester) async {
      final now = DateTime(2026, 1, 1, 12);
      await tester.pumpWidget(
        wrap(
          UvIndexDetailScreen(
            hourly: [aWeatherHourly(time: now, uvIndex: 1.5)],
            now: () => now,
          ),
        ),
      );

      expect(find.textContaining('Low — '), findsOneWidget);
    });

    testWidgets('shows a "Moderate" hint when the current UV index is in '
        'the moderate band', (tester) async {
      final now = DateTime(2026, 1, 1, 12);
      await tester.pumpWidget(
        wrap(
          UvIndexDetailScreen(
            hourly: [aWeatherHourly(time: now, uvIndex: 4.0)],
            now: () => now,
          ),
        ),
      );

      expect(find.textContaining('Moderate — '), findsOneWidget);
    });

    testWidgets('shows an "Extreme" hint when the current UV index is 11 '
        'or above', (tester) async {
      final now = DateTime(2026, 1, 1, 12);
      await tester.pumpWidget(
        wrap(
          UvIndexDetailScreen(
            hourly: [aWeatherHourly(time: now, uvIndex: 12.0)],
            now: () => now,
          ),
        ),
      );

      expect(find.textContaining('Extreme — '), findsOneWidget);
    });

    testWidgets('shows min/now/max summary labels from the hourly series', (
      tester,
    ) async {
      final now = DateTime(2026, 1, 1, 15);
      await tester.pumpWidget(
        wrap(
          UvIndexDetailScreen(
            hourly: [
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 2)),
                uvIndex: 1.0,
              ),
              aWeatherHourly(
                time: now.subtract(const Duration(hours: 1)),
                uvIndex: 7.5,
              ),
              aWeatherHourly(time: now, uvIndex: 3.0),
            ],
            now: () => now,
          ),
        ),
      );

      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('1.0'), findsOneWidget);
      expect(find.text('7.5'), findsOneWidget);
    });

    testWidgets(
      'passes the hourly UV series (gaps included), the "Now" index and '
      'the five colored bands to the chart',
      (tester) async {
        final now = DateTime(2026, 1, 1, 14);
        await tester.pumpWidget(
          wrap(
            UvIndexDetailScreen(
              hourly: [
                aWeatherHourly(time: DateTime(2026, 1, 1, 12), uvIndex: 2.0),
                aWeatherHourly(time: DateTime(2026, 1, 1, 13), uvIndex: null),
                aWeatherHourly(time: now, uvIndex: 5.0),
              ],
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.points.map((p) => p.value), [2.0, null, 5.0]);
        expect(chart.nowIndex, 2);
        expect(chart.valueBands, hasLength(5));
        expect(
          chart.valueBands.map((b) => b.label),
          containsAll(['Low', 'Moderate', 'High', 'Very high', 'Extreme']),
        );
        // The topmost band ("Extreme") is open-ended.
        expect(
          chart.valueBands.firstWhere((b) => b.label == 'Extreme').max,
          isNull,
        );
      },
    );

    testWidgets(
      'passes a y-axis value formatter and no unit to the chart (UV index '
      'has none) (issue #212)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            UvIndexDetailScreen(
              hourly: [
                aWeatherHourly(time: DateTime(2026, 1, 1, 12), uvIndex: 5.2),
              ],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.unitLabel, isNull);
        expect(chart.valueFormatter, isNotNull);
        expect(chart.valueFormatter!(5.2), '5.2');
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
                    builder: (_) => UvIndexDetailScreen(
                      hourly: const [],
                      currentUvIndex: 4.5,
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
      expect(find.byType(UvIndexDetailScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(UvIndexDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
