import 'package:beachiq/logic/swim_suitability.dart';
import 'package:beachiq/presentation/widgets/swim_suggestion_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders the verdict message and a leading icon', (
    tester,
  ) async {
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
}
