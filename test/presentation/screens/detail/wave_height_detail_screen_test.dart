import 'package:beachiq/logic/swim_suitability.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/screens/detail/wave_height_detail_screen.dart';
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
        aSeaHourly(time: DateTime(2026, 1, 1, 11)),
        aSeaHourly(time: DateTime(2026, 1, 1, 12)),
        aSeaHourly(time: DateTime(2026, 1, 1, 13)),
      ];

      expect(nowHourIndex(hourly, DateTime(2026, 1, 1, 12)), 1);
    });

    test('given a time after every entry, nowHourIndex -> the last index', () {
      final hourly = [
        aSeaHourly(time: DateTime(2026, 1, 1, 11)),
        aSeaHourly(time: DateTime(2026, 1, 1, 12)),
      ];

      expect(nowHourIndex(hourly, DateTime(2026, 1, 1, 23)), 1);
    });
  });

  group('WaveHeightDetailScreen', () {
    testWidgets('renders the hero value from currentWaveHeightMeters', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          WaveHeightDetailScreen(
            hourly: const [],
            currentWaveHeightMeters: 0.9,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      expect(find.text('0.9'), findsWidgets);
      expect(find.text('m'), findsWidgets);
    });

    testWidgets('falls back to the nearest hourly entry when '
        'currentWaveHeightMeters is not supplied', (tester) async {
      await tester.pumpWidget(
        wrap(
          WaveHeightDetailScreen(
            hourly: [
              aSeaHourly(time: DateTime(2026, 1, 1, 12), waveHeight: 1.1),
            ],
            now: () => DateTime(2026, 1, 1, 12, 30),
          ),
        ),
      );

      expect(find.text('1.1'), findsWidgets);
    });

    testWidgets(
      'given a fully empty series and no current value, build -> shows '
      '"No data for this location" instead of a chart',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            WaveHeightDetailScreen(
              hourly: const [],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.text(noWaveDataForLocationText), findsOneWidget);
        expect(find.byType(HourlyMetricChart), findsNothing);
      },
    );

    testWidgets(
      'given every hourly entry has a null wave height, build -> still '
      'shows "No data for this location" (a fully empty series, not just '
      'an empty list)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            WaveHeightDetailScreen(
              hourly: [
                aSeaHourly(time: DateTime(2026, 1, 1, 11), waveHeight: null),
                aSeaHourly(time: DateTime(2026, 1, 1, 12), waveHeight: null),
              ],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.text(noWaveDataForLocationText), findsOneWidget);
        expect(find.byType(HourlyMetricChart), findsNothing);
      },
    );

    testWidgets('shows min/now/max summary labels from the hourly series', (
      tester,
    ) async {
      final now = DateTime(2026, 1, 1, 15);
      await tester.pumpWidget(
        wrap(
          WaveHeightDetailScreen(
            hourly: [
              aSeaHourly(
                time: now.subtract(const Duration(hours: 2)),
                waveHeight: 0.3,
              ),
              aSeaHourly(
                time: now.subtract(const Duration(hours: 1)),
                waveHeight: 1.4,
              ),
              aSeaHourly(time: now, waveHeight: 0.8),
            ],
            now: () => now,
          ),
        ),
      );

      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('0.3'), findsOneWidget);
      expect(find.text('1.4'), findsOneWidget);
      expect(find.text('0.8'), findsWidgets);
    });

    testWidgets(
      'passes the hourly wave height series (gaps included) and the "Now" '
      'index to the chart, with the 0.6 m/1.2 m swim thresholds',
      (tester) async {
        final now = DateTime(2026, 1, 1, 14);
        await tester.pumpWidget(
          wrap(
            WaveHeightDetailScreen(
              hourly: [
                aSeaHourly(time: DateTime(2026, 1, 1, 12), waveHeight: 0.4),
                aSeaHourly(time: DateTime(2026, 1, 1, 13), waveHeight: null),
                aSeaHourly(time: now, waveHeight: 1.3),
              ],
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.points.map((p) => p.value), [0.4, null, 1.3]);
        expect(chart.nowIndex, 2);
        expect(chart.thresholds, hasLength(2));
        expect(
          chart.thresholds.map((t) => t.value),
          containsAll([moderateWaveHeightM, highWaveHeightM]),
        );
      },
    );

    testWidgets(
      'given imperial units, build -> converts the hero value, summary '
      'row and chart thresholds to feet',
      (tester) async {
        final now = DateTime(2026, 1, 1, 12);
        await tester.pumpWidget(
          wrap(
            WaveHeightDetailScreen(
              hourly: [aSeaHourly(time: now, waveHeight: 1.0)],
              unitSystem: UnitSystem.imperial,
              now: () => now,
            ),
          ),
        );

        final expectedFeet = metersToFeet(1.0).toStringAsFixed(1);
        expect(find.text(expectedFeet), findsWidgets);
        expect(find.text('ft'), findsWidgets);

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(
          chart.thresholds.map((t) => t.value),
          containsAll([
            metersToFeet(moderateWaveHeightM),
            metersToFeet(highWaveHeightM),
          ]),
        );
      },
    );

    testWidgets('shows wave period and direction per hour under the chart', (
      tester,
    ) async {
      final now = DateTime(2026, 1, 1, 12);
      await tester.pumpWidget(
        wrap(
          WaveHeightDetailScreen(
            hourly: [
              aSeaHourly(
                time: now,
                waveHeight: 0.5,
                waveDirection: 270,
                wavePeriod: 6.2,
              ),
              aSeaHourly(
                time: now.add(const Duration(hours: 1)),
                waveHeight: 0.6,
                waveDirection: null,
                wavePeriod: null,
              ),
            ],
            now: () => now,
          ),
        ),
      );

      // Wave direction 270° ("coming from" W) -> "from W" for the "Now"
      // hour.
      expect(find.text('from W'), findsOneWidget);
      expect(find.text('6.2s'), findsOneWidget);
      // The second hour has no direction/period data at all.
      expect(find.text('No data'), findsOneWidget);
      expect(find.text('--'), findsWidgets);
    });

    testWidgets('back button returns to the previous screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WaveHeightDetailScreen(
                      hourly: const [],
                      currentWaveHeightMeters: 0.9,
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
      expect(find.byType(WaveHeightDetailScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(WaveHeightDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
