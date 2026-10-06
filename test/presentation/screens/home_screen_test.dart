import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/presentation/screens/home_screen.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/cloud_backdrop.dart';
import 'package:beachiq/presentation/widgets/forecast_alert_list.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
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
}
