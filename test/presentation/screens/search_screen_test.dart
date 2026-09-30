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

  testWidgets('shows a loading indicator while a search is in flight', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SearchScreen(isLoading: true)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(BeachResultCard), findsNothing);
    expect(find.text('Beaches Near'), findsOneWidget);
  });

  testWidgets('shows a clear error message when the search fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const SearchScreen(error: 'Could not load nearby beaches.')),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(BeachResultCard), findsNothing);
    expect(
      find.textContaining('Could not load nearby beaches.'),
      findsOneWidget,
    );
  });

  testWidgets('renders the normal results list when not loading and no error', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SearchScreen()));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(BeachResultCard), findsWidgets);
    expect(find.text(staticBeaches.first.name), findsOneWidget);
  });

  testWidgets('a pull-to-refresh gesture over the result sheet calls onRefresh', (
    tester,
  ) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      wrap(
        SearchScreen(
          onRefresh: () async {
            refreshCount++;
          },
        ),
      ),
    );

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();
    await tester.pumpAndSettle();

    expect(refreshCount, 1);
  });

  testWidgets('a pull-to-refresh gesture is a no-op when onRefresh is not set', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SearchScreen()));

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();
    await tester.pumpAndSettle();

    expect(find.byType(BeachResultCard), findsWidgets);
  });
}
