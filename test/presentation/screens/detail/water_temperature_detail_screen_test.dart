import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/screens/detail/water_temperature_detail_screen.dart';
import 'package:beachiq/presentation/widgets/hourly_metric_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  group('waterTempBandFor', () {
    test('below 16 C -> cold', () {
      expect(waterTempBandFor(10), WaterTempBand.cold);
      expect(waterTempBandFor(15.9), WaterTempBand.cold);
    });

    test('exactly 16 C (inclusive) -> cool', () {
      expect(waterTempBandFor(16), WaterTempBand.cool);
    });

    test('between 16 and 20 C -> cool', () {
      expect(waterTempBandFor(18), WaterTempBand.cool);
      expect(waterTempBandFor(19.9), WaterTempBand.cool);
    });

    test('exactly 20 C (inclusive) -> pleasant', () {
      expect(waterTempBandFor(20), WaterTempBand.pleasant);
    });

    test('between 20 and 24 C -> pleasant', () {
      expect(waterTempBandFor(22), WaterTempBand.pleasant);
      expect(waterTempBandFor(23.9), WaterTempBand.pleasant);
    });

    test('exactly 24 C (inclusive) -> warm', () {
      expect(waterTempBandFor(24), WaterTempBand.warm);
    });

    test('above 24 C -> warm', () {
      expect(waterTempBandFor(30), WaterTempBand.warm);
    });
  });

  group('waterTempBandLabel / waterTempComfortHint', () {
    test('every band has a label and a non-empty, distinct hint', () {
      final hints = <String>{};
      for (final band in WaterTempBand.values) {
        expect(waterTempBandLabel(band), isNotEmpty);
        final hint = waterTempComfortHint(band);
        expect(hint, isNotEmpty);
        expect(hints.add(hint), isTrue, reason: 'duplicate hint for $band');
      }
    });
  });

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
  });

  group('WaterTemperatureDetailScreen', () {
    testWidgets('renders the hero value from '
        'currentWaterTemperatureCelsius', (tester) async {
      await tester.pumpWidget(
        wrap(
          WaterTemperatureDetailScreen(
            hourly: const [],
            currentWaterTemperatureCelsius: 22,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      expect(find.text('22'), findsWidgets);
      expect(find.text('°C'), findsOneWidget);
      expect(find.textContaining('Pleasant — '), findsOneWidget);
    });

    testWidgets(
      'falls back to the nearest hourly entry when '
      'currentWaterTemperatureCelsius is not supplied',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            WaterTemperatureDetailScreen(
              hourly: [
                aSeaHourly(
                  time: DateTime(2026, 1, 1, 12),
                  seaSurfaceTemperature: 14,
                ),
              ],
              now: () => DateTime(2026, 1, 1, 12, 30),
            ),
          ),
        );

        expect(find.text('14'), findsWidgets);
        expect(find.textContaining('Cold — '), findsOneWidget);
      },
    );

    testWidgets(
      'shows the "no data for this location" message when every hour is '
      'null',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            WaterTemperatureDetailScreen(
              hourly: [
                aSeaHourly(time: DateTime(2026, 1, 1, 12)),
                aSeaHourly(time: DateTime(2026, 1, 1, 13)),
              ],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.text(noWaterTempDataForLocationText), findsOneWidget);
        expect(find.byType(HourlyMetricChart), findsNothing);
        expect(
          find.textContaining('Not enough data yet to show a comfort tip.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('converts the hero value, unit and band edges to '
        'Fahrenheit in the imperial unit system', (tester) async {
      await tester.pumpWidget(
        wrap(
          WaterTemperatureDetailScreen(
            hourly: [
              aSeaHourly(
                time: DateTime(2026, 1, 1, 12),
                seaSurfaceTemperature: 22,
              ),
            ],
            unitSystem: UnitSystem.imperial,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      // 22C = 71.6F, rounds to 72.
      expect(find.text('72'), findsWidgets);
      expect(find.text('°F'), findsOneWidget);

      final chart = tester.widget<HourlyMetricChart>(
        find.byType(HourlyMetricChart),
      );
      // 16C -> 60.8F, 20C -> 68F, 24C -> 75.2F.
      expect(chart.valueBands[0].max, closeTo(60.8, 0.01));
      expect(chart.valueBands[1].max, closeTo(68.0, 0.01));
      expect(chart.valueBands[2].max, closeTo(75.2, 0.01));
      expect(chart.valueBands[3].max, isNull);
    });

    testWidgets(
      'passes the hourly series (gaps included) and the "Now" index to '
      'the chart, with the topmost band open-ended',
      (tester) async {
        final now = DateTime(2026, 1, 1, 14);
        await tester.pumpWidget(
          wrap(
            WaterTemperatureDetailScreen(
              hourly: [
                aSeaHourly(
                  time: DateTime(2026, 1, 1, 12),
                  seaSurfaceTemperature: 18,
                ),
                aSeaHourly(
                  time: DateTime(2026, 1, 1, 13),
                  seaSurfaceTemperature: null,
                ),
                aSeaHourly(time: now, seaSurfaceTemperature: 25),
              ],
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.points.map((p) => p.value), [18.0, null, 25.0]);
        expect(chart.nowIndex, 2);
        expect(chart.valueBands, hasLength(4));
        expect(chart.valueBands.last.max, isNull);
      },
    );

    testWidgets('shows min/now/max summary labels from the hourly series', (
      tester,
    ) async {
      final now = DateTime(2026, 1, 1, 15);
      await tester.pumpWidget(
        wrap(
          WaterTemperatureDetailScreen(
            hourly: [
              aSeaHourly(
                time: now.subtract(const Duration(hours: 2)),
                seaSurfaceTemperature: 15,
              ),
              aSeaHourly(
                time: now.subtract(const Duration(hours: 1)),
                seaSurfaceTemperature: 27,
              ),
              aSeaHourly(time: now, seaSurfaceTemperature: 20),
            ],
            now: () => now,
          ),
        ),
      );

      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
    });

    testWidgets(
      'passes a y-axis value formatter and unit (°C) to the chart (issue '
      '#212)',
      (tester) async {
        final now = DateTime(2026, 1, 1, 12);
        await tester.pumpWidget(
          wrap(
            WaterTemperatureDetailScreen(
              hourly: [aSeaHourly(time: now, seaSurfaceTemperature: 22)],
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.unitLabel, '°C');
        expect(chart.valueFormatter!(22), '22');
      },
    );

    testWidgets(
      'given imperial units, passes a unit (°F) to the chart (issue #212)',
      (tester) async {
        final now = DateTime(2026, 1, 1, 12);
        await tester.pumpWidget(
          wrap(
            WaterTemperatureDetailScreen(
              hourly: [aSeaHourly(time: now, seaSurfaceTemperature: 22)],
              unitSystem: UnitSystem.imperial,
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.unitLabel, '°F');
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
                    builder: (_) => WaterTemperatureDetailScreen(
                      hourly: const [],
                      currentWaterTemperatureCelsius: 22,
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
      expect(find.byType(WaterTemperatureDetailScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(WaterTemperatureDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
