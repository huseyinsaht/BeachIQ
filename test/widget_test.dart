import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/models/weather_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/services/marine_batch_service.dart';
import 'package:beachiq/data/services/overpass_service.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/nearby_beaches_provider.dart';
import 'package:beachiq/logic/providers/unit_preferences_provider.dart';
import 'package:beachiq/logic/providers/weather_provider.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/logic/wave_shore_relation.dart';
import 'package:beachiq/presentation/screens/detail/pressure_detail_screen.dart';
import 'package:beachiq/presentation/screens/home_screen.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:beachiq/presentation/widgets/hourly_forecast_item.dart';
import 'package:beachiq/presentation/widgets/location_map_card.dart';
import 'package:beachiq/presentation/widgets/sea_conditions_row.dart';
import 'package:beachiq/presentation/widgets/stat_tile.dart';
import 'package:beachiq/presentation/widgets/swim_suggestion_pill.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/pump_app.dart';

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
            'wave_height': 0.8,
            'wave_direction': 180,
            'wave_period': 5,
            'sea_surface_temperature': 25.0,
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
      ],
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

NearbyBeachesProvider _fixtureNearbyBeachesProvider() {
  final client = _FixtureNetworkClient();
  return NearbyBeachesProvider(
    OverpassService(client),
    BeachCache(_mockPrefs!),
    MarineBatchService(client),
    debounceDuration: const Duration(milliseconds: 1),
  );
}

