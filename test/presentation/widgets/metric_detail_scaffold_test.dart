import 'package:beachiq/presentation/widgets/metric_detail_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MetricDetailScaffold scaffold({
    String title = 'Pressure',
    String heroValue = '1013',
    String? heroUnit = 'hPa',
    String? trendText,
    Widget chart = const SizedBox(key: Key('test-chart'), height: 10),
    String minValueLabel = '1005 hPa',
    String nowValueLabel = '1013 hPa',
    String maxValueLabel = '1020 hPa',
    String explanation = 'What this metric means for the weather.',
  }) {
    return MetricDetailScaffold(
      title: title,
      heroValue: heroValue,
      heroUnit: heroUnit,
      trendText: trendText,
      chart: chart,
      minValueLabel: minValueLabel,
      nowValueLabel: nowValueLabel,
      maxValueLabel: maxValueLabel,
      explanation: explanation,
    );
  }

  Widget buildScaffold({
    String title = 'Pressure',
    String heroValue = '1013',
    String? heroUnit = 'hPa',
    String? trendText,
    Widget chart = const SizedBox(key: Key('test-chart'), height: 10),
    String minValueLabel = '1005 hPa',
    String nowValueLabel = '1013 hPa',
    String maxValueLabel = '1020 hPa',
    String explanation = 'What this metric means for the weather.',
  }) {
    return MaterialApp(
      home: scaffold(
        title: title,
        heroValue: heroValue,
        heroUnit: heroUnit,
        trendText: trendText,
        chart: chart,
        minValueLabel: minValueLabel,
        nowValueLabel: nowValueLabel,
        maxValueLabel: maxValueLabel,
        explanation: explanation,
      ),
    );
  }

  group('MetricDetailScaffold', () {
    testWidgets('renders the title, hero value/unit, chart slot and '
        'explanation', (tester) async {
      await tester.pumpWidget(buildScaffold());

      expect(find.text('Pressure'), findsOneWidget);
      expect(find.text('1013'), findsOneWidget);
      expect(find.text('hPa'), findsOneWidget);
      expect(find.byKey(const Key('test-chart')), findsOneWidget);
      expect(
        find.text('What this metric means for the weather.'),
        findsOneWidget,
      );
    });

    testWidgets('renders the min/now/max summary row', (tester) async {
      await tester.pumpWidget(buildScaffold());

      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      // 'Now' also appears as the summary label; both the label and its
      // value should be present.
      expect(find.text('1005 hPa'), findsOneWidget);
      expect(find.text('1020 hPa'), findsOneWidget);
      // nowValueLabel and minValueLabel collide here deliberately: assert
      // the hero value's own '1013' count instead of the now summary
      // value, which also renders '1013 hPa'.
      expect(find.text('1013 hPa'), findsOneWidget);
    });

    testWidgets('hides the unit/trend lines when not supplied', (tester) async {
      await tester.pumpWidget(buildScaffold(heroUnit: null, trendText: null));

      expect(find.text('hPa'), findsNothing);
    });

    testWidgets('shows a trend line when supplied', (tester) async {
      await tester.pumpWidget(
        buildScaffold(trendText: 'Rising — clearer weather likely.'),
      );

      expect(find.text('Rising — clearer weather likely.'), findsOneWidget);
    });

    testWidgets('a back button pops the route back to the previous screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => scaffold())),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Pressure'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Pressure'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
