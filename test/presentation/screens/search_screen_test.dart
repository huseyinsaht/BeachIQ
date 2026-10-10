import 'dart:async';
import 'dart:convert';

import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/services/geocoding_service.dart';
import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:beachiq/data/services/overpass_service.dart';
import 'package:beachiq/data/static_beaches.dart';
import 'package:beachiq/logic/beach_gear_advisor.dart';
import 'package:beachiq/logic/providers/favorites_provider.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/logic/providers/place_search_provider.dart';
import 'package:beachiq/logic/providers/unit_preferences_provider.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http_client.dart';

/// A fake [http.Client] that never touches the real network: it answers an
/// Overpass query with a single fixture beach (with a `surface=pebbles` tag
/// and a parking node nearby) and a marine-batch request with fixture
/// wave/temperature data, keyed off the request host.
class _FixtureNetworkClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.host.contains('overpass')) {
      final body = json.encode([
        {
          'current': {
            'wave_height': 0.6,
            'wave_direction': 180,
            'wave_period': 5,
            'sea_surface_temperature': 23.0,
          },
        },
      ]);
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }

    final body = json.encode({
      'elements': [
        {
          'type': 'way',
          'id': 1,
          'tags': {
            'natural': 'beach',
            'name': 'Fixture Beach',
            'addr:city': 'Cesme',
            'fee': 'no',
            'surface': 'pebbles',
          },
          'geometry': [
            {'lat': 38.30, 'lon': 26.30},
            {'lat': 38.31, 'lon': 26.30},
            {'lat': 38.31, 'lon': 26.31},
          ],
        },
        {
          'type': 'node',
          'id': 2,
          'lat': 38.3003,
          'lon': 26.3003,
          'tags': {'amenity': 'parking'},
        },
      ],
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// A fake [http.Client] whose response is controlled by [overpassCompleter],
/// so a provider using it is deterministically stuck mid-fetch until the
/// test completes it — rather than racing against a fixture client's
/// (near-instant) response.
class _PendingNetworkClient extends http.BaseClient {
  final overpassCompleter = Completer<http.StreamedResponse>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return overpassCompleter.future;
  }
}

/// Counts [addListener]/[removeListener] calls so a test can assert
/// directly on whether `_SearchScreenState`'s `didUpdateWidget` actually
/// detached from an old provider instance and attached to a new one (and,
/// just as importantly, never re-subscribes on every rebuild when the
/// provider instance hasn't changed), rather than inferring it indirectly
/// from a widget rebuild.
mixin _ListenerProbe on ChangeNotifier {
  int addListenerCallCount = 0;
  int removeListenerCallCount = 0;

  bool get isListenedTo => hasListeners;

  @override
  void addListener(VoidCallback listener) {
    addListenerCallCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeListenerCallCount++;
    super.removeListener(listener);
  }
}

class _ProbeFavoritesProvider = FavoritesProvider with _ListenerProbe;
class _ProbeUnitPreferencesProvider = UnitPreferencesProvider
    with _ListenerProbe;
class _ProbeNearbyBeachesProvider = NearbyBeachesProvider with _ListenerProbe;
class _ProbePlaceSearchProvider = PlaceSearchProvider with _ListenerProbe;

Future<NearbyBeachesProvider> _loadedFixtureProvider(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({});
  final client = _FixtureNetworkClient();
  final provider = NearbyBeachesProvider(
    OverpassService(client),
    BeachCache(await SharedPreferences.getInstance()),
    MarineBatchService(client),
    debounceDuration: const Duration(milliseconds: 1),
  );
  provider.pickLocation(const LatLng(38.3, 26.3));
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
  return provider;
}

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
    expect(find.textContaining('No beaches match'), findsOneWidget);
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
      'un-favoriting while favorites-only is active shrinks the list down '
      'to the empty message',
      (tester) async {
        final provider = await favoritesProvider();
        await provider.toggleFavorite(staticBeaches.first);
        await tester.pumpWidget(
          wrap(SearchScreen(favoritesProvider: provider)),
        );
        await tester.tap(find.byIcon(Icons.star_border));
        await tester.pump();
        expect(find.byType(BeachResultCard), findsOneWidget);

        await tester.tap(find.byIcon(Icons.favorite));
        await tester.pump();

        expect(find.byType(BeachResultCard), findsNothing);
        expect(find.text('No favorite beaches yet.'), findsOneWidget);
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

  group('unit preferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'the "More" button opens the unit sheet, and picking Imperial updates '
      'the shared provider',
      (tester) async {
        final provider = UnitPreferencesProvider(
          await SharedPreferences.getInstance(),
        );
        await tester.pumpWidget(
          wrap(SearchScreen(unitPreferencesProvider: provider)),
        );

        expect(find.text('Imperial (ft, °F, mph)'), findsNothing);

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();

        expect(find.text('Imperial (ft, °F, mph)'), findsOneWidget);

        await tester.tap(find.text('Imperial (ft, °F, mph)'));
        await tester.pumpAndSettle();

        expect(provider.unitSystem, UnitSystem.imperial);
      },
    );

    testWidgets(
      'the "More" button is a no-op without a unitPreferencesProvider',
      (tester) async {
        await tester.pumpWidget(wrap(const SearchScreen()));

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();

        expect(find.text('Imperial (ft, °F, mph)'), findsNothing);
      },
    );
  });

  group('nearbyBeachesProvider', () {
    testWidgets(
      'without a nearbyBeachesProvider, results stay the static placeholder '
      'list with no beach-info block',
      (tester) async {
        await tester.pumpWidget(wrap(const SearchScreen()));

        expect(find.text(staticBeaches.first.name), findsOneWidget);
        expect(find.textContaining('Wave height'), findsNothing);
      },
    );

    testWidgets(
      'a loaded nearbyBeachesProvider replaces the static list and shows '
      'real beach-info fields on each result',
      (tester) async {
        final provider = await _loadedFixtureProvider(tester);
        addTearDown(provider.dispose);
        expect(provider.status, NearbyBeachesStatus.loaded);

        await tester.pumpWidget(
          wrap(SearchScreen(nearbyBeachesProvider: provider)),
        );
        await tester.pump();

        expect(find.text('Fixture Beach'), findsOneWidget);
        expect(find.text(staticBeaches.first.name), findsNothing);

        final card = tester.widget<BeachResultCard>(
          find.byType(BeachResultCard),
        );
        expect(card.fee, BeachFee.free);
        expect(card.waveHeightMeters, closeTo(0.6, 0.001));
        expect(card.waterTemperatureCelsius, closeTo(23.0, 0.001));
        expect(card.shoeAdvice, ShoeAdvice.advised);
        expect(card.hasParking, isTrue);
        expect(find.textContaining('Wave height'), findsOneWidget);
      },
    );

    testWidgets(
      'a nearbyBeachesProvider mid-fetch shows the loading indicator',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final client = _PendingNetworkClient();
        final provider = NearbyBeachesProvider(
          OverpassService(client, endpoints: const ['https://example.com/api']),
          BeachCache(await SharedPreferences.getInstance()),
          MarineBatchService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(provider.dispose);
        provider.pickLocation(const LatLng(38.3, 26.3));
        await tester.pump(const Duration(milliseconds: 2));
        expect(provider.isLoading, isTrue);

        await tester.pumpWidget(
          wrap(SearchScreen(nearbyBeachesProvider: provider)),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(BeachResultCard), findsNothing);

        // Resolves the pending fetch so no future is left dangling past the
        // test, matching NearbyBeachesProvider's own test conventions.
        client.overpassCompleter.complete(
          http.StreamedResponse(
            Stream.value(utf8.encode('{"elements":[]}')),
            200,
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));
      },
    );
  });

  group('placeSearchProvider', () {
    testWidgets(
      'given no placeSearchProvider, typing a query -> no Places section appears',
      (tester) async {
        await tester.pumpWidget(wrap(const SearchScreen()));

        await tester.enterText(find.byType(TextField), 'istanbul');
        await tester.pump();

        expect(find.text('Places'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'given a search in flight, typing a query -> shows a loading indicator',
      (tester) async {
        final client = FakeHttpClient()
          ..queueJson(
            host: 'geocoding-api.open-meteo.com',
            json: {
              'results': [
                {'name': 'Istanbul', 'latitude': 41.0, 'longitude': 28.9},
              ],
            },
            delay: const Duration(milliseconds: 50),
          );
        final provider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(provider.dispose);

        await tester.pumpWidget(
          wrap(SearchScreen(placeSearchProvider: provider)),
        );
        await tester.enterText(find.byType(TextField), 'istanbul');
        await tester.pump(const Duration(milliseconds: 2));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 60));
      },
    );

    testWidgets(
      'given results beyond the static list, typing a query -> shows them in a Places section',
      (tester) async {
        final client = FakeHttpClient()
          ..queueJson(
            host: 'geocoding-api.open-meteo.com',
            json: {
              'results': [
                {
                  'name': 'Bodrum',
                  'latitude': 37.03,
                  'longitude': 27.43,
                  'admin1': 'Mugla',
                  'country': 'Turkey',
                },
              ],
            },
          );
        final provider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(provider.dispose);

        await tester.pumpWidget(
          wrap(SearchScreen(placeSearchProvider: provider)),
        );
        await tester.enterText(find.byType(TextField), 'bodrum');
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();

        expect(find.text('Bodrum'), findsOneWidget);
        expect(find.text('Mugla, Turkey'), findsOneWidget);
        // Bodrum is not in the static placeholder list, proving this came
        // from the geocoding search rather than the local name/city filter.
        expect(
          staticBeaches.any((b) => b.name == 'Bodrum' || b.city == 'Bodrum'),
          isFalse,
        );
      },
    );

    testWidgets(
      'given no matching places, typing a query -> shows an empty message',
      (tester) async {
        final client = FakeHttpClient()
          ..queueJson(
            host: 'geocoding-api.open-meteo.com',
            json: {'results': <Object?>[]},
          );
        final provider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(provider.dispose);

        await tester.pumpWidget(
          wrap(SearchScreen(placeSearchProvider: provider)),
        );
        await tester.enterText(find.byType(TextField), 'zzzzzz');
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();

        expect(find.text('No places match "zzzzzz".'), findsOneWidget);
      },
    );

    testWidgets(
      'given a failed search, typing a query -> shows an error message',
      (tester) async {
        final client = FakeHttpClient()
          ..queueResponse(
            host: 'geocoding-api.open-meteo.com',
            body: 'Service Unavailable',
            statusCode: 503,
          );
        final provider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(provider.dispose);

        await tester.pumpWidget(
          wrap(SearchScreen(placeSearchProvider: provider)),
        );
        await tester.enterText(find.byType(TextField), 'istanbul');
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();

        expect(
          find.text('Could not search for places. Please try again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('given a loaded place result, selecting it -> picks its exact '
        'location for nearbyBeachesProvider and clears the search field', (
      tester,
    ) async {
      final geocodingClient = FakeHttpClient()
        ..queueJson(
          host: 'geocoding-api.open-meteo.com',
          json: {
            'results': [
              {'name': 'Bodrum', 'latitude': 37.03, 'longitude': 27.43},
            ],
          },
        );
      final placeSearchProvider = PlaceSearchProvider(
        GeocodingService(geocodingClient),
        debounceDuration: const Duration(milliseconds: 1),
      );
      addTearDown(placeSearchProvider.dispose);

      SharedPreferences.setMockInitialValues({});
      final nearbyClient = FakeHttpClient()
        ..queueJson(host: 'overpass-api.de', json: {'elements': <Object?>[]})
        ..queueJson(host: 'marine-api.open-meteo.com', json: <Object?>[]);
      final nearbyBeachesProvider = NearbyBeachesProvider(
        OverpassService(nearbyClient),
        BeachCache(await SharedPreferences.getInstance()),
        MarineBatchService(nearbyClient),
        debounceDuration: const Duration(milliseconds: 1),
      );
      addTearDown(nearbyBeachesProvider.dispose);

      await tester.pumpWidget(
        wrap(
          SearchScreen(
            placeSearchProvider: placeSearchProvider,
            nearbyBeachesProvider: nearbyBeachesProvider,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'bodrum');
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump();

      expect(find.text('Bodrum'), findsOneWidget);
      expect(nearbyBeachesProvider.status, NearbyBeachesStatus.idle);

      await tester.tap(find.byKey(const ValueKey('place-result-0-Bodrum')));
      await tester.pump();

      expect(find.text('Bodrum'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );

      // Lets the debounced pickLocation fetch settle, then proves it was
      // called with Bodrum's own coordinates (not some other place's) by
      // inspecting the Overpass POST body the fetch actually sent: a
      // coordinate mix-up would send the wrong lat/lon here even though
      // the fixture response (and thus the final "loaded" status) looks
      // the same regardless of which point was requested.
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));

      // The fixture Overpass response has no beaches, so this resolves
      // to the explicit "empty" status rather than "loaded" — what
      // matters for this test is which coordinates were requested.
      expect(nearbyBeachesProvider.status, NearbyBeachesStatus.empty);
      final overpassRequest = nearbyClient.requests.single as http.Request;
      expect(overpassRequest.body, contains('37.03'));
      expect(overpassRequest.body, contains('27.43'));
    });

    testWidgets(
      'given two places with the same name, selecting the second -> picks '
      'its own (different) location, not the first',
      (tester) async {
        final geocodingClient = FakeHttpClient()
          ..queueJson(
            host: 'geocoding-api.open-meteo.com',
            json: {
              'results': [
                {'name': 'Springfield', 'latitude': 39.78, 'longitude': -89.65},
                {'name': 'Springfield', 'latitude': 42.1, 'longitude': -72.59},
              ],
            },
          );
        final placeSearchProvider = PlaceSearchProvider(
          GeocodingService(geocodingClient),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(placeSearchProvider.dispose);

        SharedPreferences.setMockInitialValues({});
        final nearbyClient = FakeHttpClient()
          ..queueJson(host: 'overpass-api.de', json: {'elements': <Object?>[]})
          ..queueJson(host: 'marine-api.open-meteo.com', json: <Object?>[]);
        final nearbyBeachesProvider = NearbyBeachesProvider(
          OverpassService(nearbyClient),
          BeachCache(await SharedPreferences.getInstance()),
          MarineBatchService(nearbyClient),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(nearbyBeachesProvider.dispose);

        await tester.pumpWidget(
          wrap(
            SearchScreen(
              placeSearchProvider: placeSearchProvider,
              nearbyBeachesProvider: nearbyBeachesProvider,
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'springfield');
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();

        // Both rows render without Flutter's duplicate-key assertion
        // firing (it would throw during this pump), each under its own
        // index-qualified key.
        expect(find.text('Springfield'), findsNWidgets(2));
        expect(
          find.byKey(const ValueKey('place-result-0-Springfield')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('place-result-1-Springfield')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('place-result-1-Springfield')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));

        final overpassRequest = nearbyClient.requests.single as http.Request;
        expect(overpassRequest.body, contains('42.1'));
        expect(overpassRequest.body, contains('-72.59'));
        expect(overpassRequest.body, isNot(contains('39.78')));
      },
    );
  });

  group('tapping a beach result (#214)', () {
    testWidgets('tapping a beach card pops the screen with that exact Beach', (
      tester,
    ) async {
      Beach? popped;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<Beach>(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(staticBeaches.first.name), findsOneWidget);
      await tester.tap(find.text(staticBeaches.first.name));
      await tester.pumpAndSettle();

      expect(popped, same(staticBeaches.first));
      // The screen itself is gone — popped back to the `open` button.
      expect(find.byType(SearchScreen), findsNothing);
    });

    testWidgets(
      'tapping the favorite heart toggles the favorite and does NOT pop '
      'the screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final favoritesProvider = FavoritesProvider(
          await SharedPreferences.getInstance(),
        );
        addTearDown(favoritesProvider.dispose);
        Beach? popped;
        var didPop = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<Beach>(
                      MaterialPageRoute(
                        builder: (_) =>
                            SearchScreen(favoritesProvider: favoritesProvider),
                      ),
                    );
                    didPop = true;
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.favorite_border).first);
        await tester.pump();

        expect(favoritesProvider.isFavorite(staticBeaches.first), isTrue);
        expect(didPop, isFalse);
        expect(popped, isNull);
        expect(find.byType(SearchScreen), findsOneWidget);
      },
    );
  });

  group(
    'selecting a "Places" result also moves the Home map camera (#214)',
    () {
      testWidgets(
        'given onLocationPicked, selecting a place calls it with the exact '
        'point and name, without popping the screen',
        (tester) async {
          final geocodingClient = FakeHttpClient()
            ..queueJson(
              host: 'geocoding-api.open-meteo.com',
              json: {
                'results': [
                  {'name': 'Bodrum', 'latitude': 37.03, 'longitude': 27.43},
                ],
              },
            );
          final placeSearchProvider = PlaceSearchProvider(
            GeocodingService(geocodingClient),
            debounceDuration: const Duration(milliseconds: 1),
          );
          addTearDown(placeSearchProvider.dispose);

          LatLng? pickedPoint;
          String? pickedName;

          await tester.pumpWidget(
            wrap(
              SearchScreen(
                placeSearchProvider: placeSearchProvider,
                onLocationPicked: (point, name) {
                  pickedPoint = point;
                  pickedName = name;
                },
              ),
            ),
          );
          await tester.enterText(find.byType(TextField), 'bodrum');
          await tester.pump(const Duration(milliseconds: 2));
          await tester.pump();

          await tester.tap(find.byKey(const ValueKey('place-result-0-Bodrum')));
          await tester.pump();

          expect(pickedPoint, const LatLng(37.03, 27.43));
          expect(pickedName, 'Bodrum');
          // Stays open — unlike a beach-card tap, a place pick doesn't pop.
          expect(find.byType(SearchScreen), findsOneWidget);
        },
      );

      testWidgets(
        'given no onLocationPicked, selecting a place still re-centers '
        'nearbyBeachesProvider exactly as before (no behavior change for '
        'existing callers)',
        (tester) async {
          final geocodingClient = FakeHttpClient()
            ..queueJson(
              host: 'geocoding-api.open-meteo.com',
              json: {
                'results': [
                  {'name': 'Bodrum', 'latitude': 37.03, 'longitude': 27.43},
                ],
              },
            );
          final placeSearchProvider = PlaceSearchProvider(
            GeocodingService(geocodingClient),
            debounceDuration: const Duration(milliseconds: 1),
          );
          addTearDown(placeSearchProvider.dispose);

          SharedPreferences.setMockInitialValues({});
          final nearbyClient = FakeHttpClient()
            ..queueJson(
              host: 'overpass-api.de',
              json: {'elements': <Object?>[]},
            )
            ..queueJson(host: 'marine-api.open-meteo.com', json: <Object?>[]);
          final nearbyBeachesProvider = NearbyBeachesProvider(
            OverpassService(nearbyClient),
            BeachCache(await SharedPreferences.getInstance()),
            MarineBatchService(nearbyClient),
            debounceDuration: const Duration(milliseconds: 1),
          );
          addTearDown(nearbyBeachesProvider.dispose);

          await tester.pumpWidget(
            wrap(
              SearchScreen(
                placeSearchProvider: placeSearchProvider,
                nearbyBeachesProvider: nearbyBeachesProvider,
              ),
            ),
          );
          await tester.enterText(find.byType(TextField), 'bodrum');
          await tester.pump(const Duration(milliseconds: 2));
          await tester.pump();

          await tester.tap(find.byKey(const ValueKey('place-result-0-Bodrum')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 10));
          await tester.pump(const Duration(milliseconds: 10));

          final overpassRequest = nearbyClient.requests.single as http.Request;
          expect(overpassRequest.body, contains('37.03'));
          expect(overpassRequest.body, contains('27.43'));
        },
      );
    },
  );

  group('didUpdateWidget provider swap', () {
    testWidgets('given every provider is replaced with a new instance, '
        'didUpdateWidget -> detaches from each old provider and attaches to '
        'its replacement', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final emptyClient = FakeHttpClient()
        ..queueJson(host: 'overpass-api.de', json: {'elements': <Object?>[]})
        ..queueJson(host: 'marine-api.open-meteo.com', json: <Object?>[])
        ..queueJson(host: 'overpass-api.de', json: {'elements': <Object?>[]})
        ..queueJson(host: 'marine-api.open-meteo.com', json: <Object?>[]);

      final favoritesA = _ProbeFavoritesProvider(prefs);
      final favoritesB = _ProbeFavoritesProvider(prefs);
      final unitPrefsA = _ProbeUnitPreferencesProvider(prefs);
      final unitPrefsB = _ProbeUnitPreferencesProvider(prefs);
      final nearbyA = _ProbeNearbyBeachesProvider(
        OverpassService(emptyClient),
        BeachCache(prefs),
        MarineBatchService(emptyClient),
      );
      final nearbyB = _ProbeNearbyBeachesProvider(
        OverpassService(emptyClient),
        BeachCache(prefs),
        MarineBatchService(emptyClient),
      );
      final placeA = _ProbePlaceSearchProvider(GeocodingService(emptyClient));
      final placeB = _ProbePlaceSearchProvider(GeocodingService(emptyClient));
      addTearDown(() {
        for (final p in [
          favoritesA,
          favoritesB,
          unitPrefsA,
          unitPrefsB,
          nearbyA,
          nearbyB,
          placeA,
          placeB,
        ]) {
          p.dispose();
        }
      });

      await tester.pumpWidget(
        wrap(
          SearchScreen(
            favoritesProvider: favoritesA,
            unitPreferencesProvider: unitPrefsA,
            nearbyBeachesProvider: nearbyA,
            placeSearchProvider: placeA,
          ),
        ),
      );

      expect(favoritesA.isListenedTo, isTrue);
      expect(unitPrefsA.isListenedTo, isTrue);
      expect(nearbyA.isListenedTo, isTrue);
      expect(placeA.isListenedTo, isTrue);
      expect(favoritesB.isListenedTo, isFalse);
      expect(unitPrefsB.isListenedTo, isFalse);
      expect(nearbyB.isListenedTo, isFalse);
      expect(placeB.isListenedTo, isFalse);

      await tester.pumpWidget(
        wrap(
          SearchScreen(
            favoritesProvider: favoritesB,
            unitPreferencesProvider: unitPrefsB,
            nearbyBeachesProvider: nearbyB,
            placeSearchProvider: placeB,
          ),
        ),
      );

      expect(favoritesA.isListenedTo, isFalse);
      expect(unitPrefsA.isListenedTo, isFalse);
      expect(nearbyA.isListenedTo, isFalse);
      expect(placeA.isListenedTo, isFalse);
      expect(favoritesB.isListenedTo, isTrue);
      expect(unitPrefsB.isListenedTo, isTrue);
      expect(nearbyB.isListenedTo, isTrue);
      expect(placeB.isListenedTo, isTrue);
    });

    testWidgets('given the same provider instance is kept across a rebuild, '
        'didUpdateWidget -> never re-subscribes (addListener/removeListener '
        'are each called exactly once, from initState/dispose, not again)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final favorites = _ProbeFavoritesProvider(prefs);
      addTearDown(favorites.dispose);

      await tester.pumpWidget(wrap(SearchScreen(favoritesProvider: favorites)));
      expect(favorites.addListenerCallCount, 1);
      expect(favorites.removeListenerCallCount, 0);

      // A rebuild with an unchanged `favoritesProvider` instance (only
      // `isLoading` differs) still runs `didUpdateWidget` — it must not
      // drop and re-add the listener on every such rebuild.
      await tester.pumpWidget(
        wrap(SearchScreen(favoritesProvider: favorites, isLoading: false)),
      );

      expect(favorites.addListenerCallCount, 1);
      expect(favorites.removeListenerCallCount, 0);
      expect(favorites.isListenedTo, isTrue);
    });
  });
}