/// Like [_FixtureNetworkClient], but the Overpass response also includes a
/// parking amenity node near the fixture beach, so the mapped [Beach] has a
/// non-empty `amenities` list — needed to exercise
/// `seawardBearingFromGeometry`'s real (non-null) path, not just its
/// no-amenities -> null fallback.
class _FixtureNetworkClientWithAmenity extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.host.contains('overpass')) {
      final body = json.encode([
        {
          'current': {
            'wave_height': 0.8,
            'wave_direction': 180,
            'wave_period': 5,
            'sea_surface_temperature': 25.0,
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
          // Just south of the beach's geometry, within the 150m attach
          // radius, so it gets attached as a land-side amenity.
          'lat': 38.32195,
          'lon': 26.3265,
          'tags': {'amenity': 'parking', 'name': 'Fixture Car Park'},
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

/// Like [_FixtureNetworkClientWithAmenity], but the Overpass response lists
/// TWO beaches, each with its own amenity: a far one (listed FIRST, ~100 km
/// from `_placeCenter`) and the real fixture beach at `_placeCenter` (listed
/// SECOND). `NearbyBeachesProvider.beaches` carries no distance ordering
/// (Overpass returns elements in element-id order), so this proves
/// HomeScreen picks the nearest beach by actual distance rather than
/// assuming the first list entry is closest.
class _FixtureNetworkClientTwoBeaches extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.host.contains('overpass')) {
      final body = json.encode([
        {
          'current': {
            'wave_height': 0.8,
            'wave_direction': 180,
            'wave_period': 5,
            'sea_surface_temperature': 25.0,
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
          'id': 10,
          'tags': {
            'natural': 'beach',
            'name': 'Far Beach',
            'addr:city': 'Elsewhere',
            'fee': 'no',
          },
          'geometry': [
            {'lat': 39.00, 'lon': 27.00},
            {'lat': 39.01, 'lon': 27.00},
            {'lat': 39.01, 'lon': 27.01},
          ],
        },
        {
          'type': 'node',
          'id': 11,
          'lat': 38.99995,
          'lon': 27.005,
          'tags': {'amenity': 'parking', 'name': 'Far Car Park'},
        },
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
          'lat': 38.32195,
          'lon': 26.3265,
          'tags': {'amenity': 'parking', 'name': 'Fixture Car Park'},
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

NearbyBeachesProvider _fixtureNearbyBeachesProviderWithAmenity() {
  final client = _FixtureNetworkClientWithAmenity();
  return NearbyBeachesProvider(
    OverpassService(client),
    BeachCache(_mockPrefs!),
    MarineBatchService(client),
    debounceDuration: const Duration(milliseconds: 1),
  );
}

SharedPreferences? _mockPrefs;

// Minimal valid 1x1 transparent PNG, used so the fake tile provider can
// resolve a real image without any network access.
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

/// A [MarineRepository] whose response never resolves, so tests can inspect
/// the UI while a fetch is still in flight.
class _PendingMarineRepository extends MarineRepository {
  _PendingMarineRepository() : super(MarineApiService());

  final Completer<SeaCondition> completer = Completer<SeaCondition>();

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) =>
      completer.future;
}

class _FixedMarineRepository extends MarineRepository {
  _FixedMarineRepository(this.data) : super(MarineApiService());

  final SeaCondition data;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async => data;
}

class _FailingMarineRepository extends MarineRepository {
  _FailingMarineRepository(this._message) : super(MarineApiService());

  final String _message;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    throw Exception(_message);
  }
}

/// A [MarineRepository] whose calls each get their own [Completer], kept in
/// [calls] in call order, so a test can resolve one fetch (e.g. the initial
/// load) while leaving a later one (e.g. a pull-to-refresh) pending.
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

SeaCondition _fakeSeaCondition() => SeaCondition(
  waveHeight: 0.5,
  waveDirection: 90,
  wavePeriod: 5,
  seaSurfaceTemperature: 22,
);

class _SucceedingMarineRepository extends MarineRepository {
  _SucceedingMarineRepository() : super(MarineApiService());

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    return SeaCondition(
      waveHeight: 0.5,
      waveDirection: 90,
      wavePeriod: 5,
      seaSurfaceTemperature: 22,
    );
  }
}

WeatherCondition _fakeWeatherCondition({double? uvIndex = 6.5}) {
  return WeatherCondition(
    temperature: 27,
    windSpeed: 12,
    weatherCode: 1,
    pressureHpa: 1013,
    uvIndex: uvIndex,
    rainChancePercent: 10,
    highTemperature: 29,
    lowTemperature: 15,
    hourly: [
      // Deliberately distinct from the header's 27° so tests can tell the
      // header and hourly-row temperatures apart.
      WeatherHourly(
        time: DateTime(2026, 1, 1, 12),
        temperature: 26,
        weatherCode: 1,
      ),
      WeatherHourly(
        time: DateTime(2026, 1, 1, 13),
        temperature: 28,
        weatherCode: 1,
      ),
    ],
  );
}

class _SucceedingWeatherRepository extends WeatherRepository {
  _SucceedingWeatherRepository({this.uvIndex = 6.5})
    : super(WeatherApiService());

  final double? uvIndex;

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async {
    return _fakeWeatherCondition(uvIndex: uvIndex);
  }
}

class _FailingWeatherRepository extends WeatherRepository {
  _FailingWeatherRepository() : super(WeatherApiService());

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async {
    throw Exception('boom');
  }
}

class _FixedWeatherRepository extends WeatherRepository {
  _FixedWeatherRepository(this.data) : super(WeatherApiService());

  final WeatherCondition data;

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async {
    return data;
  }
}

/// A [WeatherRepository] that records every (lat, lon) it's asked for, in
/// call order, and resolves to [results] at the matching index (repeating
/// the last entry if asked more times than [results] has) — so a test can
/// prove a later call (e.g. one triggered by a map pick) was made with
/// *different* coordinates than the first, and produced different data,
/// rather than reusing the first fetch (#157).
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // HomeScreen's search entry point constructs a FavoritesProvider (via
    // SharedPreferences.getInstance()) before pushing SearchScreen, and
    // NearbyBeachesProvider's BeachCache needs one too.
    SharedPreferences.setMockInitialValues({});
    _mockPrefs = await SharedPreferences.getInstance();
  });

  testWidgets('HomeScreen renders the composed location-detail layout', (
    WidgetTester tester,
  ) async {
    final weatherProvider = WeatherProvider(_SucceedingWeatherRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('My Location'), findsOneWidget);
    expect(find.byType(LocationMapCard), findsOneWidget);
    expect(find.byType(StatTile), findsNWidgets(4));
    expect(find.byType(HourlyForecastItem), findsWidgets);
    expect(find.text('Now'), findsOneWidget);
  });

  testWidgets(
    'HomeScreen fetches weather data on init and binds the header, stat '
    'grid and hourly row to real WeatherProvider values',
    (WidgetTester tester) async {
      final weatherProvider = WeatherProvider(_SucceedingWeatherRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            // Pins "now" inside the fixture's hourly window (12:00-13:00)
            // so both entries are on/after "now" and survive the
            // current-hour-onward trim.
            now: () => DateTime(2026, 1, 1, 12, 30),
          ),
        ),
      );
      // initState fires WeatherProvider.fetchData itself; no manual call.
      await tester.pumpAndSettle();

      expect(weatherProvider.currentData, isNotNull);

      // Header: real temperature/condition, replacing the old hardcoded
      // '27°'/'Partly Cloudy'/'H:29° L:15°'.
      expect(find.text('27°'), findsOneWidget);
      expect(find.text('Mainly Clear'), findsOneWidget);
      expect(find.text('H:29° L:15°'), findsOneWidget);

      // Stat grid: real wind speed/rain chance/pressure/UV index.
      expect(find.text('12 km/h'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('1013 hPa'), findsOneWidget);
      expect(find.text('6.5'), findsOneWidget);

      // Hourly row: real fixture entries instead of the old hardcoded
      // six-item list.
      expect(find.byType(HourlyForecastItem), findsNWidgets(2));
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('28°'), findsOneWidget);
    },
  );

