import 'package:beachiq/presentation/widgets/hourly_metric_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  List<HourlyChartPoint> somePoints({int withNullAt = -1}) {
    return [
      for (var i = 0; i < 5; i++)
        HourlyChartPoint(
          time: DateTime(2026, 1, 1, i),
          value: i == withNullAt ? null : (1010 + i).toDouble(),
        ),
    ];
  }

  HourlyMetricChartPainter painterOf(WidgetTester tester) {
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<HourlyMetricChartPainter>();
    expect(painters, hasLength(1));
    return painters.single;
  }

  group('HourlyMetricChart', () {
    testWidgets(
      'given a null hour, the painter keeps it as a gap (null) rather than '
      'rewriting it to 0',
      (tester) async {
        final points = somePoints(withNullAt: 2);

        await tester.pumpWidget(
          wrap(HourlyMetricChart(points: points, nowIndex: 0)),
        );

        final painter = painterOf(tester);
        expect(painter.points[2].value, isNull);
        // The point is still present (a real gap in a pre-sized series),
        // not dropped from the list either.
        expect(painter.points, hasLength(5));
        // Every other, non-null point is unaffected.
        expect(painter.points[0].value, 1010.0);
        expect(painter.points[4].value, 1014.0);
      },
    );

    testWidgets('given no null hours, the painter sees every value unchanged', (
      tester,
    ) async {
      final points = somePoints();

      await tester.pumpWidget(
        wrap(HourlyMetricChart(points: points, nowIndex: 0)),
      );

      final painter = painterOf(tester);
      expect(painter.points.map((p) => p.value), [
        1010.0,
        1011.0,
        1012.0,
        1013.0,
        1014.0,
      ]);
    });

    testWidgets('shows a "Now" marker when nowIndex has a value', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(HourlyMetricChart(points: somePoints(), nowIndex: 0)),
      );

      expect(find.byKey(const Key('hourly-chart-now-marker')), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('hides the "Now" marker when nowIndex is null', (tester) async {
      await tester.pumpWidget(
        wrap(HourlyMetricChart(points: somePoints(), nowIndex: null)),
      );

      expect(find.byKey(const Key('hourly-chart-now-marker')), findsNothing);
    });

    testWidgets("hides the 'Now' marker when nowIndex's own hour has no data", (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(HourlyMetricChart(points: somePoints(withNullAt: 1), nowIndex: 1)),
      );

      expect(find.byKey(const Key('hourly-chart-now-marker')), findsNothing);
    });

    testWidgets('hides the "Now" marker when nowIndex is out of range', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(HourlyMetricChart(points: somePoints(), nowIndex: 99)),
      );

      expect(find.byKey(const Key('hourly-chart-now-marker')), findsNothing);
    });

    testWidgets('shows a "No data" message instead of an empty chart', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const HourlyMetricChart(points: [])));

      expect(find.text('No data'), findsOneWidget);
      // No chart painting at all for this metric (other CustomPaints from
      // MaterialApp/Scaffold's own internals are unrelated).
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<HourlyMetricChartPainter>();
      expect(painters, isEmpty);
    });

    testWidgets('forwards configured thresholds to the painter', (
      tester,
    ) async {
      const threshold = HourlyChartThreshold(value: 1000, color: Colors.red);

      await tester.pumpWidget(
        wrap(
          HourlyMetricChart(
            points: somePoints(),
            thresholds: const [threshold],
          ),
        ),
      );

      final painter = painterOf(tester);
      expect(painter.thresholds, [threshold]);
    });

    testWidgets('forwards configured value bands to the painter', (
      tester,
    ) async {
      const bands = [
        HourlyChartValueBand(min: 0, max: 3, color: Colors.green),
        HourlyChartValueBand(min: 3, color: Colors.purple),
      ];

      await tester.pumpWidget(
        wrap(HourlyMetricChart(points: somePoints(), valueBands: bands)),
      );

      final painter = painterOf(tester);
      expect(painter.valueBands, bands);
    });

    testWidgets('defaults to no value bands when none are given', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(HourlyMetricChart(points: somePoints())));

      final painter = painterOf(tester);
      expect(painter.valueBands, isEmpty);
    });

    group('axes (issue #212)', () {
      testWidgets(
        'given a valueFormatter and unitLabel, HourlyMetricChart -> '
        'forwards at least 3 nice tick values, each formatted with the '
        'unit, to the painter',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              HourlyMetricChart(
                points: somePoints(),
                valueFormatter: (v) => v.round().toString(),
                unitLabel: 'hPa',
              ),
            ),
          );

          final painter = painterOf(tester);
          expect(painter.yTicks.length, greaterThanOrEqualTo(3));
          expect(painter.yTickLabels, hasLength(painter.yTicks.length));
          for (final label in painter.yTickLabels) {
            expect(label, endsWith('hPa'));
          }
        },
      );

      testWidgets(
        'given a percent unitLabel, HourlyMetricChart -> attaches it '
        'directly with no separating space',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              HourlyMetricChart(
                points: [
                  for (var i = 0; i < 4; i++)
                    HourlyChartPoint(
                      time: DateTime(2026, 1, 1, i),
                      value: (i * 20).toDouble(),
                    ),
                ],
                valueFormatter: (v) => v.round().toString(),
                unitLabel: '%',
              ),
            ),
          );

          final painter = painterOf(tester);
          expect(painter.yTickLabels, isNotEmpty);
          for (final label in painter.yTickLabels) {
            expect(label, matches(RegExp(r'^-?\d+%$')));
          }
        },
      );

      testWidgets(
        'given a degree unitLabel, HourlyMetricChart -> attaches it '
        'directly with no separating space',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              HourlyMetricChart(
                points: somePoints(),
                valueFormatter: (v) => v.round().toString(),
                unitLabel: '°C',
              ),
            ),
          );

          final painter = painterOf(tester);
          expect(painter.yTickLabels, isNotEmpty);
          for (final label in painter.yTickLabels) {
            expect(label, matches(RegExp(r'^-?\d+°C$')));
          }
        },
      );

      testWidgets(
        'given no valueFormatter/unitLabel, HourlyMetricChart -> still '
        'computes bare rounded-number ticks',
        (tester) async {
          await tester.pumpWidget(wrap(HourlyMetricChart(points: somePoints())));

          final painter = painterOf(tester);
          expect(painter.yTicks.length, greaterThanOrEqualTo(3));
          for (final label in painter.yTickLabels) {
            expect(double.tryParse(label), isNotNull);
          }
        },
      );

      testWidgets(
        'given a flat series (every value equal), HourlyMetricChart -> '
        'still produces at least 3 sane, finite y ticks',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              HourlyMetricChart(
                points: [
                  for (var i = 0; i < 4; i++)
                    HourlyChartPoint(time: DateTime(2026, 1, 1, i), value: 7.0),
                ],
              ),
            ),
          );

          final painter = painterOf(tester);
          expect(painter.yTicks.length, greaterThanOrEqualTo(3));
          for (final tick in painter.yTicks) {
            expect(tick.isFinite, isTrue);
          }
        },
      );

      testWidgets(
        'given a series with null gaps, HourlyMetricChart -> ticks are '
        "based on the non-null entries' own min/max, matching the "
        'painter minValue/maxValue it also uses for the line',
        (tester) async {
          await tester.pumpWidget(
            wrap(HourlyMetricChart(points: somePoints(withNullAt: 2))),
          );

          final painter = painterOf(tester);
          expect(painter.minValue, 1010.0);
          expect(painter.maxValue, 1014.0);
          for (final tick in painter.yTicks) {
            expect(tick, greaterThanOrEqualTo(painter.minValue));
            expect(tick, lessThanOrEqualTo(painter.maxValue));
          }
        },
      );

      testWidgets(
        'given no data, HourlyMetricChart -> shows "No data" with no '
        'axes drawn at all',
        (tester) async {
          await tester.pumpWidget(wrap(const HourlyMetricChart(points: [])));

          expect(find.text('No data'), findsOneWidget);
          final painters = tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((w) => w.painter)
              .whereType<HourlyMetricChartPainter>();
          expect(painters, isEmpty);
        },
      );

      testWidgets(
        'given a nowIndex, HourlyMetricChart -> labels that hour "Now" on '
        'the x-axis instead of its clock hour',
        (tester) async {
          await tester.pumpWidget(
            wrap(HourlyMetricChart(points: somePoints(), nowIndex: 0)),
          );

          final painter = painterOf(tester);
          expect(painter.xAxisLabels, isNotEmpty);
          expect(
            painter.xAxisLabels.where((l) => l.text == 'Now'),
            hasLength(1),
          );
          expect(painter.xAxisLabels.first.text, 'Now');
        },
      );

      testWidgets(
        'given axis ticks and labels, HourlyMetricChart -> reserves a '
        'left gutter and bottom strip so the plot area never covers the '
        'whole canvas',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              HourlyMetricChart(
                points: somePoints(),
                nowIndex: 0,
                valueFormatter: (v) => v.round().toString(),
                unitLabel: 'hPa',
              ),
            ),
          );

          final painter = painterOf(tester);
          expect(painter.plotRect, isNotNull);
          expect(painter.plotRect!.left, greaterThan(0));
          expect(painter.plotRect!.bottom, lessThan(160));
        },
      );

      testWidgets(
        'at a narrow width (360dp) and a 1.3x text scale, HourlyMetricChart '
        '-> renders without a layout/overflow error',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(360, 800),
                    textScaler: TextScaler.linear(1.3),
                  ),
                  child: SizedBox(
                    width: 360,
                    child: HourlyMetricChart(
                      points: somePoints(),
                      nowIndex: 0,
                      valueFormatter: (v) => v.round().toString(),
                      unitLabel: 'hPa',
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(HourlyMetricChart), findsOneWidget);
        },
      );
    });

    group('shouldRepaint', () {
      // A single shared points list: shouldRepaint OR-combines several
      // field comparisons, so two painters built from *different* points
      // lists would already report a repaint regardless of valueBands,
      // defeating these tests' whole point.
      final sharedPoints = somePoints();

      HourlyMetricChartPainter painterWith({
        List<HourlyChartValueBand> valueBands = const [],
      }) {
        return HourlyMetricChartPainter(
          points: sharedPoints,
          minValue: 1010,
          maxValue: 1014,
          lineColor: Colors.white,
          bandColor: null,
          thresholds: const [],
          valueBands: valueBands,
        );
      }

      test('given different value bands, shouldRepaint -> true', () {
        final a = painterWith(
          valueBands: const [
            HourlyChartValueBand(min: 0, max: 3, color: Colors.green),
          ],
        );
        final b = painterWith();

        expect(a.shouldRepaint(b), isTrue);
      });

      test('given the same value bands, shouldRepaint -> false', () {
        const bands = [
          HourlyChartValueBand(min: 0, max: 3, color: Colors.green),
        ];
        final a = painterWith(valueBands: bands);
        final b = painterWith(valueBands: bands);

        expect(a.shouldRepaint(b), isFalse);
      });
    });
  });
}
