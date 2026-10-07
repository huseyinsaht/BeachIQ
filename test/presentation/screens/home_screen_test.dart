import 'dart:async';

import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/data/services/device_location_service.dart';
import 'package:beachiq/data/services/reverse_geocode_cache.dart';
import 'package:beachiq/data/services/reverse_geocoding_service.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/logic/providers/unit_preferences_provider.dart';
import 'package:beachiq/logic/providers/weather_provider.dart';
import 'package:beachiq/logic/rain_status.dart';
import 'package:beachiq/logic/shallow_entry.dart';
import 'package:beachiq/logic/shallow_entry_status.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/logic/uv_band.dart';
import 'package:beachiq/logic/wind_status.dart';
import 'package:beachiq/presentation/screens/detail/current_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/depth_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/water_temperature_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/wave_height_detail_screen.dart';
import 'package:beachiq/presentation/screens/home_screen.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/cloud_backdrop.dart';
import 'package:beachiq/presentation/widgets/forecast_alert_list.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
import 'package:beachiq/presentation/widgets/stat_tile.dart';
import 'package:beachiq/presentation/widgets/stat_tile_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_http_client.dart';
import '../../helpers/fake_location.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('HomeScreen cloud backdrop (issue #162)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders a CloudBackdrop behind the header', (tester) async {
      await pumpApp(tester, const HomeScreen());

      expect(find.byType(CloudBackdrop), findsOneWidget);
    });

    testWidgets('the CloudBackdrop is wrapped in IgnorePointer', (
      tester,
    ) async {
      await pumpApp(tester, const HomeScreen());

      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(CloudBackdrop),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets(
      'given the backdrop stacked over the screen, opening Search via the '
      'map card overflow still works (hit-testing is not blocked anywhere '
      'on the screen)',
      (tester) async {
        await pumpApp(tester, const HomeScreen());
        expect(find.byType(CloudBackdrop), findsOneWidget);

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beaches'));
        await tester.pumpAndSettle();

        expect(find.byType(SearchScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets(
      'the backdrop is positioned top-right, behind (before, in paint '
      'order) the screen content in the Stack',
      (tester) async {
        await pumpApp(tester, const HomeScreen());

        final positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byType(CloudBackdrop),
            matching: find.byType(Positioned),
          ),
        );
        expect(positioned.top, 0);
        expect(positioned.right, 0);

        final stack = tester.widget<Stack>(
          find.ancestor(
            of: find.byType(CloudBackdrop),
            matching: find.byType(Stack),
          ),
        );
        final backdropIndex = stack.children.indexWhere(
          (child) => child is Positioned,
        );
        // SafeArea (the real content) must come after the backdrop in the
        // Stack's children so it paints on top, keeping the backdrop purely
        // decorative and underneath everything interactive.
        final safeAreaIndex = stack.children.indexWhere(
          (child) => child is SafeArea,
        );
        expect(backdropIndex, greaterThanOrEqualTo(0));
        expect(safeAreaIndex, greaterThan(backdropIndex));
      },
    );
  });

  group('HomeScreen forecast alerts (issue #169)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    final now = DateTime(2026, 1, 1, 8, 30);
    DateTime h(int hour) => DateTime(2026, 1, 1, hour);

    testWidgets(
      'given no upcoming wind/wave/rain/current transitions, build -> does '
      'not render ForecastAlertList at all (no widget, no gap)',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(9), windSpeed: 10, rainChancePercent: 5),
              aWeatherHourly(time: h(10), windSpeed: 10, rainChancePercent: 5),
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => now),
        );

        expect(find.byType(ForecastAlertList), findsNothing);
      },
    );

    testWidgets(
      'given a wind reading that crosses the high threshold, build -> '
      'shows a ForecastAlertList row with its icon, message and time '
      'window',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(9), windSpeed: 10),
              aWeatherHourly(time: h(10), windSpeed: 45), // crosses 40 km/h
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => now),
        );

        expect(find.byType(ForecastAlertList), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ForecastAlertList),
            matching: find.byIcon(Icons.air),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Wind crosses 40 km/h'), findsOneWidget);
        expect(find.text('09:00 - 10:00'), findsOneWidget);
      },
    );

    testWidgets(
      'given both a high-severity wind crossing and a later moderate rain '
      'crossing, build -> lists the high-severity alert before the '
      'moderate one',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(9), windSpeed: 10, rainChancePercent: 10),
              aWeatherHourly(
                time: h(10),
                windSpeed: 45, // crosses the high (40) threshold
                rainChancePercent: 10,
              ),
              aWeatherHourly(time: h(11), windSpeed: 45, rainChancePercent: 10),
              aWeatherHourly(
                time: h(12),
                windSpeed: 45,
                rainChancePercent: 50, // crosses the moderate (40) threshold
              ),
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => now),
        );

        expect(find.byType(ForecastAlertList), findsOneWidget);

        final messages = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where((data) => data != null)
            .toList();
        final windIndex = messages.indexWhere(
          (m) => m!.contains('Wind crosses 40 km/h'),
        );
        final rainIndex = messages.indexWhere(
          (m) => m!.contains('Rain chance crosses 40%'),
        );
        expect(windIndex, greaterThanOrEqualTo(0));
        expect(rainIndex, greaterThanOrEqualTo(0));
        expect(
          windIndex,
          lessThan(rainIndex),
          reason:
              'the high-severity wind alert must render before the '
              'moderate-severity rain alert',
        );
      },
    );

    testWidgets(
      'given marine data with a wave crossing, build -> includes the wave '
      'alert alongside the weather-driven ones',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(hourly: [aWeatherHourly(time: h(9))]),
        );
        final marineProvider = await aLoadedMarineProvider(
          aSeaCondition(
            hourly: [
              aSeaHourly(time: h(9), waveHeight: 0.4),
              aSeaHourly(time: h(10), waveHeight: 1.3), // crosses 1.2m
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            now: () => now,
          ),
        );

        expect(find.byType(ForecastAlertList), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ForecastAlertList),
            matching: find.byIcon(Icons.waves),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Waves cross'), findsOneWidget);
      },
    );
  });

  group('HomeScreen stat grid status words (issue #215)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'given a UV index reading, the UV tile shows its band word in the '
      "exact color uv_band.dart's uvBandColor returns for that band",
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(uvIndex: 9),
        );

        await pumpApp(tester, HomeScreen(weatherProvider: weatherProvider));

        // UV index 9 falls in the "very high" band (8-10.9).
        final statusText = tester.widget<Text>(find.text('Very high'));
        expect(statusText.style!.color, uvBandColor(UvBand.veryHigh));
      },
    );

    testWidgets(
      'given a different UV index reading, the UV tile shows a different '
      'band word with a different color',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(uvIndex: 4),
        );

        await pumpApp(tester, HomeScreen(weatherProvider: weatherProvider));

        // UV index 4 falls in the "moderate" band (3-5.9).
        final statusText = tester.widget<Text>(find.text('Moderate'));
        expect(statusText.style!.color, uvBandColor(UvBand.moderate));
      },
    );

    testWidgets(
      'given a strong wind reading, the wind speed tile shows its status '
      'word in the matching color',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(windSpeed: 45),
        );

        await pumpApp(tester, HomeScreen(weatherProvider: weatherProvider));

        final statusText = tester.widget<Text>(find.text('Strong'));
        expect(statusText.style!.color, windStatusColor(WindStatus.strong));
      },
    );

    testWidgets(
      'given a high rain chance reading, the rain chance tile shows its '
      'status word in the matching color',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(rainChancePercent: 80),
        );

        await pumpApp(tester, HomeScreen(weatherProvider: weatherProvider));

        final statusText = tester.widget<Text>(find.text('High'));
        expect(
          statusText.style!.color,
          rainChanceStatusColor(RainChanceStatus.high),
        );
      },
    );

    testWidgets(
      'given no weather data loaded yet, the stat grid renders with no '
      'status chip and no crash',
      (tester) async {
        await pumpApp(tester, const HomeScreen());

        expect(tester.takeException(), isNull);
        expect(find.text('Calm'), findsNothing);
        expect(find.text('Moderate'), findsNothing);
        expect(find.text('Strong'), findsNothing);
        expect(find.text('Low'), findsNothing);
        expect(find.text('Medium'), findsNothing);
        expect(find.text('High'), findsNothing);
      },
    );
  });

  group('Search results: tapping a beach shows it on the Home map (#214)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    /// A client that always answers with a single fixture beach ("Fixture
    /// Beach", 38.40/26.40, free entry, sand, a parking node, a cafe node
    /// and a beach-club node nearby) regardless of the requested point —
    /// sticky by default (see [FakeHttpClient]), so both `HomeScreen`'s
    /// own initial pick (for the Çeşme default) and the later re-fetch
    /// triggered by picking this very beach resolve to it.
    FakeHttpClient fixtureClient() {
      return FakeHttpClient()
        ..queueJson(
          host: 'overpass-api.de',
          json: {
            'elements': [
              {
                'type': 'way',
                'id': 1,
                'tags': {
                  'natural': 'beach',
                  'name': 'Fixture Beach',
                  'addr:city': 'Cesme',
                  'fee': 'no',
                  'surface': 'sand',
                },
                'geometry': [
                  {'lat': 38.40, 'lon': 26.40},
                  {'lat': 38.41, 'lon': 26.40},
                  {'lat': 38.41, 'lon': 26.41},
                ],
              },
              {
                'type': 'node',
                'id': 2,
                'lat': 38.4003,
                'lon': 26.4003,
                'tags': {'amenity': 'parking'},
              },
              {
                'type': 'node',
                'id': 3,
                'lat': 38.4004,
                'lon': 26.4004,
                'tags': {'amenity': 'cafe'},
              },
              {
                'type': 'node',
                'id': 4,
                'lat': 38.4005,
                'lon': 26.4005,
                'tags': {'leisure': 'beach_resort'},
              },
            ],
          },
        )
        ..queueJson(
          host: 'marine-api.open-meteo.com',
          json: [
            {
              'current': {
                'wave_height': 0.5,
                'wave_direction': 200,
                'wave_period': 5,
                'sea_surface_temperature': 24.0,
              },
            },
          ],
        );
    }

    /// Pumps `HomeScreen` with [provider] and lets its initial pick (for
    /// the Çeşme default) resolve, so `SearchScreen`'s "Beaches Near" list
    /// already has the fixture beach to tap by the time a test opens it.
    Future<void> pumpLoadedHome(
      WidgetTester tester,
      NearbyBeachesProvider provider,
    ) async {
      final weatherProvider = await aLoadedWeatherProvider(
        aWeatherCondition(temperature: 27),
      );
      await pumpApp(
        tester,
        HomeScreen(
          nearbyBeachesProvider: provider,
          weatherProvider: weatherProvider,
        ),
      );
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets(
      'tapping a beach in Search returns to Home with it as the selected '
      'location: header name, highlighted on the map, and a compact info '
      'row',
      (tester) async {
        final client = fixtureClient();
        final provider = await fakeNearbyBeachesProvider(client: client);
        addTearDown(provider.dispose);
        await pumpLoadedHome(tester, provider);

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beaches'));
        await tester.pumpAndSettle();

        expect(find.byType(SearchScreen), findsOneWidget);
        expect(find.text('Fixture Beach'), findsOneWidget);
        await tester.tap(find.text('Fixture Beach'));
        await tester.pumpAndSettle();

        // Back on Home — no longer inside SearchScreen.
        expect(find.byType(SearchScreen), findsNothing);

        // The header subtitle, the map card's own docked location bar and
        // the compact info row below the map (all reading the same
        // selected beach's name) account for all three occurrences.
        expect(find.text('Fixture Beach'), findsNWidgets(3));

        // LocationMapCard is handed the picked Beach so it can highlight
        // and fit/center on it (#214's own camera behavior is covered by
        // location_map_card_test.dart; here only the wiring matters).
        final mapCard = tester.widget<LocationMapCard>(
          find.byType(LocationMapCard),
        );
        expect(mapCard.selectedBeach?.name, 'Fixture Beach');

        // The compact info row reuses BeachResultCard with the same
        // fields a search result shows.
        expect(find.byType(BeachResultCard), findsOneWidget);
        expect(find.text('Free'), findsOneWidget);
        expect(find.text('Yes'), findsNWidgets(3)); // parking, beach club, cafe

        // Marine fields specifically: `_handleBeachPicked` also re-fetches
        // nearby beaches for the picked beach's own location (asserted
        // below), which replaces `nearbyBeachesProvider.beaches` with
        // fresh `Beach` instances — so these must come from the live
        // instance, not the (now stale) one `SearchScreen` handed back, or
        // they regress to "No data" once that re-fetch resolves.
        expect(find.text('0.5 m'), findsOneWidget);
        expect(find.text('24°'), findsOneWidget);
      },
    );

    testWidgets(
      'picking a beach re-fetches nearby beaches for its own coordinates, '
      'not just the previous location',
      (tester) async {
        final client = fixtureClient();
        final provider = await fakeNearbyBeachesProvider(client: client);
        addTearDown(provider.dispose);
        await pumpLoadedHome(tester, provider);

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beaches'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fixture Beach'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));

        final overpassRequests = client.requests
            .map((r) => r as http.Request)
            .where((r) => r.url.host == 'overpass-api.de')
            .toList();
        expect(overpassRequests.length, greaterThanOrEqualTo(2));
        expect(overpassRequests.last.body, contains('38.4'));
        expect(overpassRequests.last.body, contains('26.4'));
      },
    );

    testWidgets('going back from Search without tapping a beach leaves Home '
        'untouched (no compact info row)', (tester) async {
      final client = fixtureClient();
      final provider = await fakeNearbyBeachesProvider(client: client);
      addTearDown(provider.dispose);
      await pumpLoadedHome(tester, provider);

      expect(find.byType(BeachResultCard), findsNothing);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beaches'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsNothing);
      expect(find.byType(BeachResultCard), findsNothing);
    });
  });

  group('HomeScreen water depth tile (issue #217)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    const gentleProfile = DepthProfile(
      available: true,
      samples: [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: 1.0),
        DepthSample(distanceMeters: 200, depthMeters: 1.5),
      ],
    );

    testWidgets('shows a water-depth tile where pressure used to be, and no '
        'pressure tile at all', (tester) async {
      await pumpApp(tester, const HomeScreen());

      expect(find.text('Water depth'), findsOneWidget);
      expect(find.text('Pressure'), findsNothing);
    });

    testWidgets(
      'given no DepthProvider, the water-depth tile shows "No data" and '
      'does not crash',
      (tester) async {
        await pumpApp(tester, const HomeScreen());

        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Water depth'));
        await tester.pumpAndSettle();

        final depthTile = find.ancestor(
          of: find.text('Water depth'),
          matching: find.byType(StatTile),
        );
        expect(
          find.descendant(of: depthTile, matching: find.text('No data')),
          findsOneWidget,
        );
      },
    );

    testWidgets('given a loaded DepthProvider with a gentle profile, shows the '
        'formatted value and the Gentle status word in its matching color', (
      tester,
    ) async {
      final depthProvider = await aLoadedDepthProvider(gentleProfile);

      await pumpApp(tester, HomeScreen(depthProvider: depthProvider));
      await tester.ensureVisible(find.text('Water depth'));
      await tester.pumpAndSettle();

      expect(find.text('<= 1.2 m for 200 m'), findsOneWidget);
      final statusText = tester.widget<Text>(find.text('Gentle'));
      expect(
        statusText.style!.color,
        shallowEntryStatusColor(ShallowEntrySteepness.gentle),
      );
    });

    testWidgets(
      'given an imperial unit preference, the water-depth tile value is '
      'formatted in feet',
      (tester) async {
        final depthProvider = await aLoadedDepthProvider(gentleProfile);
        final unitPreferencesProvider = UnitPreferencesProvider(
          await SharedPreferences.getInstance(),
        );
        await unitPreferencesProvider.setUnitSystem(UnitSystem.imperial);

        await pumpApp(
          tester,
          HomeScreen(
            depthProvider: depthProvider,
            unitPreferencesProvider: unitPreferencesProvider,
          ),
        );
        await tester.ensureVisible(find.text('Water depth'));
        await tester.pumpAndSettle();

        expect(find.text('<= 3.9 ft for 656 ft'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the water-depth tile opens DepthDetailScreen, and the back '
      'button returns to Home',
      (tester) async {
        final depthProvider = await aLoadedDepthProvider(gentleProfile);

        await pumpApp(tester, HomeScreen(depthProvider: depthProvider));
        await tester.ensureVisible(find.text('Water depth'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Water depth'));
        await tester.pumpAndSettle();

        expect(find.byType(DepthDetailScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        expect(find.byType(DepthDetailScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'the water-depth tile does not overflow at a narrow (360dp) width '
      'with a large text scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final depthProvider = await aLoadedDepthProvider(gentleProfile);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: HomeScreen(depthProvider: depthProvider),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('HomeScreen forecast alerts daylight filter and next-hour note '
      '(issue #229)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    DateTime h(int hour, [int day = 1]) => DateTime(2026, 1, day, hour);

    testWidgets(
      'given a wind crossing entirely outside the location\'s daylight '
      'window, build -> does not render it as a daylight alert',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              // 23:00 -> 00:00 next day: outside both days' 06:00-20:00
              // daylight windows below, and not adjacent to `now` (8:30)
              // either, so it also can't surface as a next-hour note.
              aWeatherHourly(time: h(23), windSpeed: 10),
              aWeatherHourly(time: h(0, 2), windSpeed: 45),
            ],
            daylightWindows: [
              aDaylightWindow(sunrise: h(6), sunset: h(20)),
              aDaylightWindow(sunrise: h(6, 2), sunset: h(20, 2)),
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            now: () => DateTime(2026, 1, 1, 8, 30),
          ),
        );

        expect(find.byType(ForecastAlertList), findsNothing);
      },
    );

    testWidgets(
      'given a daytime wind crossing inside the daylight window, build -> '
      'still renders it as a daylight alert',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(9), windSpeed: 10),
              aWeatherHourly(time: h(10), windSpeed: 45),
            ],
            daylightWindows: [aDaylightWindow(sunrise: h(6), sunset: h(20))],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            now: () => DateTime(2026, 1, 1, 8, 30),
          ),
        );

        expect(find.byType(ForecastAlertList), findsOneWidget);
        expect(find.textContaining('Wind crosses 40 km/h'), findsOneWidget);
      },
    );

    testWidgets(
      'given a change in the next hour after the location\'s sunset, build '
      '-> still shows the next-hour note even though the daylight alert '
      'list is filtered out',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(21), windSpeed: 10),
              aWeatherHourly(time: h(22), windSpeed: 45),
            ],
            daylightWindows: [aDaylightWindow(sunrise: h(6), sunset: h(20))],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => h(21)),
        );

        expect(find.byType(ForecastAlertList), findsOneWidget);
        expect(find.text('Next hour'), findsOneWidget);
        expect(find.textContaining('Wind crosses 40 km/h'), findsOneWidget);
      },
    );
  });

  group('HomeScreen 3x3 stat grid (issue #251)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    const gentleProfile = DepthProfile(
      available: true,
      samples: [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: 1.0),
        DepthSample(distanceMeters: 200, depthMeters: 1.5),
      ],
    );

    Future<HomeScreen> loadedHome(WidgetTester tester) async {
      final weatherProvider = await aLoadedWeatherProvider(
        aWeatherCondition(windSpeed: 10, rainChancePercent: 20, uvIndex: 2),
      );
      final marineProvider = await aLoadedMarineProvider(
        aSeaCondition(
          waveHeight: 0.9,
          seaSurfaceTemperature: 24.0,
          waveDirection: 315,
          currentVelocity: 4.0,
          currentDirection: 135,
        ),
      );
      final depthProvider = await aLoadedDepthProvider(gentleProfile);
      return HomeScreen(
        weatherProvider: weatherProvider,
        marineProvider: marineProvider,
        depthProvider: depthProvider,
      );
    }

    testWidgets('given loaded weather, marine and depth data, build -> renders '
        'exactly 3 groups (Sea, Current, Air, in that order) of exactly 3 '
        'StatTiles each — 9 same-size tiles in a 3x3 grid', (tester) async {
      await pumpApp(tester, await loadedHome(tester));

      final groups = tester
          .widgetList<StatTileGroup>(find.byType(StatTileGroup))
          .toList();
      expect(groups, hasLength(3));
      expect(groups.map((g) => g.label), ['Sea', 'Current', 'Air']);
      expect(find.byType(StatTile), findsNWidgets(9));

      expect(groups[0].tiles.map((t) => t.label), [
        'Wave height',
        'Water temp',
        'Water depth',
      ]);
      expect(groups[1].tiles.map((t) => t.label), [
        'Current speed',
        'Current direction',
        'Wave direction',
      ]);
      expect(groups[2].tiles.map((t) => t.label), [
        'Wind speed',
        'Rain chance',
        'UV index',
      ]);
    });

    testWidgets('renders a thin divider between each of the three groups (two '
        'dividers total)', (tester) async {
      await pumpApp(tester, await loadedHome(tester));

      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('given full data, the 3x3 grid shows no trend row (no up/down '
        'arrow) on any of the nine tiles — only the detail screens keep one', (
      tester,
    ) async {
      await pumpApp(tester, await loadedHome(tester));

      expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets(
      'wave direction has no status/third line at all (a metric with no '
      'defined status), unlike current direction',
      (tester) async {
        await pumpApp(tester, await loadedHome(tester));

        final waveDirectionTile = tester.widget<StatTile>(
          find.widgetWithText(StatTile, 'Wave direction'),
        );
        expect(waveDirectionTile.statusLabel, isNull);
        expect(waveDirectionTile.statusColor, isNull);
        expect(find.text('from NW'), findsOneWidget);
      },
    );

    testWidgets('given no seawardBearingDegrees (no beach geometry for this '
        'location), the current-direction tile shows the cardinal label only '
        '— never an invented shore relation', (tester) async {
      await pumpApp(tester, await loadedHome(tester));

      final currentDirectionTile = tester.widget<StatTile>(
        find.widgetWithText(StatTile, 'Current direction'),
      );
      expect(currentDirectionTile.statusLabel, isNull);
      expect(find.text('toward SE'), findsOneWidget);
    });

    testWidgets(
      'tapping the wave height tile opens WaveHeightDetailScreen with the '
      'real marine data, and back returns to Home',
      (tester) async {
        await pumpApp(tester, await loadedHome(tester));

        await tester.tap(find.byKey(const Key('wave-height-tile')));
        await tester.pumpAndSettle();

        expect(find.byType(WaveHeightDetailScreen), findsOneWidget);
        final screen = tester.widget<WaveHeightDetailScreen>(
          find.byType(WaveHeightDetailScreen),
        );
        expect(screen.currentWaveHeightMeters, 0.9);

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets('tapping the water temperature tile opens '
        'WaterTemperatureDetailScreen with the real marine data', (
      tester,
    ) async {
      await pumpApp(tester, await loadedHome(tester));

      await tester.tap(find.byKey(const Key('water-temperature-tile')));
      await tester.pumpAndSettle();

      expect(find.byType(WaterTemperatureDetailScreen), findsOneWidget);
      final screen = tester.widget<WaterTemperatureDetailScreen>(
        find.byType(WaterTemperatureDetailScreen),
      );
      expect(screen.currentWaterTemperatureCelsius, 24.0);
    });

    testWidgets(
      'tapping the current speed tile and the current direction tile both '
      'open the same CurrentDetailScreen',
      (tester) async {
        await pumpApp(tester, await loadedHome(tester));

        await tester.tap(find.byKey(const Key('current-speed-tile')));
        await tester.pumpAndSettle();
        expect(find.byType(CurrentDetailScreen), findsOneWidget);
        var screen = tester.widget<CurrentDetailScreen>(
          find.byType(CurrentDetailScreen),
        );
        expect(screen.currentSpeedKmh, 4.0);

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('current-direction-tile')));
        await tester.pumpAndSettle();
        expect(find.byType(CurrentDetailScreen), findsOneWidget);
        screen = tester.widget<CurrentDetailScreen>(
          find.byType(CurrentDetailScreen),
        );
        expect(screen.currentDirectionDegrees, 135);
      },
    );

    testWidgets(
      'given a marine fetch that fails for a newly picked location (after '
      'an earlier successful load), the error is shown visibly, but the '
      'independent Water depth and Air tiles keep rendering their own '
      'real data (issue #213/#228)',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(windSpeed: 10),
        );
        final depthProvider = await aLoadedDepthProvider(gentleProfile);
        final marineProvider = MarineProvider(_ThenFailingMarineRepository());

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            depthProvider: depthProvider,
          ),
        );
        // First (successful) load, so `_hasLoadedOnce` is already true —
        // a later pick's failure must then show inline, never fall back
        // to the full-screen error shell reserved for the very first load.
        await marineProvider.fetchData(38.3, 26.3);
        await tester.pump();
        unawaited(marineProvider.fetchData(50, 50));
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Water depth'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Unable to load marine data'),
          findsOneWidget,
        );
        expect(find.textContaining('boom'), findsOneWidget);
        // Water depth (not marine-driven) and the wind speed tile (Air
        // group, also not marine-driven) still show their own real data
        // next to the error, rather than being hidden along with it.
        expect(find.text('<= 1.2 m for 200 m'), findsOneWidget);
        expect(find.text('10 km/h'), findsOneWidget);
        // The marine-driven tiles fall back to "No data", never a
        // fabricated reading.
        expect(find.widgetWithText(StatTile, 'Wave height'), findsOneWidget);
        final waveHeightTile = tester.widget<StatTile>(
          find.widgetWithText(StatTile, 'Wave height'),
        );
        expect(waveHeightTile.value, 'No data');
      },
    );

    testWidgets(
      'the full 3x3 grid does not overflow at a narrow (360dp) width with '
      'a large text scale, with sea/current/air data all loaded',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final home = await loadedHome(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: home,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('HomeScreen header shows the place name, never "My Location" '
      '(issue #253)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'given the Çeşme first-run default (nothing picked yet), build -> '
      'the header title is the real place name, "My Location" never '
      'appears, and the coordinates show as a secondary line underneath '
      '(the name is a real name, not the coordinates themselves)',
      (tester) async {
        await pumpApp(tester, const HomeScreen());

        expect(find.text('My Location'), findsNothing);
        expect(find.text('Çeşme, İzmir'), findsAtLeastNWidgets(1));
        expect(find.text('38.3220°N, 26.3260°E'), findsOneWidget);
      },
    );

    testWidgets('given a beach picked from Search results, the header title '
        'becomes the beach name — never "My Location" — with its own '
        'coordinates shown underneath', (tester) async {
      final client = FakeHttpClient()
        ..queueJson(
          host: 'overpass-api.de',
          json: {
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
                // Two points straddling (38.40, 26.40) so the mapper's
                // centroid (used as `Beach.latitude`/`.longitude`) lands
                // exactly on it — makes the expected coordinates below
                // exact, while still being 2 distinct points (flutter_map
                // needs a non-zero-area bounds to fit the camera to).
                'geometry': [
                  {'lat': 38.39, 'lon': 26.40},
                  {'lat': 38.41, 'lon': 26.40},
                ],
              },
            ],
          },
        )
        ..queueJson(
          host: 'marine-api.open-meteo.com',
          json: [
            {
              'current': {
                'wave_height': 0.5,
                'wave_direction': 200,
                'wave_period': 5,
                'sea_surface_temperature': 24.0,
              },
            },
          ],
        );
      final provider = await fakeNearbyBeachesProvider(client: client);
      addTearDown(provider.dispose);
      final weatherProvider = await aLoadedWeatherProvider(
        aWeatherCondition(temperature: 27),
      );

      await pumpApp(
        tester,
        HomeScreen(
          nearbyBeachesProvider: provider,
          weatherProvider: weatherProvider,
        ),
      );
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beaches'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixture Beach'));
      await tester.pumpAndSettle();

      expect(find.text('My Location'), findsNothing);
      // The header title, the map card's docked location bar and the
      // compact info row below the map all render the same beach name.
      expect(find.text('Fixture Beach'), findsNWidgets(3));
      expect(find.text('38.4000°N, 26.4000°E'), findsOneWidget);
    });
  });

  group(
    'HomeScreen header temperature matches Open-Meteo\'s current.temperature_2m '
    'for the selected point (issue #253)',
    () {
      setUp(() {
        SharedPreferences.setMockInitialValues({});
      });

      /// Queues a response shaped exactly like a real Open-Meteo `/forecast`
      /// reply (`current.temperature_2m`, the real field this repository/
      /// model parse) for the exact (lat, lon) `WeatherApiService` sends,
      /// so this exercises the real JSON field name end to end rather than
      /// a `FakeWeatherRepository` handing back an already-built
      /// `WeatherCondition`.
      void queueTemperature(
        FakeHttpClient client,
        double lat,
        double lon,
        double temperatureCelsius,
      ) {
        client.queueJson(
          matcher: (request) =>
              request.url.host == 'api.open-meteo.com' &&
              request.url.queryParameters['latitude'] == lat.toString() &&
              request.url.queryParameters['longitude'] == lon.toString(),
          json: {
            'current': {
              'temperature_2m': temperatureCelsius,
              'wind_speed_10m': 5.0,
              'weather_code': 0,
            },
          },
        );
      }

      testWidgets('given three different points at different times of day (two '
          'daytime fixtures, one evening fixture), the header shows each '
          "point's own real current.temperature_2m after its fetch, never a "
          'previous pick\'s value — ruling out #213\'s stale-value failure '
          'mode for the real Open-Meteo field, not a canned WeatherCondition', (
        tester,
      ) async {
        final client = FakeHttpClient();
        // HomeScreen's initState auto-fetches the Çeşme first-run default
        // on mount; queued so that fetch has somewhere to resolve to
        // before the test's own explicit picks below.
        queueTemperature(client, 38.3220, 26.3260, 21.0);
        final weatherProvider = WeatherProvider(
          WeatherRepository(WeatherApiService()),
        );

        await http.runWithClient(() async {
          await pumpApp(tester, HomeScreen(weatherProvider: weatherProvider));
          expect(find.text('21°'), findsOneWidget);

          // Point A: a daytime fixture at a different location.
          queueTemperature(client, 36.8, 30.7, 31.0);
          await weatherProvider.fetchData(36.8, 30.7);
          await tester.pumpAndSettle();
          expect(find.text('31°'), findsOneWidget);
          expect(find.text('21°'), findsNothing);

          // Point B: an evening fixture at a third, different location —
          // this is the owner's actual complaint (a steady 19-20°C every
          // evening): the real cause is the fixed Çeşme default being
          // shown under a misleading "My Location" label (fixed above),
          // not a bug in this fetch-to-display path, which this proves
          // reflects whatever point/time Open-Meteo itself returns.
          queueTemperature(client, 41.0, 29.0, 19.0);
          await weatherProvider.fetchData(41.0, 29.0);
          await tester.pumpAndSettle();
          expect(find.text('19°'), findsOneWidget);
          expect(find.text('31°'), findsNothing);

          // Point C: back to a daytime fixture at yet another location —
          // proves the previous evening value doesn't linger either.
          queueTemperature(client, 37.9, 27.3, 26.0);
          await weatherProvider.fetchData(37.9, 27.3);
          await tester.pumpAndSettle();
          expect(find.text('26°'), findsOneWidget);
          expect(find.text('19°'), findsNothing);

          // Each fetch really did carry its own point: the 3 explicit
          // picks plus the initial default are 4 distinct requests.
          final forecastRequests = client.requests
              .where((r) => r.url.host == 'api.open-meteo.com')
              .toList();
          expect(forecastRequests, hasLength(4));
          expect(forecastRequests.last.url.queryParameters['latitude'], '37.9');
          expect(
            forecastRequests.last.url.queryParameters['longitude'],
            '27.3',
          );
        }, () => client);
      });

      testWidgets(
        'a newer pick\'s real Open-Meteo fetch resolving before an older, '
        'still-in-flight one shows the NEWER point\'s temperature and is '
        'never overwritten once the older one belatedly resolves (#213)',
        (tester) async {
          final client = FakeHttpClient();
          queueTemperature(client, 38.3220, 26.3260, 21.0);
          final weatherProvider = WeatherProvider(
            WeatherRepository(WeatherApiService()),
          );

          await http.runWithClient(() async {
            await pumpApp(tester, HomeScreen(weatherProvider: weatherProvider));
            expect(find.text('21°'), findsOneWidget);

            // The OLDER request is queued with a delay so it resolves only
            // after the newer one below, simulating two overlapping picks
            // completing out of order.
            client.queueResponse(
              matcher: (request) =>
                  request.url.host == 'api.open-meteo.com' &&
                  request.url.queryParameters['latitude'] == '10.0' &&
                  request.url.queryParameters['longitude'] == '10.0',
              body:
                  '{"current": {"temperature_2m": 99.0, '
                  '"wind_speed_10m": 1.0, "weather_code": 0}}',
              headers: const {'content-type': 'application/json'},
              delay: const Duration(milliseconds: 50),
            );
            final olderFetch = weatherProvider.fetchData(10.0, 10.0);

            queueTemperature(client, 20.0, 20.0, 31.0);
            final newerFetch = weatherProvider.fetchData(20.0, 20.0);

            await newerFetch;
            await tester.pumpAndSettle();
            expect(find.text('31°'), findsOneWidget);

            // The older request finally resolves, but must not overwrite
            // the newer pick's already-displayed real value.
            await olderFetch;
            await tester.pumpAndSettle();
            expect(find.text('31°'), findsOneWidget);
            expect(find.text('99°'), findsNothing);
          }, () => client);
        },
      );
    },
  );

  group('HomeScreen device location and reverse geocoding (issue #254)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    /// A [ReverseGeocodingService] wired to a throwaway [SharedPreferences]
    /// cache (so each test starts with an empty cache) and the given fake
    /// lookup result/error.
    Future<ReverseGeocodingService> aReverseGeocodingService({
      List<Placemark> result = const [],
      Object? error,
    }) async {
      final prefs = await SharedPreferences.getInstance();
      return ReverseGeocodingService(
        FakePlacemarkLookup(result: result, error: error),
        ReverseGeocodeCache(prefs),
      );
    }

    testWidgets(
      'given no deviceLocationService, the map overflow menu has no "Use '
      'my location" entry',
      (tester) async {
        await pumpApp(tester, const HomeScreen());

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();

        expect(find.text('Use my location'), findsNothing);
      },
    );

    testWidgets(
      'given a deviceLocationService and a reverse geocoder that resolves, '
      'tapping "Use my location" selects the device position and shows '
      'its resolved city name in the header',
      (tester) async {
        final deviceLocationService = DeviceLocationService(
          FakeDeviceLocationSource(position: const LatLng(36.8969, 30.7133)),
        );
        final reverseGeocodingService = await aReverseGeocodingService(
          result: const [
            Placemark(locality: 'Antalya', administrativeArea: 'Antalya'),
          ],
        );

        await pumpApp(
          tester,
          HomeScreen(
            tileProvider: FakeTileProvider(),
            deviceLocationService: deviceLocationService,
            reverseGeocodingService: reverseGeocodingService,
          ),
        );

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use my location'));
        await tester.pumpAndSettle();

        expect(find.text('Antalya'), findsAtLeastNWidgets(1));
        expect(find.text('Çeşme, İzmir'), findsNothing);
        expect(find.text('My Location'), findsNothing);
      },
    );

    testWidgets(
      'given location permission is denied (even after being requested), '
      'tapping "Use my location" keeps the previous place and shows a '
      'short, non-blocking message',
      (tester) async {
        final deviceLocationService = DeviceLocationService(
          FakeDeviceLocationSource(
            permission: LocationPermission.denied,
            permissionAfterRequest: LocationPermission.denied,
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(
            tileProvider: FakeTileProvider(),
            deviceLocationService: deviceLocationService,
          ),
        );

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use my location'));
        await tester.pumpAndSettle();

        // Still the Çeşme first-run default — nothing was picked.
        expect(find.text('Çeşme, İzmir'), findsAtLeastNWidgets(1));
        expect(find.textContaining('permission denied'), findsOneWidget);
      },
    );

    testWidgets(
      'given the device\'s location services are off, tapping "Use my '
      'location" keeps the previous place and shows a short, non-blocking '
      'message',
      (tester) async {
        final deviceLocationService = DeviceLocationService(
          FakeDeviceLocationSource(serviceEnabled: false),
        );

        await pumpApp(
          tester,
          HomeScreen(
            tileProvider: FakeTileProvider(),
            deviceLocationService: deviceLocationService,
          ),
        );

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use my location'));
        await tester.pumpAndSettle();

        expect(find.text('Çeşme, İzmir'), findsAtLeastNWidgets(1));
        expect(find.textContaining('turned off'), findsOneWidget);
      },
    );

    testWidgets(
      'given a map tap and a reverse geocoder that resolves, the header '
      'upgrades from formatted coordinates to the real city name',
      (tester) async {
        final reverseGeocodingService = await aReverseGeocodingService(
          result: const [
            Placemark(locality: 'Antalya', administrativeArea: 'Antalya'),
          ],
        );

        await pumpApp(
          tester,
          HomeScreen(
            tileProvider: FakeTileProvider(),
            reverseGeocodingService: reverseGeocodingService,
          ),
        );

        await tester.tap(find.byType(FlutterMap));
        // flutter_map delays a single tap by its double-tap-to-zoom window
        // before firing onTap.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Antalya'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'given a map tap and a reverse geocoder that fails, the header falls '
      'back to formatted coordinates — never a fabricated name',
      (tester) async {
        final reverseGeocodingService = await aReverseGeocodingService(
          error: Exception('IO_ERROR: rate limited'),
        );

        await pumpApp(
          tester,
          HomeScreen(
            tileProvider: FakeTileProvider(),
            reverseGeocodingService: reverseGeocodingService,
          ),
        );

        await tester.tap(find.byType(FlutterMap));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.textContaining('°N'), findsAtLeastNWidgets(1));
        expect(find.text('Çeşme, İzmir'), findsNothing);
      },
    );

    testWidgets(
      'given the same grid cell is picked twice via "Use my location", the '
      'reverse geocoder is looked up only once (cache reuse)',
      (tester) async {
        final lookup = FakePlacemarkLookup(
          result: const [
            Placemark(locality: 'Antalya', administrativeArea: 'Antalya'),
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        final reverseGeocodingService = ReverseGeocodingService(
          lookup,
          ReverseGeocodeCache(prefs),
        );
        final deviceLocationService = DeviceLocationService(
          FakeDeviceLocationSource(position: const LatLng(36.8969, 30.7133)),
        );

        await pumpApp(
          tester,
          HomeScreen(
            tileProvider: FakeTileProvider(),
            deviceLocationService: deviceLocationService,
            reverseGeocodingService: reverseGeocodingService,
          ),
        );

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use my location'));
        await tester.pumpAndSettle();
        expect(lookup.calls, hasLength(1));

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use my location'));
        await tester.pumpAndSettle();

        expect(lookup.calls, hasLength(1));
      },
    );
  });
}

/// A [MarineRepository] whose first call succeeds (seeding "the previous
/// pick already loaded") and every later call fails — used to test a later
/// pick's marine failure without going through the full-screen error shell
/// reserved for the very first load (see `_hasLoadedOnce` in
/// `home_screen.dart`).
class _ThenFailingMarineRepository extends MarineRepository {
  _ThenFailingMarineRepository() : super(MarineApiService());

  int _calls = 0;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    _calls++;
    if (_calls == 1) return SeaCondition(waveHeight: 0.3);
    throw Exception('boom');
  }
}