  testWidgets(
    'an imperial UnitPreferencesProvider converts the header, stat grid '
    'and hourly row temperature/wind speed values',
    (WidgetTester tester) async {
      final weatherProvider = WeatherProvider(_SucceedingWeatherRepository());
      final unitPreferencesProvider = UnitPreferencesProvider(
        await SharedPreferences.getInstance(),
      );
      await unitPreferencesProvider.setUnitSystem(UnitSystem.imperial);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            unitPreferencesProvider: unitPreferencesProvider,
            now: () => DateTime(2026, 1, 1, 12, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header: 27°C -> 81°F; H:29°C/L:15°C -> H:84°F/L:59°F.
      expect(find.text('81°F'), findsOneWidget);
      expect(find.text('H:84°F L:59°F'), findsOneWidget);

      // Stat grid: 12 km/h -> 7 mph.
      expect(find.text('7 mph'), findsOneWidget);

      // Hourly row: 28°C -> 82°F.
      expect(find.text('82°F'), findsOneWidget);

      // None of the metric strings should remain.
      expect(find.text('27°'), findsNothing);
      expect(find.text('12 km/h'), findsNothing);
    },
  );

  testWidgets(
    'the map card overflow opens the unit sheet, and picking Imperial '
    'converts the header without a restart',
    (WidgetTester tester) async {
      final weatherProvider = WeatherProvider(_SucceedingWeatherRepository());
      final unitPreferencesProvider = UnitPreferencesProvider(
        await SharedPreferences.getInstance(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            unitPreferencesProvider: unitPreferencesProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('27°'), findsOneWidget);
      expect(find.text('Imperial (ft, °F, mph)'), findsNothing);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      expect(find.text('Imperial (ft, °F, mph)'), findsOneWidget);

      await tester.tap(find.text('Imperial (ft, °F, mph)'));
      await tester.pumpAndSettle();

      expect(unitPreferencesProvider.unitSystem, UnitSystem.imperial);
      expect(find.text('81°F'), findsOneWidget);
      expect(find.text('27°'), findsNothing);
    },
  );

  testWidgets(
    'the hourly row starts at the current hour (not local midnight) and '
    'caps at 24 entries',
    (WidgetTester tester) async {
      // Open-Meteo returns a full day starting at local midnight; this
      // fixture spans 40 hours from midnight to catch both the trim and
      // the 24-entry cap.
      final hourly = [
        for (var i = 0; i < 40; i++)
          WeatherHourly(
            time: DateTime(2026, 1, 1).add(Duration(hours: i)),
            temperature: i.toDouble(),
            weatherCode: 1,
          ),
      ];
      final weatherProvider = WeatherProvider(
        _FixedWeatherRepository(
          WeatherCondition(
            temperature: 20,
            windSpeed: 5,
            weatherCode: 1,
            hourly: hourly,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            // 02:30 falls in the 02:00 entry (temperature 2°).
            now: () => DateTime(2026, 1, 1, 2, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts at the 02:00 entry ("Now"/2°), not midnight (0°) or 01:00.
      expect(find.text('Now'), findsOneWidget);
      final firstItem = tester.widget<HourlyForecastItem>(
        find.byType(HourlyForecastItem).first,
      );
      expect(firstItem.temperature, '2°');
      expect(find.text('0°'), findsNothing);
      expect(find.text('1°'), findsNothing);

      // Capped at 24 entries: 02:00 through 25:00 (01:00 the next day),
      // i.e. temperatures 2 through 25; 26° and beyond are excluded. The
      // horizontal ListView only builds on-screen items, so the total
      // count is read off its own delegate rather than counting rendered
      // widgets. ListView.separated's delegate interleaves an item and a
      // separator per entry (minus the trailing separator), so its
      // childCount is itemCount * 2 - 1.
      final listView = tester.widget<ListView>(find.byType(ListView));
      final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
      expect((delegate.childCount! + 1) ~/ 2, 24);
      expect(find.text('26°'), findsNothing);
    },
  );

  testWidgets(
    "the hourly row's icons follow each entry's own hour, not the real "
    'clock: a clear noon entry shows a sun and a clear 11PM entry shows a '
    'moon side by side',
    (WidgetTester tester) async {
      final weatherProvider = WeatherProvider(
        _FixedWeatherRepository(
          WeatherCondition(
            temperature: 20,
            windSpeed: 5,
            weatherCode: 1,
            hourly: [
              WeatherHourly(
                time: DateTime(2026, 1, 1, 12),
                temperature: 26,
                weatherCode: 1,
              ),
              WeatherHourly(
                time: DateTime(2026, 1, 1, 23),
                temperature: 18,
                weatherCode: 1,
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            weatherProvider: weatherProvider,
            // Deliberately before both entries; the runner's own real
            // clock time must not affect which icon shows for which hour.
            now: () => DateTime(2026, 1, 1, 8),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    },
  );

  testWidgets('a stat tile whose WeatherProvider field is null shows "No data" '
      'instead of a fabricated value', (WidgetTester tester) async {
    final weatherProvider = WeatherProvider(
      _SucceedingWeatherRepository(uvIndex: null),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No data'), findsOneWidget);
    expect(find.text('6.5'), findsNothing);
  });

  testWidgets(
    'HomeScreen shows "No data"/"--°" placeholders rather than crashing '
    'when no WeatherProvider is supplied',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(tileProvider: _FakeTileProvider())),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('--°'), findsWidgets);
      expect(find.byType(StatTile), findsNWidgets(4));
      expect(find.byType(HourlyForecastItem), findsNothing);
    },
  );

  testWidgets('HomeScreen shows "No data" rather than crashing when the '
      'WeatherProvider fetch fails', (WidgetTester tester) async {
    final weatherProvider = WeatherProvider(_FailingWeatherRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tileProvider: _FakeTileProvider(),
          weatherProvider: weatherProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(weatherProvider.error, isNotNull);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('--°'), findsWidgets);
    expect(find.byType(StatTile), findsNWidgets(4));
  });

  testWidgets('HomeScreen built the same way MarineApp composes it (inside the '
      'Consumer2 that also listens to WeatherProvider) does not throw on '
      'its first frame', (WidgetTester tester) async {
    final marineProvider = MarineProvider(_SucceedingMarineRepository());
    final weatherProvider = WeatherProvider(_SucceedingWeatherRepository());

    // Mirrors MarineApp's own widget tree (MultiProvider + Consumer2)
    // rather than pumping a bare HomeScreen, so this catches
    // WeatherProvider.fetchData notifying an ancestor Consumer2 while it
    // is still building HomeScreen itself.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MarineProvider>.value(value: marineProvider),
          ChangeNotifierProvider<WeatherProvider>.value(value: weatherProvider),
        ],
        child: Consumer2<MarineProvider, WeatherProvider>(
          builder: (context, mp, wp, _) => MaterialApp(
            home: HomeScreen(
              tileProvider: _FakeTileProvider(),
              marineProvider: mp,
              weatherProvider: wp,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(weatherProvider.currentData, isNotNull);
  });

  testWidgets('HomeScreen shows a loading indicator while marine data loads', (
    WidgetTester tester,
  ) async {
    final repository = _PendingMarineRepository();
    final provider = MarineProvider(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          tileProvider: _FakeTileProvider(),
          marineProvider: provider,
        ),
      ),
    );
    await tester.pump();

    unawaited(provider.fetchData(38.3, 26.3));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('My Location'), findsNothing);

    // Resolve the pending fetch so no future is left dangling past the test.
    repository.completer.complete(
      SeaCondition(
        waveHeight: 0.5,
        waveDirection: 90,
        wavePeriod: 5,
        seaSurfaceTemperature: 22,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'HomeScreen shows a clear error message when marine data fails to load',
    (WidgetTester tester) async {
      final provider = MarineProvider(_FailingMarineRepository('boom'));

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: provider,
          ),
        ),
      );
      await provider.fetchData(38.3, 26.3);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('My Location'), findsNothing);
      expect(find.textContaining('boom'), findsOneWidget);
    },
  );

  testWidgets(
    'HomeScreen shows the normal layout once marine data has loaded',
    (WidgetTester tester) async {
      final provider = MarineProvider(_SucceedingMarineRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: provider,
          ),
        ),
      );
      await provider.fetchData(38.3, 26.3);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('My Location'), findsOneWidget);
      expect(find.byType(StatTile), findsNWidgets(4));
    },
  );

  testWidgets(
    'the suggestion pill reflects real wave height/wind/rain data instead '
    'of a hardcoded string',
    (WidgetTester tester) async {
      final marineProvider = MarineProvider(_SucceedingMarineRepository());
      final weatherProvider = WeatherProvider(_SucceedingWeatherRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: marineProvider,
            weatherProvider: weatherProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fixture data (0.5m waves, 12 km/h wind, 10% rain chance) is all
      // below the "caution" thresholds, so the real verdict is "good".
      expect(find.byType(SwimSuggestionPill), findsOneWidget);
      expect(find.text('Calm seas — good time for a swim.'), findsOneWidget);
      expect(find.text('Good conditions for a swim right now'), findsNothing);
    },
  );

  testWidgets('the suggestion pill downgrades to a poor verdict once real wave '
      'height crosses the rough-conditions threshold', (
    WidgetTester tester,
  ) async {
    final marineProvider = MarineProvider(
      _FixedMarineRepository(
        SeaCondition(
          waveHeight: 1.5,
          waveDirection: 90,
          wavePeriod: 5,
          seaSurfaceTemperature: 22,
        ),
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
    await marineProvider.fetchData(38.3, 26.3);
    await tester.pump();

    expect(
      find.text('Rough conditions — best to skip swimming today.'),
      findsOneWidget,
    );
  });

  testWidgets(
    "the Home background gradient stays the navy bg.base/bg.gradientBottom "
    'pair regardless of the swim verdict (only the suggestion pill colors '
    'follow it)',
    (WidgetTester tester) async {
      Future<LinearGradient> pumpAndGetBodyGradient(
        MarineProvider provider,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              tileProvider: _FakeTileProvider(),
              marineProvider: provider,
            ),
          ),
        );
        await provider.fetchData(38.3, 26.3);
        await tester.pump();
        // The background gradient now lives on the first `Container` inside
        // the Home screen's body `Stack` (the cloud backdrop and real
        // content are stacked above it, #162), rather than on the body
        // widget itself.
        final container = tester
            .widgetList<Container>(find.byType(Container))
            .first;
        final decoration = container.decoration as BoxDecoration;
        return decoration.gradient as LinearGradient;
      }

      const expectedColors = [Color(0xFF0D1220), Color(0xFF2A3145)];

      final goodGradient = await pumpAndGetBodyGradient(
        MarineProvider(_SucceedingMarineRepository()),
      );
      expect(goodGradient.colors, expectedColors);

      final poorGradient = await pumpAndGetBodyGradient(
        MarineProvider(
          _FixedMarineRepository(
            SeaCondition(
              waveHeight: 1.5,
              waveDirection: 90,
              wavePeriod: 5,
              seaSurfaceTemperature: 22,
            ),
          ),
        ),
      );
      expect(poorGradient.colors, expectedColors);
    },
  );

  testWidgets(
    'a real pull-to-refresh drag on the Home screen re-triggers the marine '
    'fetch without tearing down the scroll view while it is pending',
    (WidgetTester tester) async {
      final repository = _SequentialMarineRepository();
      final provider = MarineProvider(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: provider,
          ),
        ),
      );

      // Initial load.
      unawaited(provider.fetchData(38.3, 26.3));
      await tester.pump();
      expect(repository.calls, hasLength(1));
      repository.calls[0].complete(_fakeSeaCondition());
      await tester.pumpAndSettle();
      expect(find.text('My Location'), findsOneWidget);

      // A real drag-down gesture over the scroll view, not calling
      // RefreshIndicator.onRefresh directly, so this also catches the
      // gesture itself being broken (e.g. by the content being replaced
      // mid-drag). Anchored on the 'My Location' text rather than the
      // scroll view itself: the scroll view's render box spans the whole
      // screen including the map card, and FlutterMap's own gesture
      // recognizer would otherwise swallow the drag.
      await tester.fling(find.text('My Location'), const Offset(0, 300), 1000);
      await tester.pump();
      // RefreshIndicator only invokes onRefresh once its own arm/snap
      // animation finishes, which takes a few more frames after the drag
      // itself settles.
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.calls, hasLength(2));
      // The refresh is in flight: the screen must keep showing the loaded
      // content (and the RefreshIndicator driving the refresh) instead of
      // swapping to the full-screen loading shell, which would tear down
      // the very gesture that triggered it and reset the scroll position.
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('My Location'), findsOneWidget);

      repository.calls[1].complete(_fakeSeaCondition());
      await tester.pumpAndSettle();
      expect(find.text('My Location'), findsOneWidget);
    },
  );

