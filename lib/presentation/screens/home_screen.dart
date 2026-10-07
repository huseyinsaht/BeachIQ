import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/beach.dart';
import '../../data/models/weather_code.dart';
import '../../data/models/weather_condition.dart';
import '../../data/services/device_location_service.dart';
import '../../data/services/reverse_geocoding_service.dart';
import '../../logic/beach_gear_advisor.dart';
import '../../logic/forecast_alerts.dart';
import '../../logic/providers/depth_provider.dart';
import '../../logic/providers/favorites_provider.dart';
import '../../logic/providers/marine_provider.dart';
import '../../logic/providers/nearby_beaches_provider.dart';
import '../../logic/providers/place_search_provider.dart';
import '../../logic/providers/unit_preferences_provider.dart';
import '../../logic/providers/weather_provider.dart';
import '../../logic/rain_status.dart';
import '../../logic/shallow_entry.dart';
import '../../logic/shallow_entry_status.dart';
import '../../logic/swim_suitability.dart';
import '../../logic/unit_preferences.dart';
import '../../logic/uv_band.dart';
import '../../logic/wave_shore_relation.dart';
import '../../logic/wind_status.dart';
import '../navigation/detail_routes.dart';
import '../widgets/beach_result_card.dart';
import '../widgets/cloud_backdrop.dart';
import '../widgets/forecast_alert_list.dart';
import '../widgets/hourly_forecast_item.dart';
import '../widgets/location_map_card.dart';
import '../widgets/stat_tile.dart';
import '../widgets/stat_tile_group.dart';
import '../widgets/swim_suggestion_pill.dart';
import 'search_screen.dart';

const String _noData = 'No data';

/// Maps a compass bearing (degrees clockwise from true north, any range —
/// callers may pass values outside 0-360, e.g. close to a wrap-around like
/// 350 -> 360) to its nearest 8-point cardinal label, for the Current
/// group's direction tiles (issue #251, moved here from the pre-#251
/// `SeaConditionsRow`).
///
/// Boundaries sit at the midpoints between points (22.5° wide either side
/// of N/NE/E/.../NW), so e.g. 350° (within 10° of north) resolves to "N".
String _seaCardinalLabel(double degrees) {
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final normalized = ((degrees % 360) + 360) % 360;
  final index = ((normalized + 22.5) / 45).floor() % 8;
  return points[index];
}

/// Formats [waveDirectionDegrees] per [SeaCondition.waveDirection]'s
/// meteorological "coming from" convention, e.g. `"from NW"`.
String _seaWaveDirectionLabel(double? waveDirectionDegrees) {
  if (waveDirectionDegrees == null) return _noData;
  return 'from ${_seaCardinalLabel(waveDirectionDegrees)}';
}

/// Formats [currentDirectionDegrees] per [SeaCondition.currentDirection]'s
/// oceanographic "flowing toward" convention, e.g. `"toward SE"`.
String _seaCurrentDirectionLabel(double? currentDirectionDegrees) {
  if (currentDirectionDegrees == null) return _noData;
  return 'toward ${_seaCardinalLabel(currentDirectionDegrees)}';
}

String _formatSeaWaveHeight(double? meters, UnitSystem unitSystem) {
  if (meters == null) return _noData;
  return formatWaveHeight(meters, unitSystem);
}

String _formatSeaWaterTemperature(double? celsius, UnitSystem unitSystem) {
  if (celsius == null) return _noData;
  return formatTemperature(celsius, unitSystem);
}

String _formatSeaCurrentSpeed(double? kmh, UnitSystem unitSystem) {
  if (kmh == null) return _noData;
  return formatWindSpeed(kmh, unitSystem);
}

/// The short suffix shown under the current-direction tile's value once a
/// [ShoreRelation] is known (i.e. a seaward bearing was derived for the
/// selected beach). [ShoreRelation.awayFromShore] gets a stronger warning
/// ("stay close!") since it signals drift-out/rip-current risk — per issue
/// #251, this is the Current group's own "status word" for that tile (the
/// wave-direction tile has no defined status at all and shows no third
/// line, matching every other no-status metric in this grid).
String _shoreRelationLabel(ShoreRelation relation) {
  switch (relation) {
    case ShoreRelation.towardShore:
      return '(towards shore)';
    case ShoreRelation.awayFromShore:
      return '(away from shore — stay close!)';
    case ShoreRelation.alongShore:
      return '(along shore)';
  }
}

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

