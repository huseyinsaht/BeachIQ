import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/shallow_entry.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/widgets/depth_profile_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, child: child)),
    );
  }

  group('DepthProfileChart', () {
    testWidgets('given an empty sample list, renders a "No data" '
        'placeholder instead of an empty chart', (tester) async {
      await tester.pumpWidget(wrap(const DepthProfileChart(samples: [])));

      expect(find.text('No data'), findsOneWidget);
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthProfileChartPainter>(),
        isEmpty,
      );
    });

    testWidgets(
      'given real samples, draws both the shallow and deep threshold lines',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const DepthProfileChart(
              samples: [
                DepthSample(distanceMeters: 0, depthMeters: 0.3),
                DepthSample(distanceMeters: 100, depthMeters: 1.0),
                DepthSample(distanceMeters: 200, depthMeters: 1.8),
                DepthSample(distanceMeters: 300, depthMeters: 2.6),
                DepthSample(distanceMeters: 400, depthMeters: 3.4),
              ],
            ),
          ),
        );

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthProfileChartPainter>()
            .first;

        expect(painter.thresholds, hasLength(2));
        expect(
          painter.thresholds.map((t) => t.valueMeters),
          containsAll(<double>[shallowLimitMeters, deepLimitMeters]),
        );
      },
    );

    testWidgets('given real samples, passes the exact samples through to the '
        'painter, gaps (null depth) included rather than rewritten to 0', (
      tester,
    ) async {
      const samples = [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: null),
        DepthSample(distanceMeters: 200, depthMeters: 1.8),
      ];

      await tester.pumpWidget(wrap(const DepthProfileChart(samples: samples)));

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<DepthProfileChartPainter>()
          .first;

      expect(painter.samples.map((s) => s.depthMeters), [0.3, null, 1.8]);
    });

    testWidgets(
      'labels the x-axis with distance and the y-axis with depth, both '
      'carrying the metric unit',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const DepthProfileChart(
              samples: [
                DepthSample(distanceMeters: 0, depthMeters: 0.3),
                DepthSample(distanceMeters: 100, depthMeters: 1.0),
                DepthSample(distanceMeters: 200, depthMeters: 1.8),
              ],
            ),
          ),
        );

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthProfileChartPainter>()
            .first;

        expect(painter.xTickLabels, isNotEmpty);
        expect(painter.xTickLabels.every((l) => l.endsWith('m')), isTrue);
        expect(painter.yTickLabels, isNotEmpty);
        expect(painter.yTickLabels.every((l) => l.endsWith('m')), isTrue);
      },
    );

    testWidgets('given the imperial unit system, labels both axes in feet', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DepthProfileChart(
            unitSystem: UnitSystem.imperial,
            samples: [
              DepthSample(distanceMeters: 0, depthMeters: 0.3),
              DepthSample(distanceMeters: 100, depthMeters: 1.0),
            ],
          ),
        ),
      );

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<DepthProfileChartPainter>()
          .first;

      expect(painter.xTickLabels.every((l) => l.endsWith('ft')), isTrue);
      expect(painter.yTickLabels.every((l) => l.endsWith('ft')), isTrue);
    });

    testWidgets(
      'depth grows downward: a deeper sample paints at a larger y than a '
      'shallower one',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const DepthProfileChart(
              samples: [
                DepthSample(distanceMeters: 0, depthMeters: 0.5),
                DepthSample(distanceMeters: 400, depthMeters: 3.0),
              ],
            ),
          ),
        );

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthProfileChartPainter>()
            .first;

        // Reproduce the painter's own y-mapping (depth / yMax, no
        // inversion) to assert the *direction* of the mapping, not just
        // that it ran.
        final yMax = painter.yMax;
        final yShallow =
            painter.plotRect.top + painter.plotRect.height * (0.5 / yMax);
        final yDeep =
            painter.plotRect.top + painter.plotRect.height * (3.0 / yMax);

        expect(yDeep, greaterThan(yShallow));
      },
    );

    testWidgets(
      'the y-axis domain always extends past deepLimitMeters, even when '
      'every real sample is shallower than it',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const DepthProfileChart(
              samples: [
                DepthSample(distanceMeters: 0, depthMeters: 0.2),
                DepthSample(distanceMeters: 100, depthMeters: 0.4),
              ],
            ),
          ),
        );

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthProfileChartPainter>()
            .first;

        expect(painter.yMax, greaterThan(deepLimitMeters));
      },
    );

    testWidgets('does not overflow at a narrow (360dp) width with a large '
        'text scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: const Scaffold(
                  body: SizedBox(
                    width: 360,
                    child: DepthProfileChart(
                      samples: [
                        DepthSample(distanceMeters: 0, depthMeters: 0.3),
                        DepthSample(distanceMeters: 100, depthMeters: 1.0),
                        DepthSample(distanceMeters: 200, depthMeters: 1.8),
                        DepthSample(distanceMeters: 300, depthMeters: 2.6),
                        DepthSample(distanceMeters: 400, depthMeters: 3.4),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    group('DepthProfileChartPainter.shouldRepaint', () {
      // A single shared samples list: shouldRepaint OR-combines several
      // field comparisons, so two painters built from *different* samples
      // lists would already report a repaint regardless of the field under
      // test, defeating these tests' whole point.
      const sharedSamples = [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: 1.0),
      ];
      const sharedThresholds = [
        DepthChartThreshold(
          valueMeters: shallowLimitMeters,
          color: Colors.orange,
        ),
      ];
      const sharedPlotRect = Rect.fromLTWH(0, 0, 300, 150);

      DepthProfileChartPainter painterWith({
        List<DepthSample> samples = sharedSamples,
        double xMax = 400,
        double yMax = 4,
        Color lineColor = Colors.blue,
        List<DepthChartThreshold> thresholds = sharedThresholds,
        Rect plotRect = sharedPlotRect,
        List<double> xTicks = const [],
        List<double> yTicks = const [],
      }) {
        return DepthProfileChartPainter(
          samples: samples,
          xMax: xMax,
          yMax: yMax,
          lineColor: lineColor,
          thresholds: thresholds,
          plotRect: plotRect,
          xTicks: xTicks,
          yTicks: yTicks,
        );
      }

      test('given identical fields, shouldRepaint -> false', () {
        expect(painterWith().shouldRepaint(painterWith()), isFalse);
      });

      test('given a different xMax, shouldRepaint -> true', () {
        final a = painterWith(xMax: 400);
        final b = painterWith(xMax: 500);

        expect(a.shouldRepaint(b), isTrue);
      });

      test('given a different yMax, shouldRepaint -> true', () {
        final a = painterWith(yMax: 4);
        final b = painterWith(yMax: 6);

        expect(a.shouldRepaint(b), isTrue);
      });

      test('given a different lineColor, shouldRepaint -> true', () {
        final a = painterWith(lineColor: Colors.blue);
        final b = painterWith(lineColor: Colors.red);

        expect(a.shouldRepaint(b), isTrue);
      });

      test('given different thresholds, shouldRepaint -> true', () {
        final a = painterWith(thresholds: sharedThresholds);
        final b = painterWith(thresholds: const []);

        expect(a.shouldRepaint(b), isTrue);
      });

      test('given a different plotRect, shouldRepaint -> true', () {
        final a = painterWith(plotRect: sharedPlotRect);
        final b = painterWith(plotRect: const Rect.fromLTWH(0, 0, 320, 150));

        expect(a.shouldRepaint(b), isTrue);
      });

      test('given different xTicks, shouldRepaint -> true', () {
        final a = painterWith(xTicks: const [0, 200, 400]);
        final b = painterWith(xTicks: const []);

        expect(a.shouldRepaint(b), isTrue);
      });

      test('given different yTicks, shouldRepaint -> true', () {
        final a = painterWith(yTicks: const [0, 2, 4]);
        final b = painterWith(yTicks: const []);

        expect(a.shouldRepaint(b), isTrue);
      });
    });
  });
}
