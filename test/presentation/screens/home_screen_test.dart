import 'dart:async';

import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/models/weather_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/data/services/device_location_service.dart';
import 'package:beachiq/data/services/geocoding_service.dart';
import 'package:beachiq/data/services/notification_service.dart';
import 'package:beachiq/data/services/reverse_geocode_cache.dart';
import 'package:beachiq/data/services/reverse_geocoding_service.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:beachiq/logic/providers/condition_alert_dispatcher.dart';
import 'package:beachiq/logic/providers/depth_provider.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/logic/providers/place_search_provider.dart';
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
import 'package:beachiq/presentation/screens/forecast_screen.dart';
import 'package:beachiq/presentation/screens/home_screen.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/cloud_backdrop.dart';
import 'package:beachiq/presentation/widgets/daily_outlook_list.dart';
import 'package:beachiq/presentation/widgets/forecast_alert_list.dart';
import 'package:beachiq/presentation/widgets/hourly_forecast_item.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
import 'package:beachiq/presentation/widgets/search_field.dart';
import 'package:beachiq/presentation/widgets/stat_tile.dart';
import 'package:beachiq/presentation/widgets/stat_tile_group.dart';
import 'package:beachiq/presentation/widgets/swim_suggestion_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

/// Issue #284: `HomeScreen`'s draggable bottom sheet starts collapsed (just
/// the place name/temperature/pill/next-hour note/Sea tiles/hint) — a test
/// that needs the sheet's *expanded* content (the Current/Air groups, the
/// hourly row, the forecast entry row (#289), or the selected-beach info
/// row, none of which are even laid out while collapsed) drives
/// [controller] directly instead of simulating a real drag gesture, the
/// same reason `HomeScreen.sheetController` exists.
Future<void> expandSheet(
  WidgetTester tester,
  DraggableScrollableController controller,
) async {
  controller.jumpTo(1.0);
  await tester.pumpAndSettle();
}

