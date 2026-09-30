import 'package:beachiq/data/static_beaches.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('renders header, search field and beach results', (tester) async {
    await tester.pumpWidget(wrap(const SearchScreen()));

    expect(find.text('Search'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    expect(find.byType(SearchField), findsOneWidget);
    expect(find.text('Enter cities'), findsOneWidget);

    expect(find.text('Beaches Near'), findsOneWidget);
    expect(find.byType(BeachResultCard), findsWidgets);
    expect(find.text(staticBeaches.first.name), findsOneWidget);
  });

  testWidgets('typing into the search field fires onChanged/onSubmitted', (
    tester,
  ) async {
    String? changed;
    String? submitted;
    await tester.pumpWidget(
      wrap(
        SearchScreen(
          onSearchChanged: (value) => changed = value,
          onSearchSubmitted: (value) => submitted = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Cesme');
    expect(changed, 'Cesme');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, 'Cesme');
  });
}