  testWidgets(
    'a pull-to-refresh gesture on the Home screen is a no-op with no MarineProvider',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(tileProvider: _FakeTileProvider())),
      );
      await tester.pump();

      await tester.fling(find.text('My Location'), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(find.text('My Location'), findsOneWidget);
    },
  );

  testWidgets(
    'the Home screen shows an inline error shell only on the first load, '
    'never mid-refresh',
    (WidgetTester tester) async {
      final repository = _SequentialMarineRepository();
      final provider = MarineProvider(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: provider,
          ),
        ),
      );

      unawaited(provider.fetchData(38.3, 26.3));
      await tester.pump();
      repository.calls[0].complete(_fakeSeaCondition());
      await tester.pumpAndSettle();
      expect(find.text('My Location'), findsOneWidget);

      // A refresh that fails must not replace already-loaded content with
      // the full-screen error shell (which has no RefreshIndicator to
      // retry from).
      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final refreshFuture = refreshIndicator.onRefresh();
      repository.calls[1].completeError(Exception('boom'));
      await refreshFuture;
      await tester.pump();

      expect(find.text('My Location'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    },
  );

  testWidgets('tapping the search entry point opens SearchScreen, and the back '
      'chevron returns to HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(tileProvider: _FakeTileProvider())),
    );
    await tester.pump();

    expect(find.byType(SearchScreen), findsNothing);

    await tester.tap(find.byKey(const Key('home-search-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SearchScreen), findsNothing);
  });

  testWidgets(
    'the search entry point wires up a real FavoritesProvider, so results '
    'show a favorite heart',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(tileProvider: _FakeTileProvider())),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('home-search-entry')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsWidgets);
    },
  );

  testWidgets(
    'tapping the pressure stat tile opens PressureDetailScreen with the '
    'real weather data, and the back button returns to HomeScreen',
    (WidgetTester tester) async {
      final weatherProvider = WeatherProvider(_SucceedingWeatherRepository());

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

      expect(find.byType(PressureDetailScreen), findsNothing);

      // The pressure tile sits below the fold on the test surface's fixed
      // 800x600 size, so it needs scrolling into view before it can be hit.
      await tester.ensureVisible(find.text('1013 hPa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1013 hPa'));
      await tester.pumpAndSettle();

      expect(find.byType(PressureDetailScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      // The hero value carries over the real current pressure reading.
      expect(find.text('1013'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(PressureDetailScreen), findsNothing);
    },
  );

  group('nearbyBeachesProvider wiring', () {
    testWidgets(
      'HomeScreen fetches nearby beaches for the fixed place center on init',
      (WidgetTester tester) async {
        final nearbyBeachesProvider = _fixtureNearbyBeachesProvider();
        addTearDown(nearbyBeachesProvider.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              tileProvider: _FakeTileProvider(),
              nearbyBeachesProvider: nearbyBeachesProvider,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(nearbyBeachesProvider.status, NearbyBeachesStatus.loaded);
        expect(nearbyBeachesProvider.beaches, isNotEmpty);
      },
    );

    testWidgets(
      'HomeScreen forwards nearbyBeachesProvider to LocationMapCard for '
      'tap-to-pick',
      (WidgetTester tester) async {
        final nearbyBeachesProvider = _fixtureNearbyBeachesProvider();
        addTearDown(nearbyBeachesProvider.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              tileProvider: _FakeTileProvider(),
              nearbyBeachesProvider: nearbyBeachesProvider,
            ),
          ),
        );
        // Lets the postFrameCallback-triggered pickLocation's debounce timer
        // fire and resolve, so none is left pending when the test ends.
        await tester.pumpAndSettle();

        final mapCard = tester.widget<LocationMapCard>(
          find.byType(LocationMapCard),
        );
        expect(mapCard.nearbyBeachesProvider, same(nearbyBeachesProvider));
      },
    );

    testWidgets(
      'opening Search from Home forwards the nearbyBeachesProvider, so real '
      'beach-info fields show on the real navigation path',
      (WidgetTester tester) async {
        final nearbyBeachesProvider = _fixtureNearbyBeachesProvider();
        addTearDown(nearbyBeachesProvider.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              tileProvider: _FakeTileProvider(),
              nearbyBeachesProvider: nearbyBeachesProvider,
            ),
          ),
        );
        // Lets the postFrameCallback-triggered fetch resolve before Search
        // is opened, so the real list is already loaded.
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home-search-entry')));
        await tester.pumpAndSettle();

        expect(find.byType(SearchScreen), findsOneWidget);
        expect(find.text('Fixture Beach'), findsOneWidget);
        final card = tester.widget<BeachResultCard>(
          find.byType(BeachResultCard),
        );
        expect(card.waveHeightMeters, closeTo(0.8, 0.001));
        expect(card.waterTemperatureCelsius, closeTo(25.0, 0.001));
      },
    );

    testWidgets("Search's pull-to-refresh calls onRefresh, which re-invokes "
        'nearbyBeachesProvider.pickLocation for the fixed place center', (
      WidgetTester tester,
    ) async {
      final nearbyBeachesProvider = _fixtureNearbyBeachesProvider();
      addTearDown(nearbyBeachesProvider.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            nearbyBeachesProvider: nearbyBeachesProvider,
          ),
        ),
      );
      // Lets the postFrameCallback-triggered initial fetch resolve.
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-search-entry')));
      await tester.pumpAndSettle();

      // A second pickLocation for the exact same spot still re-runs the
      // whole fetch (MarineBatchService's own 1-hour cache means it may
      // not necessarily re-hit the network), which always notifies
      // listeners at least twice: once entering NearbyBeachesStatus.loading
      // and once resolving back to loaded. Counting notifications (rather
      // than network calls) is what actually distinguishes a real
      // pickLocation call from onRefresh being a silent no-op.
      var notifications = 0;
      nearbyBeachesProvider.addListener(() => notifications++);

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.descendant(
          of: find.byType(SearchScreen),
          matching: find.byType(RefreshIndicator),
        ),
      );
      // The onRefresh closure itself only calls pickLocation() (it does
      // not await the debounced fetch), so it resolves immediately;
      // pumpAndSettle afterwards is what lets the debounce timer fire
      // and the resulting fetch actually run to completion.
      await refreshIndicator.onRefresh();
      await tester.pumpAndSettle();

      expect(notifications, greaterThanOrEqualTo(2));
      expect(nearbyBeachesProvider.status, NearbyBeachesStatus.loaded);
    });

    testWidgets('given no nearby beaches, HomeScreen passes a null '
        'seawardBearingDegrees to SeaConditionsRow (never a fabricated one)', (
      WidgetTester tester,
    ) async {
      final marineProvider = await aLoadedMarineProvider(
        SeaCondition(currentDirection: 90),
      );
      addTearDown(marineProvider.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            tileProvider: _FakeTileProvider(),
            marineProvider: marineProvider,
            // No nearbyBeachesProvider at all -> no beach to derive a
            // bearing from.
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = tester.widget<SeaConditionsRow>(
        find.byType(SeaConditionsRow),
      );
      expect(row.seawardBearingDegrees, isNull);
    });

    testWidgets(
      'given a nearby beach with geometry and amenities, HomeScreen derives '
      'its seaward bearing and passes it to SeaConditionsRow',
      (WidgetTester tester) async {
        final nearbyBeachesProvider =
            _fixtureNearbyBeachesProviderWithAmenity();
        addTearDown(nearbyBeachesProvider.dispose);
        final marineProvider = await aLoadedMarineProvider(
          SeaCondition(currentDirection: 90),
        );
        addTearDown(marineProvider.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              tileProvider: _FakeTileProvider(),
              marineProvider: marineProvider,
              nearbyBeachesProvider: nearbyBeachesProvider,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(nearbyBeachesProvider.beaches, isNotEmpty);
        final expectedBearing = seawardBearingFromGeometry(
          nearbyBeachesProvider.beaches.first,
        );
        expect(expectedBearing, isNotNull);

        final row = tester.widget<SeaConditionsRow>(
          find.byType(SeaConditionsRow),
        );
        expect(row.seawardBearingDegrees, expectedBearing);
      },
    );

    testWidgets(
      'given several nearby beaches where the nearest one is NOT first in '
      'the list, HomeScreen still derives the bearing from the actually '
      'nearest beach (not list order)',
      (WidgetTester tester) async {
        final client = _FixtureNetworkClientTwoBeaches();
        final nearbyBeachesProvider = NearbyBeachesProvider(
          OverpassService(client),
          BeachCache(_mockPrefs!),
          MarineBatchService(client),
          debounceDuration: const Duration(milliseconds: 1),
        );
        addTearDown(nearbyBeachesProvider.dispose);
        final marineProvider = await aLoadedMarineProvider(
          SeaCondition(currentDirection: 90),
        );
        addTearDown(marineProvider.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              tileProvider: _FakeTileProvider(),
              marineProvider: marineProvider,
              nearbyBeachesProvider: nearbyBeachesProvider,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(nearbyBeachesProvider.beaches, hasLength(2));
        // "Far Beach" is listed first in the fixture response but is ~100
        // km from _placeCenter; "Fixture Beach" is listed second but sits
        // right at _placeCenter, so it is the real nearest beach.
        expect(nearbyBeachesProvider.beaches.first.name, 'Far Beach');
        final nearestBeach = nearbyBeachesProvider.beaches.firstWhere(
          (b) => b.name == 'Fixture Beach',
        );
        final expectedBearing = seawardBearingFromGeometry(nearestBeach);
        expect(expectedBearing, isNotNull);

        final row = tester.widget<SeaConditionsRow>(
          find.byType(SeaConditionsRow),
        );
        expect(row.seawardBearingDegrees, expectedBearing);
      },
    );
  });

  group('selected-location data path (#157)', () {
    testWidgets(
      'given a user taps the map, HomeScreen re-fetches weather and marine '
      'data for the tapped point (not the fixed Çeşme default) and updates '
      'the header',
      (WidgetTester tester) async {
        final weatherRepository = _RecordingWeatherRepository([
          _fakeWeatherCondition(),
          WeatherCondition(temperature: 31, windSpeed: 8, weatherCode: 1),
        ]);
        final marineRepository = _RecordingMarineRepository([
          SeaCondition(waveHeight: 0.2),
          SeaCondition(waveHeight: 1.8),
        ]);
        final weatherProvider = WeatherProvider(weatherRepository);
        final marineProvider = MarineProvider(marineRepository);

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              tileProvider: _FakeTileProvider(),
              weatherProvider: weatherProvider,
              marineProvider: marineProvider,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial load: weather fetched once, for the Çeşme first-run
        // default. Marine data is never auto-fetched on the initial load
        // (only an explicit refresh/pick triggers it — see
        // HomeScreen._fetchWeatherAndMarine's call sites), so it starts
        // empty. The place name shows twice (the header subtitle and the
        // map card's own location bar both render the same selected name).
        expect(weatherRepository.calls, hasLength(1));
        expect(marineRepository.calls, isEmpty);
        expect(find.text('27°'), findsOneWidget);
        expect(find.text('Çeşme, İzmir'), findsNWidgets(2));

        // Tapping the widget's own center taps the map's visual center
        // (see location_map_card_picker_test.dart): flutter_map's own
        // lat/lng <-> pixel projection round-trip introduces enough
        // floating-point noise that the resulting point is a genuinely
        // distinct double from the original, even though both describe
        // "the same" spot — exactly what's needed to prove a *new* fetch
        // happened, rather than the old data just being repainted.
        await tester.tap(find.byType(FlutterMap));
        // flutter_map delays a single tap by its double-tap-to-zoom window
        // before firing onTap (see location_map_card_picker_test.dart).
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Weather was asked again, for a new (different) point — this is
        // what actually proves the pick re-fetched real data rather than
        // just repainting the same values. Marine data, never fetched
        // before, is now fetched for that very same picked point too (the
        // acceptance criterion's "waves" changing on a pick).
        expect(weatherRepository.calls, hasLength(2));
        expect(weatherRepository.calls[1], isNot(weatherRepository.calls[0]));
        expect(marineRepository.calls, hasLength(1));
        expect(marineRepository.calls.single, weatherRepository.calls[1]);

        // The header now reflects the newly picked point's data, not the
        // original Çeşme fetch's.
        expect(find.text('31°'), findsOneWidget);
        expect(find.text('27°'), findsNothing);
        // No reverse geocode is available for a bare map tap, so the place
        // name falls back to formatted coordinates instead of staying on
        // the Çeşme default.
        expect(find.text('Çeşme, İzmir'), findsNothing);
      },
    );

    testWidgets(
      'a picked location is persisted and restored by a later HomeScreen '
      'mount (app restart)',
      (WidgetTester tester) async {
        final firstWeatherRepository = _RecordingWeatherRepository([
          _fakeWeatherCondition(),
          _fakeWeatherCondition(uvIndex: 9.9),
        ]);
        final firstWeatherProvider = WeatherProvider(firstWeatherRepository);

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              tileProvider: _FakeTileProvider(),
              weatherProvider: firstWeatherProvider,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FlutterMap));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(firstWeatherRepository.calls, hasLength(2));
        final pickedPoint = firstWeatherRepository.calls[1];

        // "Restart": a brand new HomeScreen/WeatherProvider mounted against
        // the same (mocked) SharedPreferences backing store the first one
        // just wrote to.
        final secondWeatherRepository = _RecordingWeatherRepository([
          _fakeWeatherCondition(),
        ]);
        final secondWeatherProvider = WeatherProvider(
          secondWeatherRepository,
        );

        // A distinct key forces Flutter to tear down the first HomeScreen's
        // State (and its in-memory _selectedLocation) and mount a brand new
        // one instead of just updating the existing element in place — the
        // only way a widget test can simulate a real app restart, where
        // SharedPreferences is the only thing that survives.
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              key: const ValueKey('restarted-home-screen'),
              tileProvider: _FakeTileProvider(),
              weatherProvider: secondWeatherProvider,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(secondWeatherRepository.calls, hasLength(1));
        expect(
          secondWeatherRepository.calls.single.$1,
          closeTo(pickedPoint.$1, 0.0001),
        );
        expect(
          secondWeatherRepository.calls.single.$2,
          closeTo(pickedPoint.$2, 0.0001),
        );
        // The restored pick's place name (formatted coordinates) survives
        // too, not just its raw lat/lon — the Çeşme default never reappears
        // once a pick has been made and persisted.
        expect(find.text('Çeşme, İzmir'), findsNothing);
      },
    );
  });
}