/// Issue #289: expands the sheet (the "Forecast and 7-14 day outlook" row
/// only exists once expanded) and taps it, landing on [ForecastScreen].
Future<void> openForecastScreen(
  WidgetTester tester,
  DraggableScrollableController controller,
) async {
  await expandSheet(tester, controller);
  final entryRow = find.byKey(const Key('home-forecast-entry-row'));
  await tester.ensureVisible(entryRow);
  await tester.pumpAndSettle();
  await tester.tap(entryRow);
  await tester.pumpAndSettle();
}

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
      'given a wind reading that crosses the high threshold, build -> does '
      'not render it on Home directly, but the Forecast screen shows a '
      'ForecastAlertList row with its icon, message and time window',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(9), windSpeed: 10),
              aWeatherHourly(time: h(10), windSpeed: 45), // crosses 40 km/h
            ],
          ),
        );
        final sheetController = DraggableScrollableController();

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            now: () => now,
            sheetController: sheetController,
          ),
        );

        // Issue #289: Home itself never shows the per-type alert list.
        expect(find.byType(ForecastAlertList), findsNothing);

        await openForecastScreen(tester, sheetController);

        expect(find.byType(ForecastScreen), findsOneWidget);
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
      'crossing, the Forecast screen lists the high-severity alert before '
      'the moderate one',
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

        final sheetController = DraggableScrollableController();
        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            now: () => now,
            sheetController: sheetController,
          ),
        );
        await openForecastScreen(tester, sheetController);

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
      'given marine data with a wave crossing, the Forecast screen includes '
      'the wave alert alongside the weather-driven ones',
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
        final sheetController = DraggableScrollableController();

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            now: () => now,
            sheetController: sheetController,
          ),
        );
        await openForecastScreen(tester, sheetController);

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

    testWidgets('given a wind crossing more than 24 hours out (issue #273: '
        'forecast_days=14 widened the raw hourly series to up to 14 days), '
        'build -> does not treat it as an upcoming alert', (tester) async {
      final farNow = DateTime(2026, 7, 1, 0, 0);
      // A dense, one-entry-per-hour series (as the real API returns),
      // calm throughout except the last hour -- two days out, well beyond
      // the ~24h cap near-term-only features must apply to the now-wider
      // daily series. A sparse series would defeat the entry-count cap
      // (it only has as many entries as actually provided), so this must
      // mirror real hourly density for the cap to have anything to do.
      final hourly = [
        for (var hour = 1; hour <= 49; hour++)
          aWeatherHourly(
            time: farNow.add(Duration(hours: hour)),
            windSpeed: hour == 49 ? 45 : 10, // crosses 40 km/h, two days out
          ),
      ];
      final weatherProvider = await aLoadedWeatherProvider(
        aWeatherCondition(hourly: hourly),
      );

      await pumpApp(
        tester,
        HomeScreen(weatherProvider: weatherProvider, now: () => farNow),
      );

      expect(find.byType(ForecastAlertList), findsNothing);
    });

    testWidgets(
      'given a wind crossing on the 24th upcoming hour (inside the cap), '
      'the Forecast screen still shows the alert',
      (tester) async {
        final farNow = DateTime(2026, 7, 1, 0, 0);
        final hourly = [
          for (var hour = 1; hour <= 24; hour++)
            aWeatherHourly(
              time: farNow.add(Duration(hours: hour)),
              windSpeed: hour == 24 ? 45 : 10, // crosses 40 km/h at +24h
            ),
        ];
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(hourly: hourly),
        );
        final sheetController = DraggableScrollableController();

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            now: () => farNow,
            sheetController: sheetController,
          ),
        );
        await openForecastScreen(tester, sheetController);

        expect(find.byType(ForecastAlertList), findsOneWidget);
      },
    );

    testWidgets(
      'given a wind crossing on the 25th upcoming hour (just outside the '
      '24-entry cap), build -> does not show the alert',
      (tester) async {
        final farNow = DateTime(2026, 7, 1, 0, 0);
        final hourly = [
          for (var hour = 1; hour <= 25; hour++)
            aWeatherHourly(
              time: farNow.add(Duration(hours: hour)),
              windSpeed: hour == 25 ? 45 : 10, // crosses 40 km/h, at +25h
            ),
        ];
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(hourly: hourly),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => farNow),
        );

        expect(find.byType(ForecastAlertList), findsNothing);
      },
    );

    testWidgets(
      'given a wave crossing more than 24 hours out on the marine series, '
      'build -> does not treat it as an upcoming alert either',
      (tester) async {
        final farNow = DateTime(2026, 7, 1, 0, 0);
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              for (var hour = 1; hour <= 49; hour++)
                aWeatherHourly(time: farNow.add(Duration(hours: hour))),
            ],
          ),
        );
        // Same reasoning as the wind test above: a dense, one-entry-per-
        // hour series, calm throughout except the last (two days out).
        final marineProvider = await aLoadedMarineProvider(
          aSeaCondition(
            hourly: [
              for (var hour = 1; hour <= 49; hour++)
                aSeaHourly(
                  time: farNow.add(Duration(hours: hour)),
                  waveHeight: hour == 49 ? 1.3 : 0.4, // crosses 1.2m
                ),
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            now: () => farNow,
          ),
        );

        expect(find.byType(ForecastAlertList), findsNothing);
      },
    );

    testWidgets(
      'given several upcoming alerts and no next-hour note, build -> Home '
      'shows no note and no alert list at all (issue #289: never falls '
      'back to the most-severe alert)',
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

        expect(find.text('Next hour'), findsNothing);
        expect(find.byType(ForecastAlertList), findsNothing);
      },
    );
  });

  group('HomeScreen 7-14 day outlook (issue #273)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'given weather and marine providers with daily data, tapping the '
      'forecast entry row opens the Forecast screen with the outlook',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            dailyForecast: [
              aDailyWeatherForecast(
                date: DateTime(2026, 7, 1),
                highTemperature: 28.0,
                lowTemperature: 20.0,
              ),
              aDailyWeatherForecast(
                date: DateTime(2026, 7, 2),
                highTemperature: 29.0,
                lowTemperature: 21.0,
              ),
            ],
          ),
        );
        final marineProvider = await aLoadedMarineProvider(
          aSeaCondition(
            dailyForecast: [
              aSeaDailyForecast(date: DateTime(2026, 7, 1), waveHeightMax: 0.3),
              aSeaDailyForecast(date: DateTime(2026, 7, 2), waveHeightMax: 0.4),
            ],
          ),
        );

        final sheetController = DraggableScrollableController();
        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            now: () => DateTime(2026, 7, 1),
            sheetController: sheetController,
          ),
        );
        // Issue #289: the outlook no longer renders on Home at all — only
        // the entry row, reachable once the sheet is expanded.
        expect(find.byType(DailyOutlookList), findsNothing);

        await openForecastScreen(tester, sheetController);

        expect(find.byType(ForecastScreen), findsOneWidget);
        expect(find.text('7-14 DAY OUTLOOK'), findsOneWidget);
        expect(find.byKey(const Key('daily-outlook-list')), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
      },
    );

    testWidgets(
      'given no daily data and no alerts on either provider, still shows '
      'the forecast entry row — the Forecast screen handles its own empty '
      'states, so the row is not data-dependent',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(),
        );
        final sheetController = DraggableScrollableController();

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            sheetController: sheetController,
          ),
        );
        await expandSheet(tester, sheetController);

        final entryRow = find.byKey(const Key('home-forecast-entry-row'));
        expect(entryRow, findsOneWidget);
        expect(find.byType(DailyOutlookList), findsNothing);

        await tester.ensureVisible(entryRow);
        await tester.pumpAndSettle();
        await tester.tap(entryRow);
        await tester.pumpAndSettle();

        expect(find.byType(ForecastScreen), findsOneWidget);
        expect(find.text('No alerts'), findsOneWidget);
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
        final sheetController = DraggableScrollableController();

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            sheetController: sheetController,
          ),
        );
        // Issue #284: the UV tile (Air group) only exists once expanded.
        await expandSheet(tester, sheetController);

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
        final sheetController = DraggableScrollableController();

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            sheetController: sheetController,
          ),
        );
        await expandSheet(tester, sheetController);

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
        final sheetController = DraggableScrollableController();

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            sheetController: sheetController,
          ),
        );
        await expandSheet(tester, sheetController);

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
        final sheetController = DraggableScrollableController();

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            sheetController: sheetController,
          ),
        );
        await expandSheet(tester, sheetController);

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
      NearbyBeachesProvider provider, {
      DraggableScrollableController? sheetController,
      DepthProvider? depthProvider,
    }) async {
      final weatherProvider = await aLoadedWeatherProvider(
        aWeatherCondition(temperature: 27),
      );
      await pumpApp(
        tester,
        HomeScreen(
          nearbyBeachesProvider: provider,
          weatherProvider: weatherProvider,
          sheetController: sheetController,
          depthProvider: depthProvider,
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
        final sheetController = DraggableScrollableController();
        await pumpLoadedHome(
          tester,
          provider,
          sheetController: sheetController,
        );

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

        // Issue #284: the compact info row (BeachResultCard) only exists
        // once the sheet is expanded — there's no docked map-card location
        // bar left to show a third, pre-#284 occurrence of the name.
        await expandSheet(tester, sheetController);
        expect(find.text('Fixture Beach'), findsNWidgets(2));

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

    group('selected-beach depth summary (issue #257)', () {
      const gentleProfile = DepthProfile(
        available: true,
        samples: [
          DepthSample(distanceMeters: 0, depthMeters: 0.3),
          DepthSample(distanceMeters: 100, depthMeters: 1.0),
          DepthSample(distanceMeters: 200, depthMeters: 1.5),
        ],
      );

      Future<void> pickFixtureBeach(
        WidgetTester tester,
        DraggableScrollableController sheetController, {
        DepthProvider? depthProvider,
      }) async {
        final client = fixtureClient();
        final provider = await fakeNearbyBeachesProvider(client: client);
        addTearDown(provider.dispose);
        await pumpLoadedHome(
          tester,
          provider,
          sheetController: sheetController,
          depthProvider: depthProvider,
        );

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beaches'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fixture Beach'));
        await tester.pumpAndSettle();
        await expandSheet(tester, sheetController);
      }

      testWidgets(
        'no DepthProvider: the card shows "Depth: no data", never a crash',
        (tester) async {
          final sheetController = DraggableScrollableController();
          await pickFixtureBeach(tester, sheetController);

          expect(tester.takeException(), isNull);
          expect(find.text('Depth: no data'), findsOneWidget);
        },
      );

      testWidgets('a loaded DepthProvider with a gentle profile shows the #256 '
          'verdict and the stand-up distance in the selected-beach card', (
        tester,
      ) async {
        final depthProvider = await aLoadedDepthProvider(gentleProfile);
        final sheetController = DraggableScrollableController();
        await pickFixtureBeach(
          tester,
          sheetController,
          depthProvider: depthProvider,
        );
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pumpAndSettle();

        expect(
          find.text('Shallow for a long way out. Easier for non-swimmers.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Stand-up water until about 200 m · '
            'Approximate (~115 m data). Not a safety guarantee.',
          ),
          findsOneWidget,
        );
      });

      testWidgets(
        'tapping the depth summary opens DepthDetailScreen, back returns '
        'to Home',
        (tester) async {
          final depthProvider = await aLoadedDepthProvider(gentleProfile);
          final sheetController = DraggableScrollableController();
          await pickFixtureBeach(
            tester,
            sheetController,
            depthProvider: depthProvider,
          );
          await tester.pump(const Duration(milliseconds: 10));
          await tester.pumpAndSettle();

          await tester.tap(
            find.text('Shallow for a long way out. Easier for non-swimmers.'),
          );
          await tester.pumpAndSettle();

          expect(find.byType(DepthDetailScreen), findsOneWidget);

          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();

          expect(find.byType(DepthDetailScreen), findsNothing);
          expect(find.byType(HomeScreen), findsOneWidget);
        },
      );

      testWidgets(
        'SearchScreen\'s own result rows never show a depth summary (no '
        'per-result depth fetch)',
        (tester) async {
          final depthProvider = await aLoadedDepthProvider(gentleProfile);
          final client = fixtureClient();
          final provider = await fakeNearbyBeachesProvider(client: client);
          addTearDown(provider.dispose);
          await pumpLoadedHome(tester, provider, depthProvider: depthProvider);

          await tester.tap(find.byTooltip('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Beaches'));
          await tester.pumpAndSettle();

          expect(find.byType(SearchScreen), findsOneWidget);
          expect(find.textContaining('Depth:'), findsNothing);
          expect(
            find.text('Shallow for a long way out. Easier for non-swimmers.'),
            findsNothing,
          );
        },
      );
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

    testWidgets('given a daytime wind crossing inside the daylight window, the '
        'Forecast screen still renders it as a daylight alert', (tester) async {
      final weatherProvider = await aLoadedWeatherProvider(
        aWeatherCondition(
          hourly: [
            aWeatherHourly(time: h(9), windSpeed: 10),
            aWeatherHourly(time: h(10), windSpeed: 45),
          ],
          daylightWindows: [aDaylightWindow(sunrise: h(6), sunset: h(20))],
        ),
      );
      final sheetController = DraggableScrollableController();

      await pumpApp(
        tester,
        HomeScreen(
          weatherProvider: weatherProvider,
          now: () => DateTime(2026, 1, 1, 8, 30),
          sheetController: sheetController,
        ),
      );
      await openForecastScreen(tester, sheetController);

      expect(find.byType(ForecastAlertList), findsOneWidget);
      expect(find.textContaining('Wind crosses 40 km/h'), findsOneWidget);
    });

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

    testWidgets(
      'given a next-hour note, build -> its message has no line cap or '
      'ellipsis (issue #289: wraps instead of being ellipsized)',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(21), windSpeed: 10),
              aWeatherHourly(time: h(22), windSpeed: 45),
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => h(21)),
        );

        final text = tester.widget<Text>(
          find.textContaining('Wind crosses 40 km/h'),
        );
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
      },
    );

    testWidgets(
      'given a next-hour note, tapping it opens the Forecast screen (issue '
      '#289: navigation from the note, not just the entry row)',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(21), windSpeed: 10),
              aWeatherHourly(time: h(22), windSpeed: 45),
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => h(21)),
        );
        expect(find.byType(ForecastScreen), findsNothing);

        await tester.tap(find.text('Next hour'));
        await tester.pumpAndSettle();

        expect(find.byType(ForecastScreen), findsOneWidget);
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

    Future<HomeScreen> loadedHome(
      WidgetTester tester, {
      DraggableScrollableController? sheetController,
    }) async {
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
        sheetController: sheetController,
      );
    }

    testWidgets('given loaded weather, marine and depth data, build -> renders '
        'exactly 3 groups (Sea, Current, Air, in that order) of exactly 3 '
        'StatTiles each — 9 same-size tiles in a 3x3 grid', (tester) async {
      final sheetController = DraggableScrollableController();
      await pumpApp(
        tester,
        await loadedHome(tester, sheetController: sheetController),
      );
      // Issue #284: the Current/Air groups only exist once expanded.
      await expandSheet(tester, sheetController);

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
      final sheetController = DraggableScrollableController();
      await pumpApp(
        tester,
        await loadedHome(tester, sheetController: sheetController),
      );
      await expandSheet(tester, sheetController);

      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('given full data, the 3x3 grid shows no trend row (no up/down '
        'arrow) on any of the nine tiles — only the detail screens keep one', (
      tester,
    ) async {
      final sheetController = DraggableScrollableController();
      await pumpApp(
        tester,
        await loadedHome(tester, sheetController: sheetController),
      );
      await expandSheet(tester, sheetController);

      expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets(
      'wave direction has no status/third line at all (a metric with no '
      'defined status), unlike current direction',
      (tester) async {
        final sheetController = DraggableScrollableController();
        await pumpApp(
          tester,
          await loadedHome(tester, sheetController: sheetController),
        );
        // Issue #284: the Current group's tiles only exist once expanded.
        await expandSheet(tester, sheetController);

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
      final sheetController = DraggableScrollableController();
      await pumpApp(
        tester,
        await loadedHome(tester, sheetController: sheetController),
      );
      await expandSheet(tester, sheetController);

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
        // Issue #284: the collapsed sheet is short enough on the default
        // test viewport that its own Sea tiles need scrolling into view.
        await tester.ensureVisible(find.byKey(const Key('wave-height-tile')));
        await tester.pumpAndSettle();

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
      await tester.ensureVisible(
        find.byKey(const Key('water-temperature-tile')),
      );
      await tester.pumpAndSettle();

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
        final sheetController = DraggableScrollableController();
        await pumpApp(
          tester,
          await loadedHome(tester, sheetController: sheetController),
        );
        // Issue #284: the Current group's tiles only exist once expanded.
        await expandSheet(tester, sheetController);

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
        final sheetController = DraggableScrollableController();

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            depthProvider: depthProvider,
            sheetController: sheetController,
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
        // Issue #284: the wind speed tile (Air group) only exists once
        // expanded.
        await expandSheet(tester, sheetController);
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
        final sheetController = DraggableScrollableController();
        final home = await loadedHome(tester, sheetController: sheetController);

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

        // Issue #284: expand the sheet too, so the full 9-tile grid (not
        // just the collapsed Sea group) is exercised at this narrow width.
        await expandSheet(tester, sheetController);
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

      final sheetController = DraggableScrollableController();
      await pumpApp(
        tester,
        HomeScreen(
          nearbyBeachesProvider: provider,
          weatherProvider: weatherProvider,
          sheetController: sheetController,
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
      // Issue #284: the compact info row (BeachResultCard) only exists once
      // the sheet is expanded — there's no docked map-card location bar
      // left to show a third, pre-#284 occurrence of the name.
      await expandSheet(tester, sheetController);
      // The sheet's own header title and the compact info row below it
      // both render the same beach name.
      expect(find.text('Fixture Beach'), findsNWidgets(2));
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

  group('HomeScreen alerts toggle (issue #267)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    /// A real [ConditionAlertDispatcher] wired to throwaway providers/
    /// notification service — this group only exercises the overflow
    /// menu's switch, never a verdict transition, so nothing here ever
    /// polls or shows a notification.
    Future<ConditionAlertDispatcher> aDispatcher({bool enabled = true}) async {
      SharedPreferences.setMockInitialValues({
        if (!enabled) alertsEnabledPrefsKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      return ConditionAlertDispatcher(
        weatherProvider: WeatherProvider(
          WeatherRepository(WeatherApiService()),
        ),
        marineProvider: MarineProvider(MarineRepository(MarineApiService())),
        notificationService: NotificationService(plugin: _NoopPlugin()),
        prefs: prefs,
      );
    }

    testWidgets(
      'given no conditionAlertDispatcher, the map overflow menu has no '
      '"Alerts" entry',
      (tester) async {
        await pumpApp(tester, const HomeScreen());

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();

        expect(find.text('Alerts'), findsNothing);
      },
    );

    testWidgets(
      'given a conditionAlertDispatcher with alerts enabled, the overflow '
      'menu shows an "Alerts" switch reflecting that, and tapping it calls '
      'setAlertsEnabled(false)',
      (tester) async {
        final dispatcher = await aDispatcher();

        await pumpApp(tester, HomeScreen(conditionAlertDispatcher: dispatcher));

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();

        final switchFinder = find.byKey(
          const Key('map-overflow-alerts-switch'),
        );
        expect(switchFinder, findsOneWidget);
        expect(tester.widget<Switch>(switchFinder).value, isTrue);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(dispatcher.alertsEnabled, isFalse);
        expect(tester.widget<Switch>(switchFinder).value, isFalse);
      },
    );

    testWidgets(
      'given a conditionAlertDispatcher with alerts already disabled, the '
      'overflow menu\'s "Alerts" switch starts off and tapping it calls '
      'setAlertsEnabled(true)',
      (tester) async {
        final dispatcher = await aDispatcher(enabled: false);

        await pumpApp(tester, HomeScreen(conditionAlertDispatcher: dispatcher));

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();

        final switchFinder = find.byKey(
          const Key('map-overflow-alerts-switch'),
        );
        expect(tester.widget<Switch>(switchFinder).value, isFalse);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(dispatcher.alertsEnabled, isTrue);
      },
    );
  });

  group('HomeScreen compare beaches (issue #274)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    /// Two distinct beaches (unlike the single-beach `fixtureClient()`
    /// used elsewhere in this file) so `NearbyBeachesProvider.beaches` has
    /// enough candidates for "Compare beaches" to work with.
    FakeHttpClient twoBeachClient() {
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
                  'name': 'Alpha Beach',
                  'addr:city': 'Alpha City',
                  'fee': 'no',
                },
                'geometry': [
                  {'lat': 38.40, 'lon': 26.40},
                  {'lat': 38.41, 'lon': 26.40},
                ],
              },
              {
                'type': 'way',
                'id': 2,
                'tags': {
                  'natural': 'beach',
                  'name': 'Beta Beach',
                  'addr:city': 'Beta City',
                  'fee': 'no',
                },
                'geometry': [
                  {'lat': 38.50, 'lon': 26.50},
                  {'lat': 38.51, 'lon': 26.50},
                ],
              },
            ],
          },
        )
        ..queueJson(
          host: 'marine-api.open-meteo.com',
          json: [
            {
              'current': {'wave_height': 0.5, 'sea_surface_temperature': 22.0},
            },
            {
              'current': {'wave_height': 1.1, 'sea_surface_temperature': 25.0},
            },
          ],
        );
    }

    Future<void> pumpLoadedHome(
      WidgetTester tester,
      NearbyBeachesProvider provider,
    ) async {
      await pumpApp(tester, HomeScreen(nearbyBeachesProvider: provider));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('the map overflow menu always has a "Compare beaches" entry', (
      tester,
    ) async {
      await pumpApp(tester, const HomeScreen());

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      expect(find.text('Compare beaches'), findsOneWidget);
    });

    testWidgets('given fewer than two nearby beaches fetched, tapping "Compare '
        'beaches" shows a SnackBar instead of opening an empty screen', (
      tester,
    ) async {
      await pumpApp(tester, const HomeScreen());

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compare beaches'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const Key('compare-select-confirm')), findsNothing);
    });

    testWidgets(
      'given two nearby beaches fetched, tapping "Compare beaches" opens '
      'a selection sheet listing both, and checking both then tapping '
      '"Compare" opens the comparison screen for them',
      (tester) async {
        final provider = await fakeNearbyBeachesProvider(
          client: twoBeachClient(),
        );
        addTearDown(provider.dispose);
        await pumpLoadedHome(tester, provider);

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compare beaches'));
        await tester.pumpAndSettle();

        expect(find.text('Alpha Beach'), findsOneWidget);
        expect(find.text('Beta Beach'), findsOneWidget);
        final confirmFinder = find.byKey(const Key('compare-select-confirm'));
        expect(tester.widget<ElevatedButton>(confirmFinder).onPressed, isNull);

        await tester.tap(find.byKey(const Key('compare-select-Alpha Beach')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('compare-select-Beta Beach')));
        await tester.pump();
        expect(
          tester.widget<ElevatedButton>(confirmFinder).onPressed,
          isNotNull,
        );

        await tester.tap(confirmFinder);
        await tester.pumpAndSettle();

        expect(find.text('Compare beaches'), findsWidgets);
        expect(find.text('Alpha Beach'), findsOneWidget);
        expect(find.text('Beta Beach'), findsOneWidget);
      },
    );

    testWidgets(
      'given Beta Beach is already a favorite, the selection sheet marks '
      'it with a star and lists it before the non-favorite Alpha Beach',
      (tester) async {
        final provider = await fakeNearbyBeachesProvider(
          client: twoBeachClient(),
        );
        addTearDown(provider.dispose);
        // `FavoritesProvider.keyFor`'s own format ("name|city"), seeded
        // after `fakeNearbyBeachesProvider` (which resets the mock prefs
        // to `{}` internally) and before `_openCompareSelection` builds
        // its own throwaway `FavoritesProvider` from `SharedPreferences`.
        SharedPreferences.setMockInitialValues({
          'favorite_beaches': ['Beta Beach|Beta City'],
        });
        await pumpLoadedHome(tester, provider);

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compare beaches'));
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .toList();
        expect(tiles, hasLength(2));
        expect((tiles.first.title as Text).data, 'Beta Beach');
        expect(tiles.first.secondary, isA<Icon>());
        expect((tiles.first.secondary as Icon).icon, Icons.star);

        expect((tiles.last.title as Text).data, 'Alpha Beach');
        expect(tiles.last.secondary, isNull);
      },
    );

    testWidgets(
      'given a compareWeatherRepository, forwards it to the comparison '
      'screen so its wind/swim-score columns show real values rather than '
      '"No data"',
      (tester) async {
        final provider = await fakeNearbyBeachesProvider(
          client: twoBeachClient(),
        );
        addTearDown(provider.dispose);
        await pumpApp(
          tester,
          HomeScreen(
            nearbyBeachesProvider: provider,
            compareWeatherRepository: FakeWeatherRepository(
              data: aWeatherCondition(windSpeed: 15),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compare beaches'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('compare-select-Alpha Beach')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('compare-select-Beta Beach')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('compare-select-confirm')));
        await tester.pumpAndSettle();

        expect(find.text('15 km/h'), findsNWidgets(2));
      },
    );

    testWidgets(
      'given more than three nearby beaches, a fourth checkbox tap is '
      'ignored -- never more than 3 selected at once',
      (tester) async {
        final client = FakeHttpClient()
          ..queueJson(
            host: 'overpass-api.de',
            json: {
              'elements': [
                for (var i = 0; i < 4; i++)
                  {
                    'type': 'way',
                    'id': i,
                    'tags': {
                      'natural': 'beach',
                      'name': 'Beach $i',
                      'addr:city': 'City $i',
                      'fee': 'no',
                    },
                    'geometry': [
                      {'lat': 38.40 + i * 0.1, 'lon': 26.40},
                      {'lat': 38.41 + i * 0.1, 'lon': 26.40},
                    ],
                  },
              ],
            },
          )
          ..queueJson(
            host: 'marine-api.open-meteo.com',
            json: [
              for (var i = 0; i < 4; i++) {'current': {}},
            ],
          );
        final provider = await fakeNearbyBeachesProvider(client: client);
        addTearDown(provider.dispose);
        await pumpLoadedHome(tester, provider);

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compare beaches'));
        await tester.pumpAndSettle();

        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byKey(Key('compare-select-Beach $i')));
          await tester.pump();
        }

        expect(
          tester
              .widget<Checkbox>(
                find.descendant(
                  of: find.byKey(const Key('compare-select-Beach 3')),
                  matching: find.byType(Checkbox),
                ),
              )
              .value,
          isFalse,
        );
      },
    );
  });

  group('HomeScreen map-first layout with draggable bottom sheet (issue '
      '#284)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    /// A loaded, non-default pick so the header's place name/temperature
    /// are easy to tell apart from the Çeşme first-run default.
    Future<HomeScreen> loadedHome({
      DraggableScrollableController? sheetController,
    }) async {
      final weatherProvider = await aLoadedWeatherProvider(
        aWeatherCondition(
          temperature: 22,
          windSpeed: 10,
          rainChancePercent: 20,
          uvIndex: 3,
          hourly: [
            aWeatherHourly(time: DateTime(2026, 7, 1, 12), temperature: 22),
            aWeatherHourly(time: DateTime(2026, 7, 1, 13), temperature: 23),
          ],
          dailyForecast: [
            aDailyWeatherForecast(
              date: DateTime(2026, 7, 1),
              highTemperature: 26.0,
              lowTemperature: 18.0,
            ),
          ],
        ),
      );
      final marineProvider = await aLoadedMarineProvider(
        aSeaCondition(
          waveHeight: 0.4,
          seaSurfaceTemperature: 23.0,
          dailyForecast: [
            aSeaDailyForecast(date: DateTime(2026, 7, 1), waveHeightMax: 0.4),
          ],
        ),
      );
      return HomeScreen(
        weatherProvider: weatherProvider,
        marineProvider: marineProvider,
        now: () => DateTime(2026, 7, 1, 12),
        sheetController: sheetController,
      );
    }

    testWidgets(
      'the bottom sheet starts collapsed: place name, temperature, the '
      'suggestion pill and the 3 Sea tiles are shown, but the Air/Current '
      'tiles and the hourly row are not laid out at all (not just scrolled '
      'off)',
      (tester) async {
        await pumpApp(tester, await loadedHome());

        // Collapsed content.
        expect(find.text('Çeşme, İzmir'), findsOneWidget);
        expect(find.text('22°'), findsOneWidget);
        expect(find.byType(SwimSuggestionPill), findsOneWidget);
        expect(
          tester
              .widgetList<StatTileGroup>(find.byType(StatTileGroup))
              .map((g) => g.label),
          ['Sea'],
        );
        expect(find.text('Wave height'), findsOneWidget);
        expect(find.text('Water temp'), findsOneWidget);
        expect(find.text('Water depth'), findsOneWidget);

        // Not laid out at the collapsed size: the Current/Air groups (6 of
        // the 9 tiles), the hourly row and the forecast entry row (issue
        // #289: the 7-14 day outlook itself never renders on Home at all).
        expect(find.byType(StatTile), findsNWidgets(3));
        expect(find.byType(HourlyForecastItem), findsNothing);
        expect(find.text('Hourly forecast'), findsNothing);
        expect(find.byType(DailyOutlookList), findsNothing);
        expect(find.byKey(const Key('home-forecast-entry-row')), findsNothing);
      },
    );

    testWidgets(
      'dragging/expanding the sheet reveals the rest of the content: the '
      'Current/Air groups, the hourly row and the forecast entry row',
      (tester) async {
        final sheetController = DraggableScrollableController();
        await pumpApp(
          tester,
          await loadedHome(sheetController: sheetController),
        );

        expect(find.byType(StatTile), findsNWidgets(3));

        await expandSheet(tester, sheetController);

        expect(find.byType(StatTile), findsNWidgets(9));
        expect(
          tester
              .widgetList<StatTileGroup>(find.byType(StatTileGroup))
              .map((g) => g.label),
          ['Sea', 'Current', 'Air'],
        );
        expect(find.text('Hourly forecast'), findsOneWidget);
        expect(find.byType(HourlyForecastItem), findsWidgets);
        // Issue #289: a single entry row, not the outlook list itself.
        expect(find.text('Forecast and 7-14 day outlook'), findsOneWidget);
        expect(find.byType(DailyOutlookList), findsNothing);
        // The collapsed content is still there too — expanded is additive.
        expect(find.text('Çeşme, İzmir'), findsOneWidget);
        expect(find.byType(SwimSuggestionPill), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the map updates the sheet\'s place name and temperature in '
      'place, and the sheet stays collapsed (it is not reset/re-expanded '
      'by the pick)',
      (tester) async {
        final weatherProvider = WeatherProvider(_TwoStepWeatherRepository());

        await pumpApp(
          tester,
          HomeScreen(
            tileProvider: FakeTileProvider(),
            weatherProvider: weatherProvider,
          ),
        );

        expect(find.text('Çeşme, İzmir'), findsOneWidget);
        expect(find.text('20°'), findsOneWidget);
        // Still collapsed: the Current/Air groups aren't laid out yet.
        expect(find.byType(StatTile), findsNWidgets(3));

        // flutter_map delays a single tap by its double-tap-to-zoom window
        // before firing onTap (see location_map_card_picker_test.dart).
        await tester.tap(find.byType(FlutterMap));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Updated in place: a new place name (no reverse geocoding wired
        // up, so it falls back to formatted coordinates, #254) and the new
        // temperature.
        expect(find.text('Çeşme, İzmir'), findsNothing);
        expect(find.textContaining('°N'), findsOneWidget);
        expect(find.text('35°'), findsOneWidget);
        expect(find.text('20°'), findsNothing);
        // Still collapsed — the pick did not expand the sheet.
        expect(find.byType(StatTile), findsNWidgets(3));
        expect(find.byType(HourlyForecastItem), findsNothing);
      },
    );

    testWidgets(
      'the sheet stays expanded across a location pick (its own state is '
      'independent of the picked location)',
      (tester) async {
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
                  'geometry': [
                    {'lat': 38.40, 'lon': 26.40},
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
                  'sea_surface_temperature': 22.0,
                },
              },
            ],
          );
        final provider = await fakeNearbyBeachesProvider(client: client);
        addTearDown(provider.dispose);
        final sheetController = DraggableScrollableController();
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(temperature: 27),
        );

        await pumpApp(
          tester,
          HomeScreen(
            nearbyBeachesProvider: provider,
            weatherProvider: weatherProvider,
            sheetController: sheetController,
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));
        await expandSheet(tester, sheetController);
        expect(find.byType(StatTile), findsNWidgets(9));

        // Picked via the overflow menu's "Beaches" entry (reachable without
        // tapping the map, which the expanded sheet now mostly covers —
        // matching how little of the map is left tappable in the mockup's
        // own expanded state).
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beaches'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fixture Beach'));
        await tester.pumpAndSettle();

        expect(find.text('Fixture Beach'), findsAtLeastNWidgets(1));
        // Still expanded — the pick did not reset the sheet back down (this
        // fixture carries no hourly data, so the Current/Air groups being
        // back are what proves it, not the hourly row).
        expect(find.byType(StatTile), findsNWidgets(9));
      },
    );

    testWidgets(
      'the floating search field surfaces live geocoding results from '
      'PlaceSearchProvider, and selecting one picks that location',
      (tester) async {
        final client = FakeHttpClient()
          ..queueJson(
            host: 'geocoding-api.open-meteo.com',
            json: {
              'results': [
                {'name': 'Bodrum', 'latitude': 37.03, 'longitude': 27.43},
              ],
            },
          );
        final placeSearchProvider = PlaceSearchProvider(
          GeocodingService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(placeSearchProvider.dispose);

        await pumpApp(
          tester,
          HomeScreen(
            tileProvider: FakeTileProvider(),
            placeSearchProvider: placeSearchProvider,
          ),
        );

        expect(find.byType(SearchField), findsOneWidget);
        expect(find.byKey(const Key('home-search-results')), findsNothing);

        await tester.enterText(find.byType(TextField), 'bodrum');
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();

        expect(find.byKey(const Key('home-search-results')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-search-result-0-Bodrum')),
          findsOneWidget,
        );
        expect(find.text('Bodrum'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('home-search-result-0-Bodrum')),
        );
        await tester.pumpAndSettle();

        // Selecting the result picks it exactly like a map tap: the real
        // looked-up name, not a coordinate fallback, now shows in the
        // sheet's header, and the search field/results collapse away.
        expect(find.text('Bodrum'), findsOneWidget);
        expect(find.byKey(const Key('home-search-results')), findsNothing);
      },
    );

    testWidgets('given no placeSearchProvider, the floating search field still '
        'renders (no toggle to tap first) but shows no results panel', (
      tester,
    ) async {
      await pumpApp(tester, const HomeScreen());

      expect(find.byType(SearchField), findsOneWidget);
      expect(find.byKey(const Key('home-search-results')), findsNothing);
    });

    test('zoomMapBy given an unattached MapController (FlutterMap never '
        'rendered), is a no-op and never throws — MapController.camera '
        "throws a plain Exception in that case (flutter_map's own "
        'implementation), which this always catches; it would NOT catch a '
        'LateInitializationError if the underlying package ever threw one '
        'instead', () {
      final controller = MapController();
      addTearDown(controller.dispose);
      expect(() => zoomMapBy(controller, 1), returnsNormally);
      expect(() => zoomMapBy(controller, -1), returnsNormally);
    });

    testWidgets(
      'the floating zoom-in/zoom-out buttons move the map camera by +-1 '
      'zoom level each tap, clamped to kLocationMapMinZoom/'
      'kLocationMapMaxZoom',
      (tester) async {
        await pumpApp(tester, HomeScreen(tileProvider: FakeTileProvider()));

        MapController currentController() =>
            tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
        double currentZoom() => currentController().camera.zoom;

        final initialZoom = currentZoom();

        await tester.tap(find.byKey(const Key('home-zoom-in-button')));
        await tester.pump();
        expect(currentZoom(), closeTo(initialZoom + 1, 0.001));

        await tester.tap(find.byKey(const Key('home-zoom-out-button')));
        await tester.pump();
        expect(currentZoom(), closeTo(initialZoom, 0.001));

        // Clamped at the floor: many more zoom-out taps than needed to
        // reach kLocationMapMinZoom from the initial zoom must never go
        // lower than it.
        for (var i = 0; i < 20; i++) {
          await tester.tap(find.byKey(const Key('home-zoom-out-button')));
          await tester.pump();
        }
        expect(currentZoom(), kLocationMapMinZoom);

        // Clamped at the ceiling: many more zoom-in taps than needed to
        // reach kLocationMapMaxZoom must never go higher than it.
        for (var i = 0; i < 30; i++) {
          await tester.tap(find.byKey(const Key('home-zoom-in-button')));
          await tester.pump();
        }
        expect(currentZoom(), kLocationMapMaxZoom);
      },
    );
  });
}

/// A [WeatherRepository] that answers the first call with 20°C and every
/// later call with 35°C — used by the map-first layout tests above to prove
/// a map pick's re-fetch really changes the sheet's temperature.
class _TwoStepWeatherRepository extends WeatherRepository {
  _TwoStepWeatherRepository() : super(WeatherApiService());

  int _calls = 0;

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async {
    _calls++;
    return _calls == 1
        ? aWeatherCondition(temperature: 20)
        : aWeatherCondition(temperature: 35);
  }
}

/// A no-op [LocalNotificationsPlugin] for the alerts-toggle widget tests
/// above, which never trigger a notification — only [NotificationService]'s
/// constructor needs a plugin instance.
class _NoopPlugin implements LocalNotificationsPlugin {
  @override
  Future<bool?> initialize(InitializationSettings settings) async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(int id, String? title, String? body) async {}
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
