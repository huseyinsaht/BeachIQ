import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'data/models/weather_code.dart';
import 'data/repositories/marine_repository.dart';
import 'data/repositories/weather_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/weather_api_service.dart';
import 'logic/providers/marine_provider.dart';
import 'logic/providers/weather_provider.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/widgets/hourly_forecast_item.dart';
import 'presentation/widgets/location_map_card.dart';
import 'presentation/widgets/search_field.dart';
import 'presentation/widgets/stat_tile.dart';

void main() {
  runApp(const MarineApp());
}

const String _noData = 'No data';

String _formatTemperature(double? celsius) {
  if (celsius == null) return '--°';
  return '${celsius.round()}°';
}

String _formatWindSpeed(double? kmh) {
  if (kmh == null) return _noData;
  return '${kmh.round()} km/h';
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

class MarineApp extends StatelessWidget {
  const MarineApp({super.key, this.tileProvider});

  /// Overridable so integration tests can avoid the real tile network.
  final TileProvider? tileProvider;

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

  @override
  void initState() {
    super.initState();
    widget.marineProvider?.addListener(_onMarineProviderChanged);
    widget.weatherProvider?.addListener(_onMarineProviderChanged);
    widget.weatherProvider?.fetchData(
      _placeCenter.latitude,
      _placeCenter.longitude,
    );
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherProvider != widget.weatherProvider) {
      oldWidget.weatherProvider?.removeListener(_onMarineProviderChanged);
      widget.weatherProvider?.addListener(_onMarineProviderChanged);
    }
    if (oldWidget.marineProvider != widget.marineProvider) {
      oldWidget.marineProvider?.removeListener(_onMarineProviderChanged);
      widget.marineProvider?.addListener(_onMarineProviderChanged);
    }
  }

  @override
  void dispose() {
    widget.marineProvider?.removeListener(_onMarineProviderChanged);
    widget.weatherProvider?.removeListener(_onMarineProviderChanged);
    super.dispose();
  }

  /// Rebuilds whenever the (optional) [MarineProvider] or [WeatherProvider]
  /// notifies, so the loading/error states and the real weather values stay
  /// in sync with them.
  void _onMarineProviderChanged() {
    if (mounted) setState(() {});
  }

  /// Re-triggers the marine data fetch for a pull-to-refresh gesture. A
  /// no-op when no [MarineProvider] was supplied (matches the existing
  /// optional-provider pattern from the loading/error states above).
  Future<void> _handleRefresh() {
    return widget.marineProvider?.fetchData(
          _placeCenter.latitude,
          _placeCenter.longitude,
        ) ??
        Future.value();
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
    final hourly = weatherData?.hourly ?? const [];
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
                        _formatTemperature(weatherData?.temperature),
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
                        'H:${_formatTemperature(weatherData?.highTemperature)} '
                        'L:${_formatTemperature(weatherData?.lowTemperature)}',
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
                  ),
                  const SizedBox(height: 16),
                  // A tappable, non-editable search entry point (per
                  // docs/assets/mockup-home.png): it looks like the same
                  // `SearchField` used on the Search screen, but tapping it
                  // pushes `SearchScreen` instead of opening the keyboard in
                  // place.
                  GestureDetector(
                    key: const Key('home-search-entry'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(),
                      ),
                    ),
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
                        value: _formatWindSpeed(weatherData?.windSpeed),
                        trendDirection: StatTrendDirection.up,
                        trendDelta: '2 km/h',
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
                          temperature: _formatTemperature(entry.temperature),
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
