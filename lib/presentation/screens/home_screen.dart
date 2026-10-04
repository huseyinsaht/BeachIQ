import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/beach.dart';
import '../../data/models/weather_code.dart';
import '../../data/models/weather_condition.dart';
import '../../logic/forecast_alerts.dart';
import '../../logic/providers/favorites_provider.dart';
import '../../logic/providers/marine_provider.dart';
import '../../logic/providers/nearby_beaches_provider.dart';
import '../../logic/providers/place_search_provider.dart';
import '../../logic/providers/unit_preferences_provider.dart';
import '../../logic/providers/weather_provider.dart';
import '../../logic/swim_suitability.dart';
import '../../logic/unit_preferences.dart';
import '../../logic/wave_shore_relation.dart';
import '../navigation/detail_routes.dart';
import '../widgets/cloud_backdrop.dart';
import '../widgets/forecast_alert_list.dart';
import '../widgets/hourly_forecast_item.dart';
import '../widgets/location_map_card.dart';
import '../widgets/sea_conditions_row.dart';
import '../widgets/stat_tile.dart';
import '../widgets/swim_suggestion_pill.dart';
import 'search_screen.dart';

const String _noData = 'No data';

/// A location/display-name pair restored from `SharedPreferences` by
/// [_HomeScreenState._restoreSelectedLocation].
class _SavedLocation {
  const _SavedLocation(this.point, this.displayName);

  final LatLng point;
  final String displayName;
}

const Distance _distance = Distance();

/// The entry of [beaches] whose `(latitude, longitude)` is closest to
/// [point] by real distance, or null when [beaches] is empty.
/// `NearbyBeachesProvider.beaches` carries no distance ordering of its own
/// (Overpass returns elements in element-id order, not by distance), so
/// this must be computed explicitly rather than assumed from list order.
Beach? _nearestBeachTo(List<Beach> beaches, LatLng point) {
  Beach? nearest;
  var nearestMeters = double.infinity;
  for (final beach in beaches) {
    final meters = _distance(point, LatLng(beach.latitude, beach.longitude));
    if (meters < nearestMeters) {
      nearestMeters = meters;
      nearest = beach;
    }
  }
  return nearest;
}

/// Formats a temperature per [unitSystem]. Metric keeps today's exact
/// bare-degree style (no unit letter); imperial converts via
/// [celsiusToFahrenheit] and appends "F" so the active system stays
/// legible, matching [formatWindSpeed]'s existing km/h-vs-mph suffix.
String _formatTemperature(double? celsius, UnitSystem unitSystem) {
  if (celsius == null) return '--°';
  if (unitSystem == UnitSystem.imperial) {
    return '${celsiusToFahrenheit(celsius).round()}°F';
  }
  return '${celsius.round()}°';
}

String _formatWindSpeed(double? kmh, UnitSystem unitSystem) {
  if (kmh == null) return _noData;
  return formatWindSpeed(kmh, unitSystem);
}

/// Opens the Home screen's map-card overflow ("...") menu (#158): a
/// "Beaches" entry that always opens [SearchScreen] (the old standalone,
/// non-editable "Enter cities" entry point this replaces), plus a "Units"
/// entry when [unitPreferencesProvider] is supplied.
Future<void> _showMapOverflowMenu(
  BuildContext context, {
  required VoidCallback onBeaches,
  UnitPreferencesProvider? unitPreferencesProvider,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('map-overflow-beaches'),
              leading: const Icon(Icons.beach_access),
              title: const Text('Beaches'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onBeaches();
              },
            ),
            if (unitPreferencesProvider != null)
              ListTile(
                key: const Key('map-overflow-units'),
                leading: const Icon(Icons.straighten),
                title: const Text('Units'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showUnitSystemSheet(context, unitPreferencesProvider);
                },
              ),
          ],
        ),
      );
    },
  );
}

