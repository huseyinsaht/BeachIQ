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
