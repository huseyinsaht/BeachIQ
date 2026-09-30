import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'data/repositories/marine_repository.dart';
import 'data/services/api_service.dart';
import 'logic/providers/marine_provider.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/widgets/hourly_forecast_item.dart';
import 'presentation/widgets/location_map_card.dart';
import 'presentation/widgets/search_field.dart';
import 'presentation/widgets/stat_tile.dart';

void main() {
  runApp(const MarineApp());
}

class MarineApp extends StatelessWidget {
  const MarineApp({super.key, this.tileProvider});

  /// Overridable so integration tests can avoid the real tile network.
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarineProvider(MarineRepository(MarineApiService())),
      child: Consumer<MarineProvider>(
        builder: (context, marineProvider, _) => MaterialApp(
          title: 'Marine Safety',
          home: HomeScreen(
            tileProvider: tileProvider,
            marineProvider: marineProvider,
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
/// All shown values are static placeholders until a later issue wires this
/// up to [MarineProvider]/`WeatherProvider`. Centers on Çeşme, İzmir, the
/// same placeholder location used elsewhere in the app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.tileProvider, this.marineProvider});

  /// Overridable so widget tests can avoid hitting the real tile network.
  final TileProvider? tileProvider;

  /// Drives the loading/error states below. Null (the default for any
  /// existing call site that doesn't pass one) renders the normal loaded
  /// layout, unchanged from before.
  final MarineProvider? marineProvider;

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

  static const _hourly = [
    HourlyForecastItem(timeLabel: 'Now', icon: Icons.wb_sunny, temperature: '27°'),
    HourlyForecastItem(timeLabel: '1PM', icon: Icons.wb_sunny, temperature: '28°'),
    HourlyForecastItem(timeLabel: '2PM', icon: Icons.wb_cloudy, temperature: '27°'),
    HourlyForecastItem(timeLabel: '3PM', icon: Icons.wb_cloudy, temperature: '26°'),
    HourlyForecastItem(timeLabel: '4PM', icon: Icons.cloud, temperature: '25°'),
    HourlyForecastItem(timeLabel: '5PM', icon: Icons.cloud, temperature: '24°'),
  ];

  @override
  void initState() {
    super.initState();
    widget.marineProvider?.addListener(_onMarineProviderChanged);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marineProvider != widget.marineProvider) {
      oldWidget.marineProvider?.removeListener(_onMarineProviderChanged);
      widget.marineProvider?.addListener(_onMarineProviderChanged);
    }
  }

  @override
  void dispose() {
    widget.marineProvider?.removeListener(_onMarineProviderChanged);
    super.dispose();
  }

  /// Rebuilds whenever the (optional) [MarineProvider] notifies, so the
  /// loading/error states below stay in sync with it.
  void _onMarineProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final marineProvider = widget.marineProvider;
    if (marineProvider != null && marineProvider.isLoading) {
      return _buildStatusShell(
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_textPrimary),
          ),
        ),
      );
    }
    final error = marineProvider?.error;
    if (error != null) {
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
          child: SingleChildScrollView(
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
                    const Text(
                      '27°',
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 44,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Partly Cloudy',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                    Text(
                      'H:29° L:15°',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
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
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
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
                      Icon(Icons.wb_sunny_outlined, size: 18, color: _textOnPaper),
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
                  children: const [
                    StatTile(
                      icon: Icons.air,
                      label: 'Wind speed',
                      value: '12 km/h',
                      trendDirection: StatTrendDirection.up,
                      trendDelta: '2 km/h',
                    ),
                    StatTile(
                      icon: Icons.water_drop_outlined,
                      label: 'Rain chance',
                      value: '10%',
                      trendDirection: StatTrendDirection.down,
                      trendDelta: '3%',
                    ),
                    StatTile(
                      icon: Icons.speed,
                      label: 'Pressure',
                      value: '1013 hPa',
                      trendDirection: StatTrendDirection.up,
                      trendDelta: '1 hPa',
                    ),
                    StatTile(
                      icon: Icons.wb_sunny_outlined,
                      label: 'UV index',
                      value: '6.5',
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
                    itemCount: _hourly.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 20),
                    itemBuilder: (context, index) => _hourly[index],
                  ),
                ),
              ],
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