/// The wind speed stat tile's headline number alone (no unit) — the unit
/// is a separate [StatTile.unit] run (see [_windSpeedUnit]).
String _formatWindSpeedValue(double? kmh, UnitSystem unitSystem) {
  if (kmh == null) return _noData;
  final displayValue = unitSystem == UnitSystem.imperial ? kmhToMph(kmh) : kmh;
  return displayValue.round().toString();
}

/// The wind speed stat tile's unit, or null when there is no reading to
/// attach it to (the tile then shows the bare "No data" placeholder with
/// no unit at all).
String? _windSpeedUnit(double? kmh, UnitSystem unitSystem) {
  if (kmh == null) return null;
  return unitSystem == UnitSystem.imperial ? 'mph' : 'km/h';
}

/// Opens the Home screen's map-card overflow ("...") menu (#158): a
/// "Beaches" entry that always opens [SearchScreen] (the old standalone,
/// non-editable "Enter cities" entry point this replaces), plus a "Units"
/// entry when [unitPreferencesProvider] is supplied.
Future<void> _showMapOverflowMenu(
  BuildContext context, {
  required VoidCallback onBeaches,
  VoidCallback? onUseMyLocation,
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
            // Issue #254: an explicit, opt-in action — tapping this is the
            // *only* thing that ever triggers a location-permission
            // prompt; it never happens on app start. Null (no
            // `deviceLocationService` supplied, see `_HomeScreenState`)
            // hides the entry entirely, the same optional pattern as the
            // "Units" entry below.
            if (onUseMyLocation != null)
              ListTile(
                key: const Key('map-overflow-use-my-location'),
                leading: const Icon(Icons.my_location),
                title: const Text('Use my location'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onUseMyLocation();
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

/// The rain chance stat tile's headline number alone (no "%" unit — that
/// is a separate [StatTile.unit] run).
String _formatPercentValue(double? percent) {
  if (percent == null) return _noData;
  return percent.round().toString();
}

/// The rain chance stat tile's unit, or null when there is no reading.
String? _percentUnit(double? percent) => percent == null ? null : '%';

/// The UV index stat tile's headline number — UV index has no unit,
/// matching `uv_index_detail_screen.dart`'s own hero value.
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
    this.depthProvider,
    this.deviceLocationService,
    this.reverseGeocodingService,
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

  /// Drives the water-depth / shallow-entry stat tile (issue #217) and its
  /// detail screen. Null (the default for any existing call site that
  /// doesn't pass one) renders the tile as "No data" and disables the
  /// underlying fetch, unchanged from any other optional provider here.
  final DepthProvider? depthProvider;

  /// Drives the map card overflow menu's "Use my location" action (issue
  /// #254). Null (the default for any existing call site that doesn't
  /// pass one, e.g. most widget/integration tests) hides that entry
  /// entirely, unchanged from before this action existed — never prompts
  /// for location permission on its own.
  final DeviceLocationService? deviceLocationService;

  /// Resolves a real place name for a device-location pick and for a plain
  /// map tap (issue #254), replacing `location_map_card.dart`'s coordinate-
  /// label fallback whenever it succeeds. Null (the default for any
  /// existing call site that doesn't pass one) leaves both picks showing
  /// [formatCoordinates], unchanged from before #254.
  final ReverseGeocodingService? reverseGeocodingService;

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
  // docs/design.md `color.warning` — the same red used for the
  // away-from-shore shore-relation label, reused here for the Sea
  // section's inline error (see [_buildSectionError]).
  static const _colorWarning = Color(0xFFEF5350);

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

  /// The header's secondary line (issue #253) — the selected point's
  /// formatted coordinates, shown under [_placeName] only when they add
  /// real information. [_placeName] already IS [formatCoordinates] for a
  /// bare map tap (no reverse geocoding — see #254), so this returns `null`
  /// in that case rather than repeating the same text twice.
  String? get _headerSubtitle {
    final coordinates = formatCoordinates(_selectedLocation);
    return coordinates == _placeName ? null : coordinates;
  }

  /// The beach last picked from `SearchScreen`'s results (#214), shown
  /// highlighted on the map and as a compact info row below it. Cleared by
  /// any other kind of pick (a bare map tap, an in-map-card place search) —
  /// see [_handleLocationPicked] — since those no longer point at this
  /// specific beach.
  Beach? _selectedBeach;

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

  /// The beach [widget.depthProvider] was last asked to fetch a depth
  /// profile for (via [_maybeFetchDepthProfile], called every [build]) —
  /// `null` covers both "nothing picked yet" and "no beach to key a
  /// transect off of". Tracked so a fetch is only actually kicked off once
  /// per distinct beach rather than once per rebuild; [DepthProvider]
  /// itself also de-dupes by the same `isSameBeach` identity as a second
  /// line of defense.
  Beach? _depthRequestedBeach;

  /// Bumped on every new pick (map tap, device location, beach pick,
  /// restore) so [_resolvePlaceName]'s async reverse-geocode result can
  /// tell whether it's still resolving the *current* pick before applying
  /// itself — a stale lookup for an earlier point must never overwrite a
  /// newer pick's name, mirroring [DepthProvider]'s own request-token
  /// pattern.
  int _placeNameRequestToken = 0;

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
    // completes. The same resolved beach list is also what the water-depth
    // tile (#217) keys its own fetch off of (see
    // [_maybeFetchDepthProfile]).
    widget.nearbyBeachesProvider?.addListener(_onProviderChanged);
    widget.depthProvider?.addListener(_onProviderChanged);
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
    final token = ++_placeNameRequestToken;
    setState(() {
      _selectedLocation = point;
      _placeName = displayName;
      // Neither a bare map tap nor an in-map-card place search names a
      // specific beach — #214's highlight/info row is only for a beach
      // explicitly picked from `SearchScreen`'s results (_handleBeachPicked
      // below), so any other kind of pick must drop it.
      _selectedBeach = null;
    });
    unawaited(_fetchWeatherAndMarine(point));
    unawaited(_persistSelectedLocation(point, displayName));
    // nearbyBeachesProvider.pickLocation(point) is already called directly
    // by LocationMapCard's own tap handler (it holds the provider itself);
    // calling it again here would just restart its debounce for no reason.
    //
    // Issue #254: a place-search result already carries a real looked-up
    // name, so reverse geocoding is only worth attempting when [displayName]
    // is still the bare coordinate fallback (a plain map tap or a device-
    // location pick, both of which hand this `formatCoordinates(point)`).
    if (displayName == formatCoordinates(point)) {
      unawaited(_resolvePlaceName(point, token));
    }
  }

  /// Issue #254: looks up a real display name for [point] via
  /// [widget.reverseGeocodingService] and, if it resolves to a usable name
  /// before a newer pick supersedes [token] (see [_placeNameRequestToken]),
  /// upgrades [_placeName] from its coordinate-label fallback — without
  /// blocking [_handleLocationPicked]'s own weather/marine fetch, which
  /// has already started independently of this. A `null` result (any
  /// failure — see `ReverseGeocodingService`) leaves [_placeName] exactly
  /// as it was: the coordinate label, never a fabricated name.
  Future<void> _resolvePlaceName(LatLng point, int token) async {
    final service = widget.reverseGeocodingService;
    if (service == null) return;
    String? resolved;
    try {
      resolved = await service.resolveName(point.latitude, point.longitude);
    } catch (_) {
      resolved = null;
    }
    if (!mounted || resolved == null) return;
    if (token != _placeNameRequestToken) return; // superseded by a newer pick
    setState(() => _placeName = resolved!);
    unawaited(_persistSelectedLocation(point, resolved));
  }

  /// Issue #254's "Use my location" action: the map card overflow menu's
  /// only entry that may ever prompt for location permission, and only
  /// because the user just tapped it. On success, treats the device
  /// position exactly like a map pick ([_handleLocationPicked]: header,
  /// weather, marine data, persistence); unlike a map tap, it must also
  /// call `nearbyBeachesProvider.pickLocation` itself — nothing else does,
  /// since this pick didn't come from `LocationMapCard`'s own tap handler
  /// (matching [_handleBeachPicked]'s same explicit call for the same
  /// reason). On failure (permission denied, service off, or any other
  /// platform error) keeps the current pick untouched and shows a short,
  /// non-blocking message instead — never invents a position.
  Future<void> _handleUseMyLocation(BuildContext context) async {
    final service = widget.deviceLocationService;
    if (service == null) return;
    final result = await service.getCurrentLocation();
    if (!context.mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_deviceLocationFailureMessage(result.failure))),
      );
      return;
    }
    final point = result.position!;
    _handleLocationPicked(point, formatCoordinates(point));
    widget.nearbyBeachesProvider?.pickLocation(point);
  }

  /// The short, non-blocking message [_handleUseMyLocation] shows for each
  /// [DeviceLocationFailure] reason — never a raw exception message.
  String _deviceLocationFailureMessage(DeviceLocationFailure? failure) {
    switch (failure) {
      case DeviceLocationFailure.serviceDisabled:
        return 'Location services are turned off. Keeping your last location.';
      case DeviceLocationFailure.permissionDenied:
        return 'Location permission denied. Keeping your last location.';
      case DeviceLocationFailure.unavailable:
      case null:
        return "Couldn't get your location right now. Keeping your last location.";
    }
  }

  /// Treats a beach tapped in `SearchScreen`'s results (#214) exactly like
  /// a map pick: selected location, name, data fetch and persistence all
  /// follow the same path as [_handleLocationPicked], plus it records
  /// [_selectedBeach] so the map highlights it and a compact info row
  /// shows its details without another tap. Unlike a map tap,
  /// `nearbyBeachesProvider.pickLocation` must be called explicitly here —
  /// this pick didn't come from `LocationMapCard`'s own tap handler, which
  /// is the thing that normally does that.
  void _handleBeachPicked(Beach beach) {
    final point = LatLng(beach.latitude, beach.longitude);
    // Invalidates any reverse-geocode lookup still in flight for whatever
    // was selected before (see [_placeNameRequestToken]) — a beach pick
    // always has a real name already, so there's nothing to resolve, but a
    // late-arriving result from the previous pick must not overwrite it.
    _placeNameRequestToken++;
    setState(() {
      _selectedLocation = point;
      _placeName = beach.name;
      _selectedBeach = beach;
    });
    unawaited(_fetchWeatherAndMarine(point));
    unawaited(_persistSelectedLocation(point, beach.name));
    widget.nearbyBeachesProvider?.pickLocation(point);
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
    if (oldWidget.depthProvider != widget.depthProvider) {
      oldWidget.depthProvider?.removeListener(_onProviderChanged);
      widget.depthProvider?.addListener(_onProviderChanged);
    }
  }

  @override
  void dispose() {
    widget.marineProvider?.removeListener(_onProviderChanged);
    widget.weatherProvider?.removeListener(_onProviderChanged);
    widget.unitPreferencesProvider?.removeListener(_onProviderChanged);
    widget.nearbyBeachesProvider?.removeListener(_onProviderChanged);
    widget.depthProvider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  /// Kicks off (or skips, when nothing changed) [widget.depthProvider]'s
  /// fetch for [depthBeach] — the beach the water-depth tile/detail screen
  /// should show data for (see [build]'s own `depthBeach` local). Called
  /// once per [build] (after [_depthRequestedBeach] is compared against
  /// it), but the actual provider call is deferred to a post-frame
  /// callback: [DepthProvider.fetchForBeach] clears its `profile`
  /// synchronously and calls `notifyListeners()` before awaiting the
  /// network, and doing that *during* this screen's own build would
  /// trigger "setState()/markNeedsBuild() called during build" exactly
  /// like `initState`'s own deferred fetches above.
  void _maybeFetchDepthProfile(Beach? depthBeach) {
    final previouslyRequested = _depthRequestedBeach;
    final changed = depthBeach == null
        ? previouslyRequested != null
        : !isSameBeach(depthBeach, previouslyRequested);
    if (!changed) return;

    _depthRequestedBeach = depthBeach;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.depthProvider?.fetchForBeach(depthBeach));
    });
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
  /// Tapping a beach result pops [SearchScreen] back with that [Beach]
  /// (#214), handled below exactly like a map pick; selecting a "Places"
  /// result instead calls [_handleLocationPicked] directly (via
  /// [SearchScreen.onLocationPicked]) while [SearchScreen] stays open.
  Future<void> _openSearch(BuildContext context) async {
    if (_openingSearch) return;
    _openingSearch = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      final pickedBeach = await Navigator.of(context).push<Beach>(
        MaterialPageRoute(
          builder: (context) => SearchScreen(
            favoritesProvider: FavoritesProvider(prefs),
            unitPreferencesProvider: widget.unitPreferencesProvider,
            nearbyBeachesProvider: widget.nearbyBeachesProvider,
            placeSearchProvider: widget.placeSearchProvider,
            onLocationPicked: _handleLocationPicked,
            onRefresh: widget.nearbyBeachesProvider == null
                ? null
                : () async => widget.nearbyBeachesProvider!.pickLocation(
                    _selectedLocation,
                  ),
          ),
        ),
      );
      if (pickedBeach != null) _handleBeachPicked(pickedBeach);
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
    // #217: the water-depth tile keys off whichever beach the rest of Home
    // already treats as "the" selected beach for beach-specific data —
    // the one explicitly picked from Search when there is one, otherwise
    // the same nearest-fetched-beach the Sea section's shore-relation
    // above already uses. Triggering the actual fetch (deferred to a
    // post-frame callback) is handled separately so this stays a pure
    // computation, safe to run on every build.
    final depthBeach = _selectedBeach ?? nearestBeach;
    _maybeFetchDepthProfile(depthBeach);
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
    // A fetch for a freshly picked location that has failed, with nothing
    // to fall back to and nothing in flight — rendered inline in the Sea
    // section's place below (#228). The very first load's failure is
    // already handled by the full-screen error shell above (which returns
    // before this point), so in practice this only ever fires for a later
    // pick; computing it unconditionally (rather than gating on
    // `!isFirstLoad`) keeps it correct even if that earlier branch's
    // conditions ever change. Previously a later pick's marine error had
    // no visible rendering at all — the Sea section simply vanished next
    // to the new place name while the error was silently swallowed.
    final marineErrorMessage =
        marineProvider != null && !hasData && !marineLoading
        ? marineProvider.error
        : null;
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
    // #215: a short status word + color per stat-grid metric, computed
    // once here (not per-tile) so the Wind speed/Rain chance/UV index
    // tiles and their detail screens can never disagree on the thresholds
    // behind "Calm"/"Moderate"/etc. — every classifier is reused as-is
    // from `swim_suitability.dart`'s own thresholds
    // (`wind_status.dart`/`rain_status.dart`) or from `uv_band.dart`.
    // Pressure has no defined status word (only a trend arrow), so its
    // tile omits the chip entirely, per the issue.
    final windStatus = windStatusFor(weatherData?.windSpeed);
    final rainStatus = rainChanceStatusFor(weatherData?.rainChancePercent);
    final uvIndex = weatherData?.uvIndex;
    final uvBand = uvIndex == null ? null : uvBandFor(uvIndex);
    // #217: the water-depth tile's own status word/color, from the #216
    // shallow-entry classification — null profile (not fetched/no
    // DepthProvider) and [ShallowEntrySteepness.unknown] (not enough data)
    // both fall back to "No data" below, never a fabricated reading.
    final depthProfile = widget.depthProvider?.profile;
    final depthClassification = depthProfile == null
        ? null
        : classifyShallowEntry(depthProfile);
    final depthValue = depthClassification == null
        ? _noData
        : formatShallowEntrySummary(depthClassification, unitSystem);
    final depthStatusLabel = depthClassification == null
        ? null
        : shallowEntryStatusLabel(depthClassification.steepness);
    final depthStatusColor = depthClassification == null
        ? null
        : shallowEntryStatusColor(depthClassification.steepness);
    // #251: the Sea/Current groups' marine-driven tiles (wave height, water
    // temp, current speed/direction, wave direction) all read from this one
    // `SeaCondition?` — null whenever nothing has been fetched yet (first
    // load) or a fetch failed with nothing to fall back to, in which case
    // every tile below falls back to its own "No data" via its null-safe
    // formatter, exactly like every other field in this grid.
    final seaCondition = marineProvider?.currentData;
    // The current-direction tile's own "status word" (issue #251's Current
    // group): the shore relation derived from the nearest beach's seaward
    // bearing, when both that bearing and a current-direction reading are
    // known. Null (never an invented relation) falls back to showing no
    // third line at all, matching the pre-#251 `SeaConditionsRow` behavior.
    final currentShoreRelation =
        seawardBearingDegrees == null || seaCondition?.currentDirection == null
        ? null
        : classifyDirection(
            degrees: seaCondition!.currentDirection!,
            convention: DirectionConvention.flowingToward,
            seawardBearingDegrees: seawardBearingDegrees,
          );
    // #169/#229: upcoming heads-ups for the selected location, computed
    // fresh on every build from the same WeatherProvider/MarineProvider
    // hourly data the stat grid and Sea section already use — never a
    // hard-coded list. Restricted to the selected location's own daylight
    // (sunrise-sunset) windows when the API returned them; an empty
    // `daylightWindows` (missing from the response) leaves the list
    // unfiltered instead of dropping every alert.
    final forecastAlerts = buildForecastAlerts(
      weather: weatherData?.hourly ?? const [],
      sea: marineProvider?.currentData?.hourly ?? const [],
      daylight: weatherData?.daylightWindows ?? const [],
      now: effectiveNow,
    );
    // #229: a single "what changes in the next hour" note, based on the
    // current time rather than daylight — still shown after sunset.
    final nextHourNote = buildNextHourNote(
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
                              Text(
                                _placeName,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              // #253 (Vaen's 2026-10-06 feedback): the
                              // header used to say the hard-coded "My
                              // Location" above the real place name, which
                              // is misleading — there is no device GPS at
                              // all (see #254), so it is never actually the
                              // user's location. The place name is now the
                              // primary title; this secondary line adds the
                              // coordinates only when they say something the
                              // title doesn't already — a bare map tap's
                              // `_placeName` IS `formatCoordinates(point)`
                              // (no reverse geocoding, #254), so showing it
                              // twice would be redundant.
                              if (_headerSubtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _headerSubtitle!,
                                  style: const TextStyle(
                                    color: _textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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
                      selectedBeach: _selectedBeach,
                      // #158: the standalone, non-editable "Enter cities"
                      // entry point below the map card is gone — the map
                      // card's own search icon is now the only place-search
                      // entry on Home, and `SearchScreen` (beach list,
                      // favorites, filter) stays reachable via "Beaches" in
                      // this overflow menu instead.
                      onOverflowPressed: () => _showMapOverflowMenu(
                        context,
                        onBeaches: () => _openSearch(context),
                        onUseMyLocation: widget.deviceLocationService == null
                            ? null
                            : () => unawaited(_handleUseMyLocation(context)),
                        unitPreferencesProvider: widget.unitPreferencesProvider,
                      ),
                    ),
                    // #214: the beach picked in `SearchScreen`'s results is
                    // already highlighted on the map above (`selectedBeach`
                    // flows into `LocationMapCard`); this is its compact
                    // info row, visible without another tap. Reuses
                    // `BeachResultCard`'s own fields/formatting — sourced
                    // from `nearbyBeachesProvider`'s re-fetched marine data
                    // once it resolves, "No data" until then, matching
                    // `SearchScreen`'s own cards exactly.
                    if (_selectedBeach != null) ...[
                      const SizedBox(height: 16),
                      _buildSelectedBeachInfo(_selectedBeach!, unitSystem),
                    ],
                    const SizedBox(height: 16),
                    SwimSuggestionPill(verdict: swimVerdict),
                    // #169/#229: sits between the smart suggestion pill and
                    // the Sea section/stat grid, hidden entirely (no gap)
                    // when there is neither an upcoming alert nor a
                    // next-hour note — see ForecastAlertList's own doc
                    // comment.
                    if (forecastAlerts.isNotEmpty || nextHourNote != null) ...[
                      const SizedBox(height: 16),
                      ForecastAlertList(
                        alerts: forecastAlerts,
                        nextHourNote: nextHourNote,
                        now: effectiveNow,
                      ),
                    ],
                    // #213/#228: a fetch in flight for a new pick, or one
                    // that failed outright, shows a loading/error note here
                    // instead of either the previous pick's values or a
                    // silent blank gap — but (issue #251) never hides the
                    // 3x3 grid below it: each tile already falls back to
                    // "No data" on its own null-safe formatter when there's
                    // nothing to show yet, exactly like every other "No
                    // data" case in this grid, so Water depth and the Air
                    // group (neither of which depend on marine data) stay
                    // visible and correct regardless of this fetch's state.
                    if (marineLoading) ...[
                      const SizedBox(height: 20),
                      _buildSectionLoading(height: 40),
                    ] else if (marineErrorMessage != null) ...[
                      const SizedBox(height: 20),
                      _buildSectionError(marineErrorMessage),
                    ],
                    const SizedBox(height: 20),
                    // #251: the former 2x2 stat grid (wind/rain/depth/UV)
                    // and the former horizontally-scrolling Sea section are
                    // now one 3x3 grid of equally-sized StatTiles in three
                    // labelled groups (Sea/Current/Air), each separated by
                    // a thin divider — all nine data points one visual
                    // size, with no trend row on any of them (the detail
                    // screens keep their own).
                    StatTileGroup(
                      label: 'Sea',
                      icon: Icons.waves,
                      tiles: [
                        StatTile(
                          key: const Key('wave-height-tile'),
                          icon: Icons.waves,
                          label: 'Wave height',
                          value: _formatSeaWaveHeight(
                            seaCondition?.waveHeight,
                            unitSystem,
                          ),
                          onTap: () => Navigator.of(context).push(
                            buildDetailRoute(
                              DetailMetric.waveHeight,
                              hourly: const [],
                              seaHourly: seaCondition?.hourly ?? const [],
                              currentValue: seaCondition?.waveHeight,
                              unitSystem: unitSystem,
                            ),
                          ),
                        ),
                        StatTile(
                          key: const Key('water-temperature-tile'),
                          icon: Icons.thermostat,
                          label: 'Water temp',
                          value: _formatSeaWaterTemperature(
                            seaCondition?.seaSurfaceTemperature,
                            unitSystem,
                          ),
                          onTap: () => Navigator.of(context).push(
                            buildDetailRoute(
                              DetailMetric.waterTemperature,
                              hourly: const [],
                              seaHourly: seaCondition?.hourly ?? const [],
                              currentValue: seaCondition?.seaSurfaceTemperature,
                              unitSystem: unitSystem,
                            ),
                          ),
                        ),
                        StatTile(
                          key: const Key('water-depth-tile'),
                          icon: Icons.waves,
                          label: 'Water depth',
                          value: depthValue,
                          statusLabel: depthStatusLabel,
                          statusColor: depthStatusColor,
                          onTap: () => Navigator.of(context).push(
                            buildDetailRoute(
                              DetailMetric.depth,
                              hourly: const [],
                              depthProfile: depthProfile,
                              beach: depthBeach,
                              currentWaveHeightMeters: seaCondition?.waveHeight,
                              currentValue: seaCondition?.currentVelocity,
                              currentDirectionValue:
                                  seaCondition?.currentDirection,
                              seawardBearingDegrees: seawardBearingDegrees,
                              unitSystem: unitSystem,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildGroupDivider(),
                    const SizedBox(height: 20),
                    StatTileGroup(
                      label: 'Current',
                      icon: Icons.explore,
                      tiles: [
                        StatTile(
                          key: const Key('current-speed-tile'),
                          icon: Icons.speed,
                          label: 'Current speed',
                          value: _formatSeaCurrentSpeed(
                            seaCondition?.currentVelocity,
                            unitSystem,
                          ),
                          onTap: () => Navigator.of(context).push(
                            buildDetailRoute(
                              DetailMetric.current,
                              hourly: const [],
                              seaHourly: seaCondition?.hourly ?? const [],
                              currentValue: seaCondition?.currentVelocity,
                              currentDirectionValue:
                                  seaCondition?.currentDirection,
                              seawardBearingDegrees: seawardBearingDegrees,
                              unitSystem: unitSystem,
                            ),
                          ),
                        ),
                        StatTile(
                          key: const Key('current-direction-tile'),
                          icon: Icons.navigation,
                          iconRotationDegrees: seaCondition?.currentDirection,
                          label: 'Current direction',
                          value: _seaCurrentDirectionLabel(
                            seaCondition?.currentDirection,
                          ),
                          statusLabel: currentShoreRelation == null
                              ? null
                              : _shoreRelationLabel(currentShoreRelation),
                          statusColor: currentShoreRelation == null
                              ? null
                              : (currentShoreRelation ==
                                        ShoreRelation.awayFromShore
                                    ? _colorWarning
                                    : _textSecondary),
                          statusBold:
                              currentShoreRelation ==
                              ShoreRelation.awayFromShore,
                          onTap: () => Navigator.of(context).push(
                            buildDetailRoute(
                              DetailMetric.current,
                              hourly: const [],
                              seaHourly: seaCondition?.hourly ?? const [],
                              currentValue: seaCondition?.currentVelocity,
                              currentDirectionValue:
                                  seaCondition?.currentDirection,
                              seawardBearingDegrees: seawardBearingDegrees,
                              unitSystem: unitSystem,
                            ),
                          ),
                        ),
                        StatTile(
                          key: const Key('wave-direction-tile'),
                          icon: Icons.navigation,
                          iconRotationDegrees:
                              seaCondition?.waveDirection == null
                              ? null
                              : seaCondition!.waveDirection! + 180,
                          label: 'Wave direction',
                          // No status/third line (issue #251): wave
                          // direction has no defined status at all, unlike
                          // the current-direction tile's shore relation
                          // above.
                          value: _seaWaveDirectionLabel(
                            seaCondition?.waveDirection,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildGroupDivider(),
                    const SizedBox(height: 20),
                    StatTileGroup(
                      label: 'Air',
                      icon: Icons.air,
                      tiles: [
                        StatTile(
                          icon: Icons.air,
                          label: 'Wind speed',
                          value: _formatWindSpeedValue(
                            weatherData?.windSpeed,
                            unitSystem,
                          ),
                          unit: _windSpeedUnit(
                            weatherData?.windSpeed,
                            unitSystem,
                          ),
                          statusLabel: windStatus == null
                              ? null
                              : windStatusLabel(windStatus),
                          statusColor: windStatus == null
                              ? null
                              : windStatusColor(windStatus),
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
                          value: _formatPercentValue(
                            weatherData?.rainChancePercent,
                          ),
                          unit: _percentUnit(weatherData?.rainChancePercent),
                          statusLabel: rainStatus == null
                              ? null
                              : rainChanceStatusLabel(rainStatus),
                          statusColor: rainStatus == null
                              ? null
                              : rainChanceStatusColor(rainStatus),
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
                          icon: Icons.wb_sunny_outlined,
                          label: 'UV index',
                          value: _formatUvIndex(weatherData?.uvIndex),
                          statusLabel: uvBand == null
                              ? null
                              : uvBandLabel(uvBand),
                          statusColor: uvBand == null
                              ? null
                              : uvBandColor(uvBand),
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

  /// The compact info row for [beach] shown under the map card once it has
  /// been picked from `SearchScreen`'s results (#214) — the same fields
  /// (price, wave height, water temperature, shoes advice, parking, beach
  /// club, cafe) `BeachResultCard` already renders for a search result, so
  /// this reuses that widget rather than duplicating its formatting.
  ///
  /// [_handleBeachPicked] also re-fetches nearby beaches for [beach]'s own
  /// location, which replaces [NearbyBeachesProvider.beaches] (and its
  /// `seaConditionFor` lookup, keyed by instance) with fresh [Beach]
  /// instances — so [beach] itself (handed down from `SearchScreen`,
  /// before that re-fetch) would never match and always render "No data"
  /// once it resolves. [isSameBeach] resolves the live instance for that
  /// lookup instead, the same value-based matching `LocationMapCard` uses
  /// for its highlight.
  Widget _buildSelectedBeachInfo(Beach beach, UnitSystem unitSystem) {
    final liveBeach = (widget.nearbyBeachesProvider?.beaches ?? const [])
        .firstWhere((b) => isSameBeach(b, beach), orElse: () => beach);
    final seaCondition = widget.nearbyBeachesProvider?.seaConditionFor(
      liveBeach,
    );
    return BeachResultCard(
      placeName: liveBeach.name,
      areaSubtitle: liveBeach.city,
      temperature: _formatTemperature(
        widget.weatherProvider?.currentData?.temperature,
        unitSystem,
      ),
      fee: liveBeach.fee,
      waveHeightMeters: seaCondition?.waveHeight,
      waterTemperatureCelsius: seaCondition?.seaSurfaceTemperature,
      shoeAdvice: adviseOnShoes(liveBeach.surface),
      hasParking: liveBeach.hasParking,
      hasBeachResort: liveBeach.hasBeachResort,
      hasCafe: liveBeach.hasCafe,
      unitSystem: unitSystem,
      borderRadius: BorderRadius.circular(24),
    );
  }

  /// A thin divider line between two of the stat grid's groups (issue
  /// #251's "Sea"/"Current"/"Air" groups) — low-opacity `text.secondary` so
  /// it reads as a subtle separator, matching the grid's own "no hard
  /// borders" direction (docs/design.md).
  Widget _buildGroupDivider() {
    return Divider(color: _textSecondary.withValues(alpha: 0.15), height: 1);
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

  /// Shown in the Sea section's place when a fetch for the newly picked
  /// location has failed and there's no previous data to fall back to
  /// (#228) — the sectional counterpart to the full-screen error state
  /// [build] uses for the very first load, so a later pick's failure is
  /// never silently left blank. Mirrors that state's wording; [height]
  /// bounds it to the Sea section's usual footprint, matching
  /// [_buildSectionLoading].
  Widget _buildSectionError(String error, {double? height}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: _colorWarning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unable to load marine data.\n$error',
              style: const TextStyle(color: _textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
    return height == null
        ? content
        : SizedBox(
            height: height,
            child: Center(child: content),
          );
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
