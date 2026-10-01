import 'package:beachiq/data/static_beaches.dart';
import 'package:beachiq/logic/providers/favorites_provider.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets(
    'a real pull-to-refresh drag over the result sheet calls onRefresh',
    (tester) async {
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

      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
    },
  );

  testWidgets(
    'no RefreshIndicator is shown when onRefresh is not set, so a drag is '
    'a plain no-op scroll',
    (tester) async {
      await tester.pumpWidget(wrap(const SearchScreen()));

      expect(find.byType(RefreshIndicator), findsNothing);

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(BeachResultCard), findsWidgets);
    },
  );

  testWidgets('typing a name filters the beach results list', (tester) async {
    await tester.pumpWidget(wrap(const SearchScreen()));

    expect(find.text('Alaçatı Plajı'), findsOneWidget);
    expect(find.text('Patara Plajı'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Alaçatı');
    await tester.pump();

    expect(find.byType(BeachResultCard), findsOneWidget);
    expect(find.text('Alaçatı Plajı'), findsOneWidget);
    expect(find.text('Patara Plajı'), findsNothing);
  });

  testWidgets('typing a city filters the beach results list', (tester) async {
    await tester.pumpWidget(wrap(const SearchScreen()));

    await tester.enterText(find.byType(TextField), 'antalya');
    await tester.pump();

    final antalyaCount = staticBeaches
        .where((beach) => beach.city.toLowerCase() == 'antalya')
        .length;
    expect(find.byType(BeachResultCard), findsNWidgets(antalyaCount));
    expect(find.text('Patara Plajı'), findsOneWidget);
    expect(find.text('Alaçatı Plajı'), findsNothing);
  });

  testWidgets('shows a "no matches" message when nothing matches the query', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SearchScreen()));

    await tester.enterText(find.byType(TextField), 'nonexistent beach xyz');
    await tester.pump();

    expect(find.byType(BeachResultCard), findsNothing);
    expect(
      find.textContaining('No beaches match'),
      findsOneWidget,
    );
  });

  testWidgets('clearing the query back to empty restores the full list', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SearchScreen()));

    await tester.enterText(find.byType(TextField), 'Alaçatı');
    await tester.pump();
    expect(find.byType(BeachResultCard), findsOneWidget);
    expect(find.text('Patara Plajı'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(find.text('Alaçatı Plajı'), findsOneWidget);
    expect(find.text('Patara Plajı'), findsOneWidget);
  });

  group('favorites', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<FavoritesProvider> favoritesProvider() async =>
        FavoritesProvider(await SharedPreferences.getInstance());

    testWidgets(
      'no star toggle or favorite icons are shown without a favoritesProvider',
      (tester) async {
        await tester.pumpWidget(wrap(const SearchScreen()));

        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.star_border), findsNothing);
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.byIcon(Icons.favorite_border), findsNothing);
      },
    );

    testWidgets(
      'a favoritesProvider shows the star toggle and a heart on each result',
      (tester) async {
        await tester.pumpWidget(
          wrap(SearchScreen(favoritesProvider: await favoritesProvider())),
        );

        expect(find.byIcon(Icons.star_border), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsWidgets);
      },
    );

    testWidgets('tapping a result\'s heart marks it as a favorite', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(SearchScreen(favoritesProvider: await favoritesProvider())),
      );

      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets(
      'the star toggle switches the list to favorites only, and back',
      (tester) async {
        final provider = await favoritesProvider();
        await provider.toggleFavorite(staticBeaches.first);
        await tester.pumpWidget(
          wrap(SearchScreen(favoritesProvider: provider)),
        );

        await tester.tap(find.byIcon(Icons.star_border));
        await tester.pump();

        expect(find.text('Favorites'), findsOneWidget);
        expect(find.byType(BeachResultCard), findsOneWidget);
        expect(find.text(staticBeaches.first.name), findsOneWidget);

        await tester.tap(find.byIcon(Icons.star));
        await tester.pump();

        expect(find.text('Beaches Near'), findsOneWidget);
        expect(find.byType(BeachResultCard), findsWidgets);
      },
    );

    testWidgets(
      'favorites-only with no favorites shows a dedicated empty message',
      (tester) async {
        await tester.pumpWidget(
          wrap(SearchScreen(favoritesProvider: await favoritesProvider())),
        );

        await tester.tap(find.byIcon(Icons.star_border));
        await tester.pump();

        expect(find.byType(BeachResultCard), findsNothing);
        expect(find.text('No favorite beaches yet.'), findsOneWidget);
      },
    );
  });
}