/// Opens a small bottom sheet to switch between metric and imperial units,
/// the "small toggle entry point" added to [_showMapOverflowMenu] above (an
/// identical copy of this lives in `search_screen.dart` for its own
/// header's overflow menu, matching this codebase's existing convention of
/// small per-file duplication over a shared presentation/main.dart
/// dependency).
Future<void> _showUnitSystemSheet(
  BuildContext context,
  UnitPreferencesProvider provider,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in UnitSystem.values)
              RadioListTile<UnitSystem>(
                title: Text(
                  option == UnitSystem.metric
                      ? 'Metric (m, °C, km/h)'
                      : 'Imperial (ft, °F, mph)',
                ),
                value: option,
                groupValue: provider.unitSystem,
                onChanged: (value) {
                  if (value != null) provider.setUnitSystem(value);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}

String _formatPercent(double? percent) {
  if (percent == null) return _noData;
  return '${percent.round()}%';
}

String _formatPressure(double? hpa) {
  if (hpa == null) return _noData;
  return '${hpa.round()} hPa';
}

String _formatUvIndex(double? uv) {
  if (uv == null) return _noData;
  return uv.toStringAsFixed(1);
}

/// Maps an Open-Meteo WMO weather code to an hourly-row icon, grouping
/// codes into the same rough categories as [weatherCodeDescription].
IconData _iconForWeatherCode(int code) {
  if (code == 0 || code == 1) return Icons.wb_sunny;
  if (code == 2) return Icons.wb_cloudy;
  if (code == 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.foggy;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return Icons.grain;
  }
  if (code >= 71 && code <= 86) return Icons.ac_unit;
  if (code == 95 || code == 96 || code == 99) return Icons.thunderstorm;
  return Icons.wb_cloudy;
}

/// The first hourly entry is labelled "Now" (it's the closest forecast
/// point to the current time); later entries show their clock hour.
String _hourLabel(DateTime time, {required bool isFirst}) {
  if (isFirst) return 'Now';
  final hour = time.hour;
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour$period';
}

/// Open-Meteo's `hourly` section returns a full day of entries starting at
/// local midnight, not from the current time — so `hourly.first` is
/// usually hours in the past by the time this renders. Slices down to the
/// entry matching (or immediately preceding) [now] onward, capped to the
/// next 24 entries so the row doesn't scroll through an entire remaining
/// day. Assumes [hourly] is sorted ascending by time, as the API returns it.
List<WeatherHourly> _upcomingHourly(List<WeatherHourly> hourly, DateTime now) {
  if (hourly.isEmpty) return hourly;
  var startIndex = 0;
  for (var i = 0; i < hourly.length; i++) {
    if (hourly[i].time.isAfter(now)) break;
    startIndex = i;
  }
  final upcoming = hourly.sublist(startIndex);
  return upcoming.length > 24 ? upcoming.sublist(0, 24) : upcoming;
}

/// The Home / location-detail screen, per docs/design.md § "Screen: Home /
/// location detail": a header, condition row, [LocationMapCard], a smart
/// suggestion pill, a 2x2 [StatTile] grid, and a scrollable hourly row of
/// [HourlyForecastItem]s.
///
/// The header, stat grid and hourly row are bound to [WeatherProvider]'s
/// data, fetched for the currently *selected* location (#157): a point the
/// user picked on [LocationMapCard] or restored from a previous session via
/// `SharedPreferences`, never a fixed city — Çeşme is only the first-run
/// default before anything has ever been picked. [MarineProvider] drives
/// the loading/error states (#69) and, once loaded, the [SeaConditionsRow]
/// under the smart suggestion pill (#163). Between the pill and the Sea
/// section/stat grid sits [ForecastAlertList] (#169): upcoming heads-ups
/// built from both providers' hourly series via `buildForecastAlerts`,
/// hidden entirely (no gap) whenever there are none.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.tileProvider,
    this.marineProvider,
    this.weatherProvider,
    this.unitPreferencesProvider,
    this.nearbyBeachesProvider,
    this.placeSearchProvider,
    this.now,
  });

  /// Overridable so widget tests can avoid hitting the real tile network.
  final TileProvider? tileProvider;

  /// Drives the loading/error states below. Null (the default for any
  /// existing call site that doesn't pass one) renders the normal loaded
  /// layout, unchanged from before.
  final MarineProvider? marineProvider;

  /// Drives the header, stat grid and hourly row's real values. Null (the
  /// default) renders every value as "No data"/"--°" instead of fetching.
  final WeatherProvider? weatherProvider;

  /// Drives the metric/imperial unit toggle, formatting the header/hourly
  /// temperatures and the wind speed stat tile accordingly. Null (the
  /// default) hides the map card's overflow toggle and renders every
  /// value in metric, unchanged from before.
  final UnitPreferencesProvider? unitPreferencesProvider;

  /// Drives the map card's tap-to-pick/beach overlay and is forwarded to
  /// `SearchScreen` for its real results list. Null (the default) disables
  /// tap-to-pick on the map and falls back to the static placeholder beach
  /// list on Search, unchanged from before.
  final NearbyBeachesProvider? nearbyBeachesProvider;

  /// Forwarded to `SearchScreen` for its real-place search ("Places"
  /// section). Null (the default) hides that section on Search, unchanged
  /// from before.
  final PlaceSearchProvider? placeSearchProvider;

  /// Overridable "current time" source for the hourly row's start-of-list
  /// trimming (see [_upcomingHourly]), so widget tests can pin it instead
  /// of depending on the real clock. Defaults to [DateTime.now].
  final DateTime Function()? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _bgBase = Color(0xFF0D1220);
  static const _bgGradientBottom = Color(0xFF2A3145);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF8B93A6);

  /// The first-run default, per docs/design.md — used only until the user
  /// has ever picked a location (on the map or via search) or one was
  /// restored from a previous session; see [_restoreSelectedLocation].
  static final _cesmeDefault = const LatLng(38.3220, 26.3260);
  static const _cesmeDefaultName = 'Çeşme, İzmir';

  static const _prefsLatKey = 'home_selected_location_lat';
  static const _prefsLonKey = 'home_selected_location_lon';
  static const _prefsNameKey = 'home_selected_location_name';

  /// The location every fetch (weather, marine, nearby beaches) and the
  /// header/map-card place name are bound to. Starts at [_cesmeDefault] and
  /// is replaced either by a restored pick (see [_restoreSelectedLocation])
  /// shortly after the first frame, or by the user tapping the map (see
  /// [_handleLocationPicked]) — never read back to [_cesmeDefault] once
  /// either of those has happened.
  LatLng _selectedLocation = _cesmeDefault;
  String _placeName = _cesmeDefaultName;

  /// Guards [_openSearch] against a fast double-tap pushing two
  /// `SearchScreen`s while the first tap's `SharedPreferences.getInstance()`
  /// await is still pending.
  bool _openingSearch = false;

  /// True once [build] has ever seen [MarineProvider.currentData] non-null
  /// for this screen instance. The full-screen loading/error shell (see
  /// [build]) is only for the very first load, before anything has ever
  /// been shown — a later map pick re-fetching for a new location must
  /// keep the header/map card on screen (with the new place name already
  /// visible) instead of tearing the whole screen down again (#213).
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    widget.marineProvider?.addListener(_onProviderChanged);
    widget.weatherProvider?.addListener(_onProviderChanged);
    widget.unitPreferencesProvider?.addListener(_onProviderChanged);
    // Needed so the Sea section's shore-relation bearing (derived from
    // nearbyBeachesProvider.beaches, see seawardBearingDegrees below)
    // actually appears once the beaches list resolves — without this,
    // HomeScreen never rebuilds after the async pickLocation() call below
    // completes.
    widget.nearbyBeachesProvider?.addListener(_onProviderChanged);
    // Deferred to after the first frame: HomeScreen is built inside the
    // Consumer2<MarineProvider, WeatherProvider> that also listens to
    // WeatherProvider (see MarineApp), so calling fetchData synchronously
    // here would notify that ancestor while it is still building this very
    // subtree ("setState()/markNeedsBuild() called during build").
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _SavedLocation? restored;
      try {
        restored = await _restoreSelectedLocation();
      } catch (_) {
        // A persisted pick is a nice-to-have, not essential: if
        // SharedPreferences itself is unavailable, the screen must still
        // load real data for the Çeşme default below rather than fail to
        // fetch anything at all.
        restored = null;
      }
      if (!mounted) return;
      if (restored != null) {
        setState(() {
          _selectedLocation = restored!.point;
          _placeName = restored.displayName;
        });
      }
      // Fire-and-forget: this screen doesn't need to wait on the refresh
      // before continuing, and any failure already surfaces through
      // weatherProvider's own error state.
      unawaited(
        widget.weatherProvider?.fetchData(
          _selectedLocation.latitude,
          _selectedLocation.longitude,
        ),
      );
      widget.nearbyBeachesProvider?.pickLocation(_selectedLocation);
    });
  }

  /// Reads back a location saved by [_persistSelectedLocation] in an
  /// earlier session, or null on a first run (nothing saved yet) — in which
  /// case [_cesmeDefault] stays as-is.
  Future<_SavedLocation?> _restoreSelectedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_prefsLatKey);
    final lon = prefs.getDouble(_prefsLonKey);
    if (lat == null || lon == null) return null;
    final point = LatLng(lat, lon);
    final name = prefs.getString(_prefsNameKey) ?? formatCoordinates(point);
    return _SavedLocation(point, name);
  }

  /// Persists [point]/[displayName] so [_restoreSelectedLocation] brings
  /// the same pick back on the next app start (acceptance criterion: "The
  /// last picked location survives an app restart").
  Future<void> _persistSelectedLocation(
    LatLng point,
    String displayName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsLatKey, point.latitude);
      await prefs.setDouble(_prefsLonKey, point.longitude);
      await prefs.setString(_prefsNameKey, displayName);
    } catch (_) {
      // Persisting the pick is a nice-to-have (the restart acceptance
      // criterion) — a failure here must never affect the live pick
      // itself, which has already updated and re-fetched above.
    }
  }

  /// [LocationMapCard.onLocationPicked]: a user tap re-centers the whole
  /// screen on the new point — the header, weather, marine data, hourly row
  /// and nearby-beaches overlay all re-fetch for it instead of staying on
  /// whatever was shown before (#157's main acceptance criterion).
  void _handleLocationPicked(LatLng point, String displayName) {
    setState(() {
      _selectedLocation = point;
      _placeName = displayName;
    });
    unawaited(_fetchWeatherAndMarine(point));
    unawaited(_persistSelectedLocation(point, displayName));
    // nearbyBeachesProvider.pickLocation(point) is already called directly
    // by LocationMapCard's own tap handler (it holds the provider itself);
    // calling it again here would just restart its debounce for no reason.
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherProvider != widget.weatherProvider) {
      oldWidget.weatherProvider?.removeListener(_onProviderChanged);
      widget.weatherProvider?.addListener(_onProviderChanged);
    }
    if (oldWidget.marineProvider != widget.marineProvider) {
      oldWidget.marineProvider?.removeListener(_onProviderChanged);
      widget.marineProvider?.addListener(_onProviderChanged);
    }
    if (oldWidget.unitPreferencesProvider != widget.unitPreferencesProvider) {
      oldWidget.unitPreferencesProvider?.removeListener(_onProviderChanged);
      widget.unitPreferencesProvider?.addListener(_onProviderChanged);
    }
    if (oldWidget.nearbyBeachesProvider != widget.nearbyBeachesProvider) {
      oldWidget.nearbyBeachesProvider?.removeListener(_onProviderChanged);
      widget.nearbyBeachesProvider?.addListener(_onProviderChanged);
    }
  }

  @override
  void dispose() {
    widget.marineProvider?.removeListener(_onProviderChanged);
    widget.weatherProvider?.removeListener(_onProviderChanged);
    widget.unitPreferencesProvider?.removeListener(_onProviderChanged);
    widget.nearbyBeachesProvider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  /// Rebuilds whenever the (optional) [MarineProvider] or [WeatherProvider]
  /// notifies, so the loading/error states and the real weather values stay
  /// in sync with them.
  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  /// Re-triggers the marine and weather data fetches for [point]. A no-op
  /// for whichever provider wasn't supplied (matches the existing
  /// optional-provider pattern from the loading/error states above). Shared
  /// by the pull-to-refresh gesture ([_handleRefresh], re-fetching the
  /// current [_selectedLocation]) and a fresh map pick
  /// ([_handleLocationPicked], fetching the newly picked point).
  Future<void> _fetchWeatherAndMarine(LatLng point) async {
    await Future.wait([
      widget.marineProvider?.fetchData(point.latitude, point.longitude) ??
          Future.value(),
      widget.weatherProvider?.fetchData(point.latitude, point.longitude) ??
          Future.value(),
    ]);
  }

  /// Re-triggers the marine and weather data fetches for a pull-to-refresh
  /// gesture, for the currently selected location.
  Future<void> _handleRefresh() => _fetchWeatherAndMarine(_selectedLocation);

  /// Obtains a [FavoritesProvider] (async: it needs `SharedPreferences`)
  /// and pushes [SearchScreen] with it, so the favorite hearts and the
  /// favorites-only star toggle are live on the real navigation path.
  Future<void> _openSearch(BuildContext context) async {
    if (_openingSearch) return;
    _openingSearch = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SearchScreen(
            favoritesProvider: FavoritesProvider(prefs),
            unitPreferencesProvider: widget.unitPreferencesProvider,
            nearbyBeachesProvider: widget.nearbyBeachesProvider,
            placeSearchProvider: widget.placeSearchProvider,
            onRefresh: widget.nearbyBeachesProvider == null
                ? null
                : () async => widget.nearbyBeachesProvider!.pickLocation(
                    _selectedLocation,
                  ),
          ),
        ),
      );
    } finally {
      _openingSearch = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final marineProvider = widget.marineProvider;
    // `NearbyBeachesProvider.beaches` is NOT sorted by distance anywhere
    // (Overpass returns elements in element-id order) - the nearest beach
    // must be found explicitly, by actual distance to _selectedLocation,
    // rather than assumed to be the first list entry. Null whenever there's
    // no provider or no beach was found, in which case SeaConditionsRow
    // falls back to its cardinal-only display.
    final nearestBeach = _nearestBeachTo(
      widget.nearbyBeachesProvider?.beaches ?? const [],
      _selectedLocation,
    );
    final seawardBearingDegrees = nearestBeach == null
        ? null
        : seawardBearingFromGeometry(nearestBeach);
    // Once data has loaded once, a pull-to-refresh re-fetch must not tear
    // down this screen (and the RefreshIndicator/scroll view driving that
    // very refresh) back to a full-screen shell — only the *first* load
    // (no data yet) uses the full-screen loading/error states below.
    final hasData = marineProvider?.currentData != null;
    // Only the very first load (nothing has ever rendered for this screen
    // instance) uses the full-screen shell below — once real content has
    // shown once, a later map pick re-fetching for a new location keeps
    // the header/map card on screen instead of hiding them again (#213);
    // see the sectional loading/error handling further down for that case.
    final isFirstLoad = !_hasLoadedOnce;
    if (hasData) _hasLoadedOnce = true;
    if (marineProvider != null &&
        marineProvider.isLoading &&
        !hasData &&
        isFirstLoad) {
      return _buildStatusShell(
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_textPrimary),
          ),
        ),
      );
    }
    final error = marineProvider?.error;
    if (error != null && !hasData && isFirstLoad) {
      return _buildStatusShell(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load marine data.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textPrimary, fontSize: 15),
            ),
          ),
        ),
      );
    }
    final weatherProvider = widget.weatherProvider;
    final weatherData = weatherProvider?.currentData;
    // Drives the sectional loading placeholders below (hourly row, stat
    // grid): true only while a fetch is in flight for a location whose
    // data hasn't arrived yet — never while a same-location refresh keeps
    // showing the previous values (#213).
    final weatherLoading =
        weatherProvider != null &&
        weatherProvider.isLoading &&
        weatherData == null;
    // Same idea as [weatherLoading], for the Sea section below.
    final marineLoading =
        marineProvider != null && marineProvider.isLoading && !hasData;
    final unitSystem =
        widget.unitPreferencesProvider?.unitSystem ?? UnitSystem.metric;
    final swimVerdict = scoreSwimSuitability(
      waveHeightM: marineProvider?.currentData?.waveHeight,
      windSpeedKmh: weatherData?.windSpeed,
      rainChancePercent: weatherData?.rainChancePercent?.round(),
    );
    final effectiveNow = (widget.now ?? DateTime.now)();
    final hourly = _upcomingHourly(
      weatherData?.hourly ?? const [],
      effectiveNow,
    );
    // #169: upcoming heads-ups for the selected location, computed fresh on
    // every build from the same WeatherProvider/MarineProvider hourly data
    // the stat grid and Sea section already use — never a hard-coded list.
    final forecastAlerts = buildForecastAlerts(
      weather: weatherData?.hourly ?? const [],
      sea: marineProvider?.currentData?.hourly ?? const [],
      now: effectiveNow,
    );
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgBase, _bgGradientBottom],
              ),
            ),
          ),
          // The faint cloud texture from docs/design.md, top-right behind
          // the header. Positioned ahead of (i.e. visually under) the real
          // content below, and `IgnorePointer`/`RepaintBoundary`-wrapped by
          // `CloudBackdrop` itself, so it never intercepts taps on anything
          // stacked above it and never repaints while that content scrolls.
          const Positioned(top: 0, right: 0, child: CloudBackdrop()),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Location',
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _placeName,
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTemperature(
                            weatherData?.temperature,
                            unitSystem,
                          ),
                          style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 44,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          weatherData != null
                              ? weatherCodeDescription(weatherData.weatherCode)
                              : _noData,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'H:${_formatTemperature(weatherData?.highTemperature, unitSystem)} '
                          'L:${_formatTemperature(weatherData?.lowTemperature, unitSystem)}',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LocationMapCard(
                      center: _selectedLocation,
                      placeName: _placeName,
                      tileProvider: widget.tileProvider,
                      nearbyBeachesProvider: widget.nearbyBeachesProvider,
                      placeSearchProvider: widget.placeSearchProvider,
                      onLocationPicked: _handleLocationPicked,
                      // #158: the standalone, non-editable "Enter cities"
                      // entry point below the map card is gone — the map
                      // card's own search icon is now the only place-search
                      // entry on Home, and `SearchScreen` (beach list,
                      // favorites, filter) stays reachable via "Beaches" in
                      // this overflow menu instead.
                      onOverflowPressed: () => _showMapOverflowMenu(
                        context,
                        onBeaches: () => _openSearch(context),
                        unitPreferencesProvider: widget.unitPreferencesProvider,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwimSuggestionPill(verdict: swimVerdict),
                    // #169: sits between the smart suggestion pill and the
                    // Sea section/stat grid, hidden entirely (no gap) when
                    // there are no upcoming alerts — see
                    // ForecastAlertList's own doc comment.
                    if (forecastAlerts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ForecastAlertList(alerts: forecastAlerts),
                    ],
                    // #213: a fetch in flight for a new pick (no data for
                    // it yet) shows a loading placeholder here instead of
                    // either the previous pick's row or nothing at all;
                    // once loaded (or when there's simply no
                    // MarineProvider), this falls back to the existing
                    // behavior unchanged.
                    if (marineLoading) ...[
                      const SizedBox(height: 20),
                      _buildSectionLoading(height: 78),
                    ] else if (marineProvider?.currentData != null) ...[
                      const SizedBox(height: 20),
                      SeaConditionsRow(
                        data: marineProvider?.currentData,
                        unitSystem: unitSystem,
                        seawardBearingDegrees: seawardBearingDegrees,
                      ),
                    ],
                    const SizedBox(height: 20),
                    // #213: same loading placeholder for the stat grid
                    // while a new pick's weather fetch is in flight, so the
                    // old place's wind/rain/pressure/UV values are never
                    // shown next to the new place name.
                    if (weatherLoading)
                      _buildSectionLoading(height: 164)
                    else
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 2.6,
                        children: [
                          StatTile(
                            icon: Icons.air,
                            label: 'Wind speed',
                            value: _formatWindSpeed(
                              weatherData?.windSpeed,
                              unitSystem,
                            ),
                            trendDirection: StatTrendDirection.up,
                            trendDelta: unitSystem == UnitSystem.imperial
                                ? '1 mph'
                                : '2 km/h',
                            onTap: () => Navigator.of(context).push(
                              buildDetailRoute(
                                DetailMetric.wind,
                                hourly: weatherData?.hourly ?? const [],
                                currentValue: weatherData?.windSpeed,
                                unitSystem: unitSystem,
                                now: widget.now,
                              ),
                            ),
                          ),
                          StatTile(
                            icon: Icons.water_drop_outlined,
                            label: 'Rain chance',
                            value: _formatPercent(
                              weatherData?.rainChancePercent,
                            ),
                            trendDirection: StatTrendDirection.down,
                            trendDelta: '3%',
                            onTap: () => Navigator.of(context).push(
                              buildDetailRoute(
                                DetailMetric.rainChance,
                                hourly: weatherData?.hourly ?? const [],
                                currentValue: weatherData?.rainChancePercent,
                                now: widget.now,
                              ),
                            ),
                          ),
                          StatTile(
                            icon: Icons.speed,
                            label: 'Pressure',
                            value: _formatPressure(weatherData?.pressureHpa),
                            trendDirection: StatTrendDirection.up,
                            trendDelta: '1 hPa',
                            onTap: () => Navigator.of(context).push(
                              buildDetailRoute(
                                DetailMetric.pressure,
                                hourly: weatherData?.hourly ?? const [],
                                currentValue: weatherData?.pressureHpa,
                                now: widget.now,
                              ),
                            ),
                          ),
                          StatTile(
                            icon: Icons.wb_sunny_outlined,
                            label: 'UV index',
                            value: _formatUvIndex(weatherData?.uvIndex),
                            trendDirection: StatTrendDirection.up,
                            trendDelta: '0.5',
                            onTap: () => Navigator.of(context).push(
                              buildDetailRoute(
                                DetailMetric.uvIndex,
                                hourly: weatherData?.hourly ?? const [],
                                currentValue: weatherData?.uvIndex,
                                now: widget.now,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: _textSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Hourly forecast',
                          style: TextStyle(color: _textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      // #213: a new pick's hourly row shows a loading
                      // placeholder instead of the previous pick's entries
                      // (or an empty-looking row) while its weather fetch
                      // is still in flight.
                      child: weatherLoading
                          ? _buildSectionLoading()
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: hourly.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 20),
                              itemBuilder: (context, index) {
                                final entry = hourly[index];
                                return HourlyForecastItem(
                                  timeLabel: _hourLabel(
                                    entry.time,
                                    isFirst: index == 0,
                                  ),
                                  icon: _iconForWeatherCode(entry.weatherCode),
                                  temperature: _formatTemperature(
                                    entry.temperature,
                                    unitSystem,
                                  ),
                                  time: entry.time,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The same spinner [_buildStatusShell] uses for the full-screen loading
  /// state, reused inline (#213) for a single section (the Sea row, the
  /// stat grid or the hourly row) while its own data is loading for a
  /// newly picked location — rather than the whole screen being replaced.
  /// [height] bounds it to that section's usual footprint; null lets it
  /// fill whatever space its parent already constrains (e.g. the hourly
  /// row's own fixed-height `SizedBox`).
  Widget _buildSectionLoading({double? height}) {
    const spinner = Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(_textPrimary),
      ),
    );
    return height == null ? spinner : SizedBox(height: height, child: spinner);
  }

  /// Wraps [child] in the same background/[SafeArea]/cloud-backdrop shell
  /// as the loaded layout (see [build]), for the loading and error states.
  Widget _buildStatusShell(Widget child) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgBase, _bgGradientBottom],
              ),
            ),
          ),
          const Positioned(top: 0, right: 0, child: CloudBackdrop()),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
