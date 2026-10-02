import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repositories/marine_repository.dart';
import 'data/repositories/weather_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/beach_cache.dart';
import 'data/services/geocoding_service.dart';
import 'data/services/marine_batch_service.dart';
import 'data/services/overpass_service.dart';
import 'data/services/weather_api_service.dart';
import 'logic/providers/marine_provider.dart';
import 'logic/providers/nearby_beaches_provider.dart';
import 'logic/providers/place_search_provider.dart';
import 'logic/providers/unit_preferences_provider.dart';
import 'logic/providers/weather_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  // Required before any plugin platform-channel call (here,
  // SharedPreferences.getInstance()) made ahead of runApp(), which would
  // otherwise initialize the binding itself.
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final httpClient = http.Client();
  final nearbyBeachesProvider = NearbyBeachesProvider(
    OverpassService(httpClient),
    BeachCache(prefs),
    MarineBatchService(httpClient),
  );
  runApp(
    MarineApp(
      unitPreferencesProvider: UnitPreferencesProvider(prefs),
      nearbyBeachesProvider: nearbyBeachesProvider,
      placeSearchProvider: PlaceSearchProvider(GeocodingService(httpClient)),
    ),
  );
}

class MarineApp extends StatelessWidget {
  const MarineApp({
    super.key,
    this.tileProvider,
    this.unitPreferencesProvider,
    this.nearbyBeachesProvider,
    this.placeSearchProvider,
  });

  /// Overridable so integration tests can avoid the real tile network.
  final TileProvider? tileProvider;

  /// Drives the metric/imperial toggle on both Home and Search. Null (the
  /// default for any existing call site that doesn't pass one, e.g. the
  /// integration tests) hides the toggle and renders every value in metric,
  /// unchanged from before.
  final UnitPreferencesProvider? unitPreferencesProvider;

  /// Drives the map's tap-to-pick/beach overlay and the Search screen's
  /// real results list. Null (the default for any existing call site that
  /// doesn't pass one, e.g. most widget/integration tests) disables
  /// tap-to-pick and falls back to the static placeholder beach list,
  /// unchanged from before.
  final NearbyBeachesProvider? nearbyBeachesProvider;

  /// Forwarded to `HomeScreen`/`SearchScreen` for real-place search by
  /// name. Null (the default for any existing call site that doesn't pass
  /// one, e.g. most widget/integration tests) hides Search's "Places"
  /// section, unchanged from before.
  final PlaceSearchProvider? placeSearchProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MarineProvider(MarineRepository(MarineApiService())),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              WeatherProvider(WeatherRepository(WeatherApiService())),
        ),
      ],
      child: Consumer2<MarineProvider, WeatherProvider>(
        builder: (context, marineProvider, weatherProvider, _) => MaterialApp(
          title: 'Marine Safety',
          home: HomeScreen(
            tileProvider: tileProvider,
            marineProvider: marineProvider,
            weatherProvider: weatherProvider,
            unitPreferencesProvider: unitPreferencesProvider,
            nearbyBeachesProvider: nearbyBeachesProvider,
            placeSearchProvider: placeSearchProvider,
          ),
        ),
      ),
    );
  }
}
