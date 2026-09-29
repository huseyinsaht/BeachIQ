import 'package:beachiq/presentation/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders the placeholder and search icon', (tester) async {
    await tester.pumpWidget(wrap(const SearchField()));

    expect(find.text('Enter cities'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('renders a custom placeholder when provided', (tester) async {
    await tester.pumpWidget(wrap(const SearchField(hintText: 'Search beach')));

    expect(find.text('Search beach'), findsOneWidget);
  });

  testWidgets('onChanged fires with typed text', (tester) async {
    String? typed;
    await tester.pumpWidget(
      wrap(SearchField(onChanged: (value) => typed = value)),
    );

    await tester.enterText(find.byType(TextField), 'Cesme');

    expect(typed, 'Cesme');
  });
}
