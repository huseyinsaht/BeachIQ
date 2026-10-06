import 'dart:async';
import 'dart:convert';

import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/models/weather_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/data/services/bathymetry_service.dart';
import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/services/depth_cache.dart';
import 'package:beachiq/data/services/geocoding_service.dart';
import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:beachiq/data/services/overpass_service.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:beachiq/logic/providers/depth_provider.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/logic/providers/place_search_provider.dart';
import 'package:beachiq/logic/providers/weather_provider.dart';
import 'package:beachiq/main.dart';
import 'package:beachiq/presentation/screens/detail/current_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/depth_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/rain_chance_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/uv_index_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/water_temperature_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/wave_height_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/wind_detail_screen.dart';
import 'package:beachiq/presentation/screens/home_screen.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/amenity_legend.dart';
import 'package:beachiq/presentation/widgets/amenity_marker.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/forecast_alert_list.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
import 'package:beachiq/presentation/widgets/sea_conditions_row.dart';
import 'package:beachiq/presentation/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/builders.dart' show aSeaCondition, aSeaHourly;
import '../test/helpers/fake_http_client.dart' show FakeHttpClient;
import '../test/helpers/pump_app.dart'
    show aLoadedMarineProvider, aLoadedWeatherProvider;

/// Records every (lat, lon) [WeatherRepository.getWeatherData] is asked
/// for, resolving to [results] at the matching call index (repeating the
/// last one if asked more times than [results] has entries) — so a map
/// pick's re-fetch can be told apart from the initial load's (#157).
class _RecordingWeatherRepository extends WeatherRepository {
  _RecordingWeatherRepository(this.results) : super(WeatherApiService());

  final List<WeatherCondition> results;
  final List<(double, double)> calls = [];

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async {
    calls.add((lat, lon));
    final index = calls.length - 1 < results.length
        ? calls.length - 1
        : results.length - 1;
    return results[index];
  }
}

/// Like [_RecordingWeatherRepository], but for [MarineRepository].
class _RecordingMarineRepository extends MarineRepository {
  _RecordingMarineRepository(this.results) : super(MarineApiService());

  final List<SeaCondition> results;
  final List<(double, double)> calls = [];

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    calls.add((lat, lon));
    final index = calls.length - 1 < results.length
        ? calls.length - 1
        : results.length - 1;
    return results[index];
  }
}

/// A [WeatherRepository] whose calls each get their own [Completer], kept
/// in [calls] in call order, so a test can resolve a later pick's fetch
/// before an earlier one — the "last tap wins" out-of-order scenario
/// (#213) — without any real network delay to race against.
class _SequentialWeatherRepository extends WeatherRepository {
  _SequentialWeatherRepository() : super(WeatherApiService());

  final List<Completer<WeatherCondition>> calls = [];

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) {
    final completer = Completer<WeatherCondition>();
    calls.add(completer);
    return completer.future;
  }
}

/// Like [_SequentialWeatherRepository], but for [MarineRepository].
class _SequentialMarineRepository extends MarineRepository {
  _SequentialMarineRepository() : super(MarineApiService());

  final List<Completer<SeaCondition>> calls = [];

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) {
    final completer = Completer<SeaCondition>();
    calls.add(completer);
    return completer.future;
  }
}

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

