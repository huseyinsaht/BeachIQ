import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repositories/marine_repository.dart';
import 'data/repositories/weather_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/bathymetry_service.dart';
import 'data/services/beach_cache.dart';
import 'data/services/depth_cache.dart';
import 'data/services/device_location_service.dart';
import 'data/services/geocoding_service.dart';
import 'data/services/marine_batch_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/overpass_service.dart';
import 'data/services/reverse_geocode_cache.dart';
import 'data/services/reverse_geocoding_service.dart';
import 'data/services/weather_api_service.dart';
import 'logic/providers/condition_alert_dispatcher.dart';
import 'logic/providers/depth_provider.dart';
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
  final depthProvider = DepthProvider(
    BathymetryService(httpClient),
    DepthCache(prefs),
  );
  // Issue #254: device location (opt-in, "Use my location" only) and
  // reverse geocoding (device-location/map-tap picks), both behind small
  // interfaces so no test ever touches real GPS hardware or a real
  // platform geocoder.
  final deviceLocationService = DeviceLocationService(
    GeolocatorDeviceLocationSource(),
  );
  final reverseGeocodingService = ReverseGeocodingService(
    GeocodingPlacemarkLookup(),
    ReverseGeocodeCache(prefs),
  );

  // Built here (rather than left to MarineApp's own default) so the
  // condition-alert dispatcher below can listen to the exact same
  // long-lived instances that end up wired into the widget tree.
  final marineProvider = MarineProvider(MarineRepository(MarineApiService()));
  final weatherProvider = WeatherProvider(
    WeatherRepository(WeatherApiService()),
  );

  // Issue #221: wires real foreground notification delivery onto #87's pure
  // "conditions turned favorable" trigger decision. Out of scope here (see
  // the issue): true background delivery while the app isn't open, and a
  // settings screen for the alerts-enabled toggle (it's persisted and
  // defaults to on, but nothing in the UI flips it yet).
  // Not awaited: `NotificationService.show` already lazily calls `init()`
  // if it hasn't run yet, so blocking app startup on the permission prompt
  // (or letting a plugin exception there stop the app from launching) is
  // unnecessary. Kicking it off here just means the permission prompt
  // likely appears sooner rather than on the first alert.
  final notificationService = NotificationService();
  unawaited(notificationService.init());
  ConditionAlertDispatcher(
    weatherProvider: weatherProvider,
    marineProvider: marineProvider,
    notificationService: notificationService,
    prefs: prefs,
  ).start();

  runApp(
    MarineApp(
      marineProvider: marineProvider,
      weatherProvider: weatherProvider,
      unitPreferencesProvider: UnitPreferencesProvider(prefs),
      nearbyBeachesProvider: nearbyBeachesProvider,
      placeSearchProvider: PlaceSearchProvider(GeocodingService(httpClient)),
      depthProvider: depthProvider,
      deviceLocationService: deviceLocationService,
      reverseGeocodingService: reverseGeocodingService,
    ),
  );
}

class MarineApp extends StatelessWidget {
  const MarineApp({
    super.key,
    this.tileProvider,
    this.marineProvider,
    this.weatherProvider,
    this.unitPreferencesProvider,
    this.nearbyBeachesProvider,
    this.placeSearchProvider,
    this.depthProvider,
    this.deviceLocationService,
    this.reverseGeocodingService,
  });

  /// Overridable so integration tests can avoid the real tile network.
  final TileProvider? tileProvider;

  /// The marine-data provider to use. Null (the default for any existing
  /// call site, e.g. the widget/integration tests) falls back to building
  /// one from the real repository/API service here, unchanged from before
  /// this provider became overridable (#221 — so `main()` can hand in the
  /// same instance its `ConditionAlertDispatcher` listens to).
  final MarineProvider? marineProvider;

  /// The weather-data provider to use, with the same null-falls-back-to-the
  /// -real-thing behavior as [marineProvider] above.
  final WeatherProvider? weatherProvider;

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

  /// Drives `HomeScreen`'s water-depth / shallow-entry stat tile (issue
  /// #217). Null (the default for any existing call site that doesn't
  /// pass one, e.g. most widget/integration tests) renders that tile as
  /// "No data", unchanged from before.
  final DepthProvider? depthProvider;

  /// Drives `HomeScreen`'s map card overflow "Use my location" action
  /// (issue #254). Null (the default for any existing call site that
  /// doesn't pass one, e.g. most widget/integration tests) hides that
  /// entry entirely, unchanged from before this action existed.
  final DeviceLocationService? deviceLocationService;

  /// Resolves real place names for device-location/map-tap picks (issue
  /// #254). Null (the default for any existing call site that doesn't
  /// pass one) leaves both kinds of pick showing `formatCoordinates`,
  /// unchanged from before #254.
  final ReverseGeocodingService? reverseGeocodingService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        marineProvider != null
            ? ChangeNotifierProvider<MarineProvider>.value(
                value: marineProvider!,
              )
            : ChangeNotifierProvider<MarineProvider>(
                create: (_) =>
                    MarineProvider(MarineRepository(MarineApiService())),
              ),
        weatherProvider != null
            ? ChangeNotifierProvider<WeatherProvider>.value(
                value: weatherProvider!,
              )
            : ChangeNotifierProvider<WeatherProvider>(
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
            depthProvider: depthProvider,
            deviceLocationService: deviceLocationService,
            reverseGeocodingService: reverseGeocodingService,
          ),
        ),
      ),
    );
  }
}
