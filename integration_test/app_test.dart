import 'dart:convert';

import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:beachiq/data/services/overpass_service.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/main.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
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
          'type': 'node',
          'id': 2,
          'lat': 38.303,
          'lon': 26.303,
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

/// A minimal "nearby beaches" results sheet composed from already-shipped
/// widgets/providers (the map's tap-to-pick from #79, the real-field
/// binding from #81) purely for this test's own widget tree — mirroring
/// what a future screen composition would render, without touching any
/// `lib/` source file.
class _NearbyBeachesResultsSheet extends StatelessWidget {
  const _NearbyBeachesResultsSheet({required this.provider});

  final NearbyBeachesProvider provider;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) => Column(
        children: [
          for (final beach in provider.beaches)
            BeachResultCard(
              placeName: beach.name,
              areaSubtitle: beach.city,
              temperature: '--°',
              fee: beach.fee,
              waveHeightMeters: provider.seaConditionFor(beach)?.waveHeight,
              waterTemperatureCelsius:
                  provider.seaConditionFor(beach)?.seaSurfaceTemperature,
              hasParking: beach.hasParking,
              hasBeachResort: beach.hasBeachResort,
              hasCafe: beach.hasCafe,
            ),
        ],
      ),
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
    'Nearby beaches flow: picking a location on the map lists a beach and '
    'the result card shows real fixture-derived fields',
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

      const center = LatLng(38.3, 26.3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LocationMapCard(
                  center: center,
                  placeName: 'Cesme, Izmir',
                  tileProvider: _FakeTileProvider(),
                  nearbyBeachesProvider: provider,
                ),
                Expanded(child: _NearbyBeachesResultsSheet(provider: provider)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BeachResultCard), findsNothing);

      // Tapping the map's visual center taps `initialCenter`. flutter_map
      // delays a single tap by its double-tap-to-zoom window before firing
      // `onTap`, so the first pump has to advance past that; the second
      // advances past the provider's own (shortened) debounce.
      await tester.tap(find.byType(FlutterMap));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(provider.status, NearbyBeachesStatus.loaded);
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
}