/// Like [_FixtureNetworkClient], but the beach way (and its one amenity)
/// sits right at `HomeScreen`'s fixed `_placeCenter` (38.3220, 26.3260)
/// instead of ~2.4 km away - needed so the marker is inside the small map
/// card's visible viewport, rather than culled off-screen by flutter_map's
/// `MarkerLayer`.
class _FixtureNetworkClientNearPlaceCenter extends http.BaseClient {
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
            {'lat': 38.3220, 'lon': 26.3260},
            {'lat': 38.3230, 'lon': 26.3260},
            {'lat': 38.3230, 'lon': 26.3270},
          ],
        },
        {
          'type': 'node',
          'id': 2,
          'lat': 38.32205,
          'lon': 26.3261,
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
    // Fixture providers keep Home off the real network: with MarineApp's
    // real defaults the fetch can stay pending, the loading spinner
    // animates forever and pumpAndSettle times out (#228).
    final weatherProvider = await aLoadedWeatherProvider(
      WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
    );
    final marineProvider = await aLoadedMarineProvider(
      SeaCondition(waveHeight: 0.3),
    );

    await tester.pumpWidget(
      MarineApp(
        tileProvider: _FakeTileProvider(),
        weatherProvider: weatherProvider,
        marineProvider: marineProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);

    final context = tester.element(find.byType(HomeScreen));
    final provider = Provider.of<MarineProvider>(context, listen: false);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
  });

  testWidgets(
    'Home to Search navigation: opening Search via the map card overflow '
    "menu's \"Beaches\" entry (#158), the back chevron returns to Home",
    (WidgetTester tester) async {
      // Fixture providers keep Home off the real network (see the boot
      // test above, #228).
      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
      );
      final marineProvider = await aLoadedMarineProvider(
        SeaCondition(waveHeight: 0.3),
      );

      await tester.pumpWidget(
        MarineApp(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
          marineProvider: marineProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);
      // #158: the old standalone, non-editable "Enter cities" entry point
      // is gone — the map card's own search icon is the only place-search
      // entry left on Home.
      expect(find.byType(SearchField), findsNothing);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beaches'));
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

      // Fixture providers keep Home off the real network (#228).
      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
      );
      final marineProvider = await aLoadedMarineProvider(
        SeaCondition(waveHeight: 0.3),
      );

      await tester.pumpWidget(
        MarineApp(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
          marineProvider: marineProvider,
          nearbyBeachesProvider: provider,
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.status, NearbyBeachesStatus.loaded);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beaches'));
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
    'Wind detail flow: tapping the wind speed stat tile on Home opens '
    'WindDetailScreen with the real WeatherProvider data, and the back '
    "button returns to Home (no real network: WeatherProvider's repository "
    'is faked via test/helpers/pump_app.dart)',
    (WidgetTester tester) async {
      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(
          temperature: 27,
          windSpeed: 18,
          weatherCode: 1,
          hourly: [
            WeatherHourly(
              time: DateTime(2026, 1, 1, 12),
              temperature: 26,
              weatherCode: 1,
              windSpeed: 18,
              windGusts: 28,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            now: () => DateTime(2026, 1, 1, 12, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WindDetailScreen), findsNothing);

      await tester.ensureVisible(find.text('18 km/h'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18 km/h'));
      await tester.pumpAndSettle();

      expect(find.byType(WindDetailScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Gusts'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(WindDetailScreen), findsNothing);
    },
  );

  testWidgets(
    'Rain chance detail flow: tapping the rain chance stat tile on Home '
    'opens RainChanceDetailScreen with the real WeatherProvider data, and '
    "the back button returns to Home (no real network: WeatherProvider's "
    'repository is faked via test/helpers/pump_app.dart)',
    (WidgetTester tester) async {
      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(
          temperature: 27,
          windSpeed: 12,
          weatherCode: 1,
          rainChancePercent: 55,
          hourly: [
            WeatherHourly(
              time: DateTime(2026, 1, 1, 12),
              temperature: 26,
              weatherCode: 1,
              rainChancePercent: 55,
            ),
            WeatherHourly(
              time: DateTime(2026, 1, 1, 13),
              temperature: 26,
              weatherCode: 1,
              rainChancePercent: 60,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            now: () => DateTime(2026, 1, 1, 12, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RainChanceDetailScreen), findsNothing);

      await tester.ensureVisible(find.text('55%'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('55%'));
      await tester.pumpAndSettle();

      expect(find.byType(RainChanceDetailScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      // now (12:30) falls inside the 12:00 hour's own bucket, so that
      // entry (55%) still counts as current/upcoming and merges with the
      // contiguous 13:00 hour into one window, not just "13:00 and 14:00".
      expect(find.text('Rain likely between 12:00 and 14:00.'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(RainChanceDetailScreen), findsNothing);
    },
  );

  testWidgets(
    'UV index detail flow: tapping the UV index stat tile on Home opens '
    'UvIndexDetailScreen with the real WeatherProvider data, and the back '
    "button returns to Home (no real network: WeatherProvider's repository "
    'is faked via test/helpers/pump_app.dart)',
    (WidgetTester tester) async {
      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(
          temperature: 27,
          windSpeed: 12,
          weatherCode: 1,
          uvIndex: 4.5,
          hourly: [
            WeatherHourly(
              time: DateTime(2026, 1, 1, 12),
              temperature: 26,
              weatherCode: 1,
              uvIndex: 4.5,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            now: () => DateTime(2026, 1, 1, 12, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UvIndexDetailScreen), findsNothing);

      // The UV index tile sits below the fold on the test surface's fixed
      // size, so it needs scrolling into view before it can be hit.
      await tester.ensureVisible(find.text('4.5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4.5'));
      await tester.pumpAndSettle();

      expect(find.byType(UvIndexDetailScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(UvIndexDetailScreen), findsNothing);
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

      // Fixture providers keep Home off the real network: with MarineApp's
      // real defaults the fetch never completes, the loading spinner
      // animates forever and pumpAndSettle times out (#228).
      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
      );
      final marineProvider = await aLoadedMarineProvider(
        SeaCondition(waveHeight: 0.3),
      );

      await tester.pumpWidget(
        MarineApp(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
          marineProvider: marineProvider,
          nearbyBeachesProvider: nearbyBeachesProvider,
          placeSearchProvider: placeSearchProvider,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beaches'));
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

  testWidgets(
    'Map card search flow (#158): typing in the map card\'s own search '
    'icon finds a real place and selecting it recenters the map and '
    "re-fetches nearbyBeachesProvider — Home's old standalone search "
    'entry is gone',
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

      // Selecting a place goes through `onLocationPicked`
      // (`HomeScreen._handleLocationPicked`), which also re-fetches
      // weather/marine data for the new point — unlike `SearchScreen`'s
      // own place search, which only re-centers `nearbyBeachesProvider`.
      // Fixture repositories (instead of `MarineApp`'s real default
      // providers) keep that re-fetch off the real network.
      final weatherProvider = WeatherProvider(
        _RecordingWeatherRepository([
          WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
          WeatherCondition(temperature: 31, windSpeed: 8, weatherCode: 1),
        ]),
      );
      final marineProvider = MarineProvider(
        _RecordingMarineRepository([
          SeaCondition(waveHeight: 0.3),
          SeaCondition(waveHeight: 1.0),
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            nearbyBeachesProvider: nearbyBeachesProvider,
            placeSearchProvider: placeSearchProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The map card's own icon is the only place-search entry on Home.
      expect(find.byType(SearchField), findsNothing);
      expect(find.byKey(const Key('map-search-toggle')), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-search-toggle')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bodrum');
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();

      expect(find.text('Bodrum'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('map-search-result-0-Bodrum')),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();

      expect(nearbyBeachesProvider.status, NearbyBeachesStatus.loaded);
      expect(nearbyBeachesProvider.beaches.single.name, 'Fixture Beach');
      // Beaches is still reachable via the overflow menu.
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Beaches'), findsOneWidget);
    },
  );

  testWidgets('Sea section flow: Home renders wave height, water temp, wave '
      'direction, current speed and current direction from a real-looking '
      'MarineProvider (#163)', (WidgetTester tester) async {
    final marineProvider = await aLoadedMarineProvider(
      aSeaCondition(
        waveHeight: 0.9,
        seaSurfaceTemperature: 23.5,
        waveDirection: 315,
        currentVelocity: 4.0,
        currentDirection: 135,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tileProvider: _FakeTileProvider(),
          marineProvider: marineProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SeaConditionsRow), findsOneWidget);
    expect(find.text('0.9 m'), findsOneWidget);
    expect(find.text('24°C'), findsOneWidget);
    expect(find.text('from NW'), findsOneWidget);
    expect(find.text('4 km/h'), findsOneWidget);
    expect(find.text('toward SE'), findsOneWidget);
  });

  testWidgets(
    'Wave height detail flow (#167): tapping the wave height tile in the '
    'Sea section opens WaveHeightDetailScreen (its own page) with the real '
    'MarineProvider hourly series, and the back button returns to Home',
    (WidgetTester tester) async {
      final marineProvider = await aLoadedMarineProvider(
        aSeaCondition(
          waveHeight: 0.9,
          hourly: [
            aSeaHourly(
              time: DateTime(2026, 1, 1, 12),
              waveHeight: 0.9,
              waveDirection: 315,
              wavePeriod: 5.5,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: marineProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WaveHeightDetailScreen), findsNothing);

      await tester.tap(find.byKey(const Key('wave-height-tile')));
      await tester.pumpAndSettle();

      expect(find.byType(WaveHeightDetailScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      // The real hourly series carried through to the chart's period/
      // direction row underneath it.
      expect(find.text('5.5s'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(WaveHeightDetailScreen), findsNothing);
    },
  );

  testWidgets(
    'Water temperature detail flow (#180): tapping the water temperature '
    'tile in the Sea section opens WaterTemperatureDetailScreen (its own '
    'page) with the real MarineProvider hourly series, and the back '
    'button returns to Home',
    (WidgetTester tester) async {
      final marineProvider = await aLoadedMarineProvider(
        aSeaCondition(
          seaSurfaceTemperature: 22.0,
          hourly: [
            aSeaHourly(
              time: DateTime(2026, 1, 1, 12),
              seaSurfaceTemperature: 22.0,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: marineProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WaterTemperatureDetailScreen), findsNothing);

      await tester.tap(find.byKey(const Key('water-temperature-tile')));
      await tester.pumpAndSettle();

      expect(find.byType(WaterTemperatureDetailScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.textContaining('Pleasant — '), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(WaterTemperatureDetailScreen), findsNothing);
    },
  );

  testWidgets(
    'Ocean current detail flow (#181): tapping the current speed tile in '
    'the Sea section opens CurrentDetailScreen (its own page) with the '
    'real MarineProvider hourly series and direction, and the back button '
    'returns to Home',
    (WidgetTester tester) async {
      final marineProvider = await aLoadedMarineProvider(
        aSeaCondition(
          currentVelocity: 8.0,
          currentDirection: 135,
          hourly: [
            aSeaHourly(
              time: DateTime(2026, 1, 1, 12),
              currentVelocity: 8.0,
              currentDirection: 135,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: marineProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CurrentDetailScreen), findsNothing);

      await tester.tap(find.byKey(const Key('current-speed-tile')));
      await tester.pumpAndSettle();

      expect(find.byType(CurrentDetailScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      // The real hourly series carried through to the direction strip.
      expect(find.byKey(const Key('current-direction-strip')), findsOneWidget);
      expect(find.text('SE'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(CurrentDetailScreen), findsNothing);
    },
  );

  testWidgets(
    'Amenity markers flow (#172): once beaches load, their real amenities '
    "appear as markers on Home's map, with a legend chip for the kind "
    'present',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      // _FixtureNetworkClient's beach sits ~2.4 km from HomeScreen's fixed
      // _placeCenter, which flutter_map's MarkerLayer culls as outside the
      // small map card's visible viewport at its zoom - this dedicated
      // fixture instead puts the beach (and its amenity) right at
      // _placeCenter so the marker is actually on screen to find.
      final client = _FixtureNetworkClientNearPlaceCenter();
      final overpassService = OverpassService(client);
      final marineBatchService = MarineBatchService(client);
      final beachCache = BeachCache(await SharedPreferences.getInstance());
      final nearbyBeachesProvider = NearbyBeachesProvider(
        overpassService,
        beachCache,
        marineBatchService,
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(nearbyBeachesProvider.dispose);

      // Fixture providers keep Home off the real network: with MarineApp's
      // real defaults the fetch never completes, the sectional loading
      // placeholder (#228) animates forever and pumpAndSettle times out.
      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
      );
      final marineProvider = await aLoadedMarineProvider(
        SeaCondition(waveHeight: 0.3),
      );

      await tester.pumpWidget(
        MarineApp(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
          marineProvider: marineProvider,
          nearbyBeachesProvider: nearbyBeachesProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(nearbyBeachesProvider.status, NearbyBeachesStatus.loaded);
      expect(nearbyBeachesProvider.beaches.single.amenities, isNotEmpty);
      expect(find.byType(AmenityMarker), findsOneWidget);
      // "Parking" appears twice once the pin's own label is drawn (the
      // legend chip and the marker's under-pin label, since this fixture's
      // amenity has no OSM name), so scope to the legend specifically.
      expect(
        find.descendant(
          of: find.byType(AmenityLegend),
          matching: find.text('Parking'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Forecast alert list flow (#169): a real wind crossing from '
      "WeatherProvider's hourly series renders as a visible alert row "
      'between the smart suggestion pill and the stat grid, with no real '
      'network involved (WeatherProvider/MarineProvider are faked via '
      'test/helpers/pump_app.dart, the same fakes the other Home flows '
      'above use)', (WidgetTester tester) async {
    final weatherProvider = await aLoadedWeatherProvider(
      WeatherCondition(
        temperature: 27,
        windSpeed: 10,
        weatherCode: 1,
        hourly: [
          WeatherHourly(
            time: DateTime(2026, 1, 1, 9),
            temperature: 26,
            weatherCode: 1,
            windSpeed: 10,
          ),
          WeatherHourly(
            // Crosses the 40 km/h "high" threshold -> a high-severity
            // wind alert from 09:00 to 10:00.
            time: DateTime(2026, 1, 1, 10),
            temperature: 26,
            weatherCode: 1,
            windSpeed: 45,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
          now: () => DateTime(2026, 1, 1, 8, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ForecastAlertList), findsOneWidget);
    expect(find.textContaining('Wind crosses 40 km/h'), findsOneWidget);
    expect(find.text('09:00 - 10:00'), findsOneWidget);
  });

  testWidgets(
    'Forecast alert daylight filter and next-hour note flow (#229): a '
    'night-time crossing outside the location\'s real sunrise/sunset '
    'window (from WeatherProvider) is hidden, while a change between the '
    'current and next hour still surfaces as a next-hour note even after '
    'sunset',
    (WidgetTester tester) async {
      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(
          temperature: 22,
          windSpeed: 10,
          weatherCode: 1,
          hourly: [
            WeatherHourly(
              time: DateTime(2026, 1, 1, 21),
              temperature: 20,
              weatherCode: 1,
              windSpeed: 10,
            ),
            WeatherHourly(
              // Crosses the 40 km/h "high" threshold, but 21:00 -> 22:00 is
              // after the 20:00 sunset below, so it must not appear as a
              // daylight alert row — only as the next-hour note.
              time: DateTime(2026, 1, 1, 22),
              temperature: 19,
              weatherCode: 1,
              windSpeed: 45,
            ),
          ],
          daylightWindows: [
            DaylightWindow(
              sunrise: DateTime(2026, 1, 1, 6),
              sunset: DateTime(2026, 1, 1, 20),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            now: () => DateTime(2026, 1, 1, 21),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ForecastAlertList), findsOneWidget);
      expect(find.text('Next hour'), findsOneWidget);
      // findsOneWidget also proves the daylight-filtered alert pipeline did
      // not additionally render this as a second, duplicate row.
      expect(find.textContaining('Wind crosses 40 km/h'), findsOneWidget);
    },
  );

  testWidgets(
    'Pick-a-location flow (#157): tapping the map re-fetches weather, '
    'marine and nearby-beaches data for the tapped point and updates the '
    'header, and the pick survives a restart',
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

      final weatherRepository = _RecordingWeatherRepository([
        WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
        WeatherCondition(temperature: 31, windSpeed: 8, weatherCode: 1),
      ]);
      final marineRepository = _RecordingMarineRepository([
        SeaCondition(waveHeight: 0.3),
        SeaCondition(waveHeight: 1.6),
      ]);
      final weatherProvider = WeatherProvider(weatherRepository);
      final marineProvider = MarineProvider(marineRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            nearbyBeachesProvider: nearbyBeachesProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial load: the Çeşme first-run default — one weather fetch, no
      // marine fetch yet (marine is only fetched on an explicit
      // refresh/pick, never automatically on first load).
      expect(weatherRepository.calls, hasLength(1));
      expect(marineRepository.calls, isEmpty);
      expect(find.text('27°'), findsOneWidget);
      expect(find.text('Çeşme, İzmir'), findsNWidgets(2));

      // Tap the map's own center: flutter_map's lat/lng <-> pixel
      // projection round-trip introduces enough floating-point noise that
      // the resulting point is a genuinely distinct double from the
      // original, which is what actually proves a *new* fetch happened.
      await tester.tap(find.byType(FlutterMap));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // The whole data path moved to the newly picked point: weather,
      // marine and the nearby-beaches overlay all re-fetched, and the
      // header/place name reflect it instead of the original Çeşme fetch.
      expect(weatherRepository.calls, hasLength(2));
      expect(weatherRepository.calls[1], isNot(weatherRepository.calls[0]));
      expect(marineRepository.calls, hasLength(1));
      expect(marineRepository.calls.single, weatherRepository.calls[1]);
      expect(nearbyBeachesProvider.status, NearbyBeachesStatus.loaded);
      expect(find.text('31°'), findsOneWidget);
      expect(find.text('27°'), findsNothing);
      expect(find.text('Çeşme, İzmir'), findsNothing);

      final pickedPoint = weatherRepository.calls[1];

      // "Restart": a brand new HomeScreen (forced via a distinct key, so a
      // fresh State actually gets created instead of just updating the
      // existing one in place) reads the pick back from the same
      // (mocked) SharedPreferences backing store.
      final restartedWeatherRepository = _RecordingWeatherRepository([
        WeatherCondition(temperature: 31, windSpeed: 8, weatherCode: 1),
      ]);
      final restartedWeatherProvider = WeatherProvider(
        restartedWeatherRepository,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: const ValueKey('restarted-home-screen'),
            tileProvider: _FakeTileProvider(),
            weatherProvider: restartedWeatherProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(restartedWeatherRepository.calls, hasLength(1));
      expect(
        restartedWeatherRepository.calls.single.$1,
        closeTo(pickedPoint.$1, 0.0001),
      );
      expect(
        restartedWeatherRepository.calls.single.$2,
        closeTo(pickedPoint.$2, 0.0001),
      );
      expect(find.text('Çeşme, İzmir'), findsNothing);
    },
  );

  testWidgets(
    'Two-tap map pick flow (#213): tapping the map a second time before '
    "the first pick's fetch has resolved shows the SECOND (newest) pick's "
    "data once both resolve, with the first pick's slower, late-arriving "
    'result discarded rather than overwriting it — real tap gestures, no '
    'real network (fake repositories/clients throughout)',
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

      final weatherRepository = _SequentialWeatherRepository();
      final marineRepository = _SequentialMarineRepository();
      final weatherProvider = WeatherProvider(weatherRepository);
      final marineProvider = MarineProvider(marineRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            nearbyBeachesProvider: nearbyBeachesProvider,
          ),
        ),
      );
      await tester.pump();

      // Initial load, for the Çeşme first-run default.
      expect(weatherRepository.calls, hasLength(1));
      weatherRepository.calls[0].complete(
        WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
      );
      await tester.pumpAndSettle();
      expect(find.text('27°'), findsOneWidget);

      // Seeds an initial MarineProvider load too, at the screen's own
      // Çeşme-default coordinates — MarineProvider is never auto-fetched
      // on init (only an explicit refresh/pick triggers it), so this
      // simulates the "old place" already having real sea data on screen
      // from an earlier pick this session, matching how a returning user
      // would actually see this screen.
      expect(marineRepository.calls, isEmpty);
      final initialMarineFetch = marineProvider.fetchData(38.3220, 26.3260);
      expect(marineRepository.calls, hasLength(1));
      marineRepository.calls[0].complete(SeaCondition(waveHeight: 0.3));
      await initialMarineFetch;
      await tester.pumpAndSettle();
      expect(find.byType(SeaConditionsRow), findsOneWidget);

      // First tap ("tap A"): a real gesture at the map's own center.
      await tester.tap(find.byType(FlutterMap));
      // flutter_map delays a single tap by its double-tap-to-zoom window
      // before firing onTap.
      await tester.pump(const Duration(milliseconds: 300));

      expect(weatherRepository.calls, hasLength(2));
      expect(marineRepository.calls, hasLength(2));
      // Tap A's old values are already gone, replaced by a loading
      // layout, even though tap A's own fetch hasn't resolved yet (#213).
      expect(find.text('27°'), findsNothing);
      expect(find.byType(SeaConditionsRow), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      // The header/map card itself stays on screen (not torn down into
      // the full-screen shell): only the data sections show loading.
      expect(find.byType(FlutterMap), findsOneWidget);

      // Second tap ("tap B"): a real gesture at a different point on the
      // map, while tap A's fetch is still pending — the overlapping-picks
      // scenario. Offset from the FlutterMap's own center (tap A's point)
      // so it lands on a genuinely different spot, well inside the map
      // card's bounds.
      final mapCenter = tester.getCenter(find.byType(FlutterMap));
      await tester.tapAt(mapCenter + const Offset(40, 20));
      await tester.pump(const Duration(milliseconds: 300));

      expect(weatherRepository.calls, hasLength(3));
      expect(marineRepository.calls, hasLength(3));

      // Resolve tap B (the newer pick) first.
      weatherRepository.calls[2].complete(
        WeatherCondition(temperature: 31, windSpeed: 8, weatherCode: 1),
      );
      marineRepository.calls[2].complete(SeaCondition(waveHeight: 1.8));
      await tester.pumpAndSettle();

      expect(find.text('31°'), findsOneWidget);
      expect(find.byType(SeaConditionsRow), findsOneWidget);

      // Tap A (the older pick) resolving late must be discarded entirely:
      // it must not overwrite tap B's already-displayed data ("last tap
      // wins").
      weatherRepository.calls[1].complete(
        WeatherCondition(temperature: 99, windSpeed: 1, weatherCode: 1),
      );
      marineRepository.calls[1].complete(SeaCondition(waveHeight: 0.1));
      await tester.pumpAndSettle();

      expect(find.text('31°'), findsOneWidget);
      expect(find.text('99°'), findsNothing);
      expect(weatherProvider.currentData!.temperature, 31);
      expect(marineProvider.currentData!.waveHeight, 1.8);
    },
  );

  testWidgets(
    'Search-to-map flow (#214): tapping a beach card in Search returns to '
    'Home with it as the selected location — highlighted on the map, '
    'shown in a compact info row, and used for the next nearby-beaches '
    'fetch',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final client = _FixtureNetworkClient();
      final overpassService = OverpassService(client);
      final marineBatchService = MarineBatchService(client);
      final beachCache = BeachCache(await SharedPreferences.getInstance());
      final provider = NearbyBeachesProvider(
        overpassService,
        beachCache,
        marineBatchService,
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(provider.dispose);

      // Fixture providers keep Home off the real network: with MarineApp's
      // real defaults the fetch never completes/errors out, and HomeScreen
      // never leaves its full-screen loading/error shell (#228) — the
      // "More" button (inside LocationMapCard, which that shell doesn't
      // render) would never even be reachable.
      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
      );
      final marineProvider = await aLoadedMarineProvider(
        SeaCondition(waveHeight: 0.3),
      );

      await tester.pumpWidget(
        MarineApp(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
          marineProvider: marineProvider,
          nearbyBeachesProvider: provider,
        ),
      );
      await tester.pumpAndSettle();
      expect(provider.status, NearbyBeachesStatus.loaded);

      // No compact info row yet — nothing has been picked from Search.
      expect(find.byType(BeachResultCard), findsNothing);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beaches'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.text('Fixture Beach'), findsOneWidget);
      await tester.tap(find.text('Fixture Beach'));
      await tester.pumpAndSettle();

      // Back on Home.
      expect(find.byType(SearchScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);

      // Highlighted on the map: `LocationMapCard` is handed the exact
      // picked `Beach` (its own highlight/camera-fit behavior is covered
      // by location_map_card_test.dart).
      final mapCard = tester.widget<LocationMapCard>(
        find.byType(LocationMapCard),
      );
      expect(mapCard.selectedBeach?.name, 'Fixture Beach');

      // Shown in a compact info row below the map, without another tap,
      // reusing BeachResultCard's own fields/formatting.
      expect(find.byType(BeachResultCard), findsOneWidget);
      final infoCard = tester.widget<BeachResultCard>(
        find.byType(BeachResultCard),
      );
      expect(infoCard.placeName, 'Fixture Beach');
      expect(infoCard.fee, BeachFee.free);
      expect(infoCard.waveHeightMeters, closeTo(0.7, 0.001));
      expect(infoCard.waterTemperatureCelsius, closeTo(24.5, 0.001));
      expect(infoCard.hasParking, isTrue);

      // The pick also re-fetches nearby beaches for the beach's own
      // location — same behavior as any other location pick (#157).
      expect(provider.status, NearbyBeachesStatus.loaded);
      expect(provider.beaches, isNotEmpty);
    },
  );

  testWidgets(
    'Water-depth flow (#217): picking up a beach fetches its nearshore '
    'depth profile from a faked BathymetryService, the Home water-depth '
    'tile shows the classified value/status, tapping it opens '
    'DepthDetailScreen, and the back button returns to Home',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final nearbyClient = _FixtureNetworkClient();
      final overpassService = OverpassService(nearbyClient);
      final marineBatchService = MarineBatchService(nearbyClient);
      final beachCache = BeachCache(await SharedPreferences.getInstance());
      final nearbyBeachesProvider = NearbyBeachesProvider(
        overpassService,
        beachCache,
        marineBatchService,
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(nearbyBeachesProvider.dispose);

      final weatherProvider = await aLoadedWeatherProvider(
        WeatherCondition(temperature: 27, windSpeed: 12, weatherCode: 1),
      );
      final marineProvider = await aLoadedMarineProvider(
        SeaCondition(waveHeight: 0.3),
      );

      // A fake transport for BathymetryService's WMS GetFeatureInfo calls
      // (never the real EMODnet network): every transect point comes back
      // at a steady 1.0 m depth, which stays shallow (<= shallowLimitMeters,
      // 1.2 m) the whole way out -> a "gentle" classification.
      final bathymetryClient = FakeHttpClient()
        ..queueJson(
          host: 'ows.emodnet-bathymetry.eu',
          json: {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {'Depth': -1.0},
              },
            ],
          },
        );
      final depthProvider = DepthProvider(
        BathymetryService(bathymetryClient),
        DepthCache(await SharedPreferences.getInstance()),
      );

      await tester.pumpWidget(
        MarineApp(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
          marineProvider: marineProvider,
          nearbyBeachesProvider: nearbyBeachesProvider,
          depthProvider: depthProvider,
        ),
      );
      await tester.pumpAndSettle();
      expect(nearbyBeachesProvider.status, NearbyBeachesStatus.loaded);

      // The water-depth tile's own fetch is triggered post-frame once the
      // nearest fetched beach (resolved just above) is known; this extra
      // settle gives that chained fetch a chance to complete too.
      await tester.pumpAndSettle();

      expect(find.byType(DepthDetailScreen), findsNothing);
      await tester.ensureVisible(find.text('Water depth'));
      await tester.pumpAndSettle();

      // depth = 1.0 m everywhere on the transect: at the 100 m reference
      // distance that's <= gentleMaxDepthAtReferenceDistanceMeters (1.5 m)
      // -> Gentle, and it never exceeds shallowLimitMeters (1.2 m)
      // anywhere, so the tile reads "beyond" the last transect distance.
      expect(find.text('<= 1.2 m beyond 400 m'), findsOneWidget);
      expect(find.text('Gentle'), findsOneWidget);

      await tester.tap(find.text('Water depth'));
      await tester.pumpAndSettle();

      expect(find.byType(DepthDetailScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      // The detail screen's own hero value/chip agree with Home's tile.
      expect(find.text('<= 1.2 m beyond 400 m'), findsOneWidget);
      expect(find.text('Gentle'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(DepthDetailScreen), findsNothing);
    },
  );
}
