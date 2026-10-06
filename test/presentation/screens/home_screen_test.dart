import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/logic/providers/unit_preferences_provider.dart';
import 'package:beachiq/logic/rain_status.dart';
import 'package:beachiq/logic/shallow_entry.dart';
import 'package:beachiq/logic/shallow_entry_status.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/logic/uv_band.dart';
import 'package:beachiq/logic/wind_status.dart';
import 'package:beachiq/presentation/screens/detail/depth_detail_screen.dart';
import 'package:beachiq/presentation/screens/home_screen.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/cloud_backdrop.dart';
import 'package:beachiq/presentation/widgets/forecast_alert_list.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
import 'package:beachiq/presentation/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_http_client.dart';
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
}
