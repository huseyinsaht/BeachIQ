import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/models/weather_code.dart';
import 'data/models/weather_condition.dart';
import 'data/repositories/marine_repository.dart';
import 'data/repositories/weather_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/weather_api_service.dart';
import 'logic/providers/favorites_provider.dart';
import 'logic/providers/marine_provider.dart';
import 'logic/providers/unit_preferences_provider.dart';
import 'logic/providers/weather_provider.dart';
import 'logic/unit_preferences.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/widgets/hourly_forecast_item.dart';
import 'presentation/widgets/location_map_card.dart';
import 'presentation/widgets/search_field.dart';
import 'presentation/widgets/stat_tile.dart';

void main() async {
  // Required before any plugin platform-channel call (here,
  // SharedPreferences.getInstance()) made ahead of runApp(), which would
  // otherwise initialize the binding itself.
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MarineApp(unitPreferencesProvider: UnitPreferencesProvider(prefs)));
}

const String _noData = 'No data';

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

/// Opens a small bottom sheet to switch between metric and imperial units,
/// the "small toggle entry point" added to the existing overflow ("...")
/// menu on the Home screen's map card (an identical copy of this lives in
/// `search_screen.dart` for its own header's overflow menu, matching this
/// codebase's existing convention of small per-file duplication over a
/// shared presentation/main.dart dependency).
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

class MarineApp extends StatelessWidget {
  const MarineApp({super.key, this.tileProvider, this.unitPreferencesProvider});

  /// Overridable so integration tests can avoid the real tile network.
  final TileProvider? tileProvider;

  /// Drives the metric/imperial toggle on both Home and Search. Null (the
  /// default for any existing call site that doesn't pass one, e.g. the
  /// integration tests) hides the toggle and renders every value in metric,
  /// unchanged from before.
  final UnitPreferencesProvider? unitPreferencesProvider;

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
          ),
        ),
      ),
    );
  }
}

/// The Home / location-detail screen, per docs/design.md § "Screen: Home /
/// location detail": a header, condition row, [LocationMapCard], a smart
/// suggestion pill, a 2x2 [StatTile] grid, and a scrollable hourly row of
/// [HourlyForecastItem]s.
///
/// The header, stat grid and hourly row are bound to [WeatherProvider]'s
/// data, fetched for the fixed Çeşme coordinates. [MarineProvider] is only
/// consumed for the loading/error states (#69) — it is not yet a source for
/// any stat tile.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.tileProvider,
    this.marineProvider,
    this.weatherProvider,
    this.unitPreferencesProvider,
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
  static const _textOnPaper = Color(0xFF2E3057);
  static const _pillGradientStart = Color(0xFFD9DBDF);
  static const _pillGradientEnd = Color(0xFFF2F3F5);

  static final _placeCenter = LatLng(38.3220, 26.3260);

  /// Guards [_openSearch] against a fast double-tap pushing two
  /// `SearchScreen`s while the first tap's `SharedPreferences.getInstance()`
  /// await is still pending.
  bool _openingSearch = false;

  @override
  void initState() {
    super.initState();
    widget.marineProvider?.addListener(_onProviderChanged);
    widget.weatherProvider?.addListener(_onProviderChanged);
    widget.unitPreferencesProvider?.addListener(_onProviderChanged);
    // Deferred to after the first frame: HomeScreen is built inside the
    // Consumer2<MarineProvider, WeatherProvider> that also listens to
    // WeatherProvider (see MarineApp), so calling fetchData synchronously
    // here would notify that ancestor while it is still building this very
    // subtree ("setState()/markNeedsBuild() called during build").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.weatherProvider?.fetchData(
        _placeCenter.latitude,
        _placeCenter.longitude,
      );
    });
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
  }

  @override
  void dispose() {
    widget.marineProvider?.removeListener(_onProviderChanged);
    widget.weatherProvider?.removeListener(_onProviderChanged);
    widget.unitPreferencesProvider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  /// Rebuilds whenever the (optional) [MarineProvider] or [WeatherProvider]
  /// notifies, so the loading/error states and the real weather values stay
  /// in sync with them.
  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  /// Re-triggers the marine and weather data fetches for a pull-to-refresh
  /// gesture. A no-op for whichever provider wasn't supplied (matches the
  /// existing optional-provider pattern from the loading/error states
  /// above).
  Future<void> _handleRefresh() async {
    await Future.wait([
      widget.marineProvider?.fetchData(
            _placeCenter.latitude,
            _placeCenter.longitude,
          ) ??
          Future.value(),
      widget.weatherProvider?.fetchData(
            _placeCenter.latitude,
            _placeCenter.longitude,
          ) ??
          Future.value(),
    ]);
  }

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
    // Once data has loaded once, a pull-to-refresh re-fetch must not tear
    // down this screen (and the RefreshIndicator/scroll view driving that
    // very refresh) back to a full-screen shell — only the *first* load
    // (no data yet) uses the full-screen loading/error states below.
    final hasData = marineProvider?.currentData != null;
    if (marineProvider != null && marineProvider.isLoading && !hasData) {
      return _buildStatusShell(
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_textPrimary),
          ),
        ),
      );
    }
    final error = marineProvider?.error;
    if (error != null && !hasData) {
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
    final weatherData = widget.weatherProvider?.currentData;
    final unitSystem =
        widget.unitPreferencesProvider?.unitSystem ?? UnitSystem.metric;
    final hourly = _upcomingHourly(
      weatherData?.hourly ?? const [],
      (widget.now ?? DateTime.now)(),
    );
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgBase, _bgGradientBottom],
          ),
        ),
        child: SafeArea(
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Location',
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Çeşme, İzmir',
                              style: TextStyle(
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
                    center: _placeCenter,
                    placeName: 'Çeşme, İzmir',
                    tileProvider: widget.tileProvider,
                    onOverflowPressed: widget.unitPreferencesProvider == null
                        ? null
                        : () => _showUnitSystemSheet(
                            context,
                            widget.unitPreferencesProvider!,
                          ),
                  ),
                  const SizedBox(height: 16),
                  // A tappable, non-editable search entry point (per
                  // docs/assets/mockup-home.png): it looks like the same
                  // `SearchField` used on the Search screen, but tapping it
                  // pushes `SearchScreen` instead of opening the keyboard in
                  // place.
                  GestureDetector(
                    key: const Key('home-search-entry'),
                    onTap: () => _openSearch(context),
                    child: const AbsorbPointer(child: SearchField()),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_pillGradientStart, _pillGradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.wb_sunny_outlined,
                          size: 18,
                          color: _textOnPaper,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Good conditions for a swim right now',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textOnPaper,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                      ),
                      StatTile(
                        icon: Icons.water_drop_outlined,
                        label: 'Rain chance',
                        value: _formatPercent(weatherData?.rainChancePercent),
                        trendDirection: StatTrendDirection.down,
                        trendDelta: '3%',
                      ),
                      StatTile(
                        icon: Icons.speed,
                        label: 'Pressure',
                        value: _formatPressure(weatherData?.pressureHpa),
                        trendDirection: StatTrendDirection.up,
                        trendDelta: '1 hPa',
                      ),
                      StatTile(
                        icon: Icons.wb_sunny_outlined,
                        label: 'UV index',
                        value: _formatUvIndex(weatherData?.uvIndex),
                        trendDirection: StatTrendDirection.up,
                        trendDelta: '0.5',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: _textSecondary),
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
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: hourly.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 20),
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
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps [child] in the same background/[SafeArea] shell as the loaded
  /// layout, for the loading and error states.
  Widget _buildStatusShell(Widget child) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgBase, _bgGradientBottom],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
