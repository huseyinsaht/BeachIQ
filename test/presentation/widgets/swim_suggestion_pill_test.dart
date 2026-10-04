import 'package:beachiq/logic/swim_suitability.dart';
import 'package:beachiq/presentation/theme/verdict_palette.dart';
import 'package:beachiq/presentation/widgets/swim_suggestion_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  LinearGradient gradientOf(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration as BoxDecoration;
    return decoration.gradient as LinearGradient;
  }

  testWidgets('renders the verdict message and a leading icon', (tester) async {
    const verdict = SwimVerdict(
      SwimSuitabilityLevel.good,
      'Calm seas — good time for a swim.',
    );

    await tester.pumpWidget(wrap(const SwimSuggestionPill(verdict: verdict)));

    expect(find.text('Calm seas — good time for a swim.'), findsOneWidget);
    expect(find.byIcon(Icons.pool), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a different icon for a cautionary verdict', (
    tester,
  ) async {
    const verdict = SwimVerdict(
      SwimSuitabilityLevel.caution,
      'A bit choppy — swim with care.',
    );

    await tester.pumpWidget(wrap(const SwimSuggestionPill(verdict: verdict)));

    expect(find.text('A bit choppy — swim with care.'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  for (final level in SwimSuitabilityLevel.values) {
    testWidgets(
      'renders the $level palette\'s gradient, icon and foreground color',
      (tester) async {
        final verdict = SwimVerdict(level, 'message');
        final expectedPalette = paletteForVerdict(level);

        await tester.pumpWidget(wrap(SwimSuggestionPill(verdict: verdict)));

        final gradient = gradientOf(tester);
        expect(gradient.colors, [
          expectedPalette.gradientStart,
          expectedPalette.gradientEnd,
        ]);
        expect(find.byIcon(expectedPalette.icon), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(expectedPalette.icon));
        expect(icon.color, expectedPalette.foreground);

        final text = tester.widget<Text>(find.text('message'));
        expect(text.style?.color, expectedPalette.foreground);
      },
    );
  }

  testWidgets(
    'the good and poor verdicts render visibly different pill colors',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const SwimSuggestionPill(
            verdict: SwimVerdict(SwimSuitabilityLevel.good, 'good'),
          ),
        ),
      );
      final goodGradient = gradientOf(tester);

      await tester.pumpWidget(
        wrap(
          const SwimSuggestionPill(
            verdict: SwimVerdict(SwimSuitabilityLevel.poor, 'poor'),
          ),
        ),
      );
      final poorGradient = gradientOf(tester);

      expect(goodGradient.colors, isNot(equals(poorGradient.colors)));
    },
  );
}
