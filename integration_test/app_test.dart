import 'dart:convert';

import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/services/geocoding_service.dart';
import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:beachiq/data/services/overpass_service.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/logic/providers/place_search_provider.dart';
import 'package:beachiq/main.dart';
import 'package:beachiq/presentation/screens/home_screen.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Minimal valid 1x1 transparent PNG so map tiles resolve without network.
final _transparentPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPixelPng);
  }
}

/// A fake [http.Client] that never touches the real network: it answers an
/// Overpass query with a single fixture beach and a marine-batch request
/// with fixture wave/temperature data, keyed off the request host.
class _FixtureNetworkClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.host.contains('overpass')) {
      final body = json.encode([
        {
          'current': {
            'wave_height': 0.7,
            'wave_direction': 180,
            'wave_period': 5,
            'sea_surface_temperature': 24.5,
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
          },
          'geometry': [
            {'lat': 38.30, 'lon': 26.30},
            {'lat': 38.31, 'lon': 26.30},
            {'lat': 38.31, 'lon': 26.31},
          ],
        },
        {
          // Within the mapper's 150m amenity-attach radius of the beach
          // geometry's (38.30, 26.30) corner (~42m away); the original
          // (38.303, 26.303) here was ~425m away, so it never attached.
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

/// App-level smoke test: boots the real widget tree (MarineApp with its
/// provider) on a device/emulator and checks the home screen comes up.
/// Extend this file whenever a PR adds or changes a screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots, provides MarineProvider and shows the map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MarineApp(tileProvider: _FakeTileProvider()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);

    final context = tester.element(find.byType(HomeScreen));
    final provider = Provider.of<MarineProvider>(context, listen: false);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
  });

  testWidgets(
    'Home to Search navigation: tapping the search entry opens Search, '
    'the back chevron returns to Home',
    (WidgetTester tester) async {
      await tester.pumpWidget(MarineApp(tileProvider: _FakeTileProvider()));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);

      await tester.tap(find.byKey(const Key('home-search-entry')));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);
    },
  );

  testWidgets(
    'Nearby beaches flow: Home fetches real beaches for the fixed place '
    'center on boot, and Search shows the result card with real '
    'fixture-derived fields',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final overpassService = OverpassService(_FixtureNetworkClient());
      final marineBatchService = MarineBatchService(_FixtureNetworkClient());
      final beachCache = BeachCache(await SharedPreferences.getInstance());
      final provider = NearbyBeachesProvider(
        overpassService,
        beachCache,
        marineBatchService,
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        MarineApp(
          tileProvider: _FakeTileProvider(),
          nearbyBeachesProvider: provider,
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.status, NearbyBeachesStatus.loaded);

      await tester.tap(find.byKey(const Key('home-search-entry')));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.byType(BeachResultCard), findsOneWidget);

      final card = tester.widget<BeachResultCard>(find.byType(BeachResultCard));
      expect(card.placeName, 'Fixture Beach');
      expect(card.areaSubtitle, 'Cesme');
      expect(card.fee, BeachFee.free);
      expect(card.waveHeightMeters, closeTo(0.7, 0.001));
      expect(card.waterTemperatureCelsius, closeTo(24.5, 0.001));
      expect(card.hasParking, isTrue);
    },
  );

  testWidgets(
    'Place search flow: typing a city on Search finds a real place beyond '
    'the fixture beach, and selecting it re-centers nearbyBeachesProvider',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final nearbyClient = _FixtureNetworkClient();
      final nearbyBeachesProvider = NearbyBeachesProvider(
        OverpassService(nearbyClient),
        BeachCache(await SharedPreferences.getInstance()),
        MarineBatchService(nearbyClient),
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(nearbyBeachesProvider.dispose);

      final geocodingClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'results': [
              {'name': 'Bodrum', 'latitude': 37.03, 'longitude': 27.43},
            ],
          }),
          200,
        );
      });
      final placeSearchProvider = PlaceSearchProvider(
        GeocodingService(geocodingClient),
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(placeSearchProvider.dispose);

      await tester.pumpWidget(
        MarineApp(
          tileProvider: _FakeTileProvider(),
          nearbyBeachesProvider: nearbyBeachesProvider,
          placeSearchProvider: placeSearchProvider,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-search-entry')));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'bodrum');
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();

      expect(find.text('Bodrum'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('place-result-0-Bodrum')));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();

      expect(nearbyBeachesProvider.status, NearbyBeachesStatus.loaded);
      expect(nearbyBeachesProvider.beaches.single.name, 'Fixture Beach');
    },
  );
}
