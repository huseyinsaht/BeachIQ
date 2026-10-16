import 'dart:ui' as ui;

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

    testWidgets(
      'given a bandColor and a gap in the data, HourlyMetricChart -> paints '
      'the area under each side of the gap as its own piece without '
      'throwing',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            HourlyMetricChart(
              points: somePoints(withNullAt: 2),
              bandColor: Colors.blue,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final painter = painterOf(tester);
        expect(painter.bandColor, Colors.blue);
      },
    );

    group('axes (issue #212)', () {
      testWidgets('given a valueFormatter and unitLabel, HourlyMetricChart -> '
          'forwards at least 3 nice tick values, each formatted with the '
          'unit, to the painter', (tester) async {
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
      });

      testWidgets('given a percent unitLabel, HourlyMetricChart -> attaches it '
          'directly with no separating space', (tester) async {
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
      });

      testWidgets('given a degree unitLabel, HourlyMetricChart -> attaches it '
          'directly with no separating space', (tester) async {
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
      });

      testWidgets(
        'given no valueFormatter/unitLabel, HourlyMetricChart -> still '
        'computes bare rounded-number ticks',
        (tester) async {
          await tester.pumpWidget(
            wrap(HourlyMetricChart(points: somePoints())),
          );

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

      testWidgets('given a narrow range (e.g. a quiet-pressure day) with an '
          'integer-rounding valueFormatter, HourlyMetricChart -> never '
          'shows two ticks with the same formatted label', (tester) async {
        await tester.pumpWidget(
          wrap(
            HourlyMetricChart(
              points: [
                for (var i = 0; i < 5; i++)
                  HourlyChartPoint(
                    time: DateTime(2026, 1, 1, i),
                    // A 2 hPa-wide range: niceTicks picks a fractional
                    // step here (e.g. 0.5), which would otherwise round
                    // to repeated whole-number labels.
                    value: 1010 + (i % 3) * 1.0,
                  ),
              ],
              valueFormatter: (v) => v.round().toString(),
              unitLabel: 'hPa',
            ),
          ),
        );

        final painter = painterOf(tester);
        expect(painter.yTickLabels, isNotEmpty);
        expect(
          painter.yTickLabels.toSet().length,
          painter.yTickLabels.length,
          reason:
              'every shown y-axis label must be distinct: '
              '${painter.yTickLabels}',
        );
        expect(painter.yTicks.length, painter.yTickLabels.length);
      });

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

      testWidgets('given no data, HourlyMetricChart -> shows "No data" with no '
          'axes drawn at all', (tester) async {
        await tester.pumpWidget(wrap(const HourlyMetricChart(points: [])));

        expect(find.text('No data'), findsOneWidget);
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<HourlyMetricChartPainter>();
        expect(painters, isEmpty);
      });

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

      testWidgets('given a very narrow chart with many hourly points, '
          'HourlyMetricChart -> falls back to the coarsest x-axis step when '
          'even the sparsest candidate would still crowd the labels', (
        tester,
      ) async {
        final points = [
          for (var i = 0; i < 240; i++)
            HourlyChartPoint(
              time: DateTime(2026, 1, 1).add(Duration(hours: i)),
              value: 1010.0,
            ),
        ];

        await tester.pumpWidget(
          wrap(SizedBox(width: 100, child: HourlyMetricChart(points: points))),
        );

        final painter = painterOf(tester);
        // 240 points at the coarsest 24h step land exactly on indices
        // 0, 24, 48, ..., 216 -> 10 labels, none of them "Now" since
        // nowIndex is null here.
        expect(painter.xAxisLabels, hasLength(10));
        expect(painter.xAxisLabels.every((l) => l.text != 'Now'), isTrue);
      });
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

    group('paint with a bandColor', () {
      // bandColor fills the area under the line and must break into
      // separate shapes at each null gap, same as the line itself
      // (_paintBand mirrors the line-drawing loop in _paintLine).
      HourlyMetricChartPainter painterWith(List<HourlyChartPoint> points) {
        return HourlyMetricChartPainter(
          points: points,
          minValue: 1010,
          maxValue: 1014,
          lineColor: Colors.white,
          bandColor: Colors.white24,
          thresholds: const [],
          plotRect: const Rect.fromLTWH(0, 0, 200, 100),
        );
      }

      void paintOn(HourlyMetricChartPainter painter) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(200, 100));
        recorder.endRecording();
      }

      test('given a gap in the middle, paint -> closes the band on either '
          'side of the gap instead of bridging across it', () {
        final painter = painterWith(somePoints(withNullAt: 2));

        expect(() => paintOn(painter), returnsNormally);
      });

      test(
        'given no gaps, paint -> draws a single band under the whole line',
        () {
          final painter = painterWith(somePoints());

          expect(() => paintOn(painter), returnsNormally);
        },
      );

      test('given every value null, paint -> draws no band at all', () {
        final painter = painterWith([
          for (var i = 0; i < 5; i++)
            HourlyChartPoint(time: DateTime(2026, 1, 1, i), value: null),
        ]);

        expect(() => paintOn(painter), returnsNormally);
      });

      test('given a leading gap before the first real value, paint -> starts '
          'the band at the first non-null point rather than throwing', () {
        final painter = painterWith(somePoints(withNullAt: 0));

        expect(() => paintOn(painter), returnsNormally);
      });
    });

    group('paint with value bands', () {
      // _paintValueBand is skipped entirely when a band doesn't overlap
      // the chart's visible [minValue, maxValue] range at all.
      test('given a band entirely below minValue, paint -> skips it without '
          'throwing', () {
        final painter = HourlyMetricChartPainter(
          points: somePoints(),
          minValue: 1010,
          maxValue: 1014,
          lineColor: Colors.white,
          bandColor: null,
          thresholds: const [],
          valueBands: const [
            HourlyChartValueBand(min: 0, max: 5, color: Colors.green),
          ],
          plotRect: const Rect.fromLTWH(0, 0, 200, 100),
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(200, 100)),
          returnsNormally,
        );
        recorder.endRecording();
      });

      test('given a band that overlaps and extends past maxValue (max: null, '
          '"and above"), paint -> clips it to the visible range without '
          'throwing', () {
        final painter = HourlyMetricChartPainter(
          points: somePoints(),
          minValue: 1010,
          maxValue: 1014,
          lineColor: Colors.white,
          bandColor: null,
          thresholds: const [],
          valueBands: const [
            HourlyChartValueBand(min: 1012, color: Colors.red),
          ],
          plotRect: const Rect.fromLTWH(0, 0, 200, 100),
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(200, 100)),
          returnsNormally,
        );
        recorder.endRecording();
      });
    });
  });
}
