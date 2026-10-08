import 'package:flutter/material.dart';

import '../../data/models/beach.dart';
import '../../data/models/depth_profile.dart';
import '../../data/models/sea_condition.dart';
import '../../data/models/weather_condition.dart';
import '../../data/repositories/weather_repository.dart';
import '../../data/services/bathymetry_service.dart';
import '../../logic/providers/unit_preferences_provider.dart';
import '../../logic/shallow_entry.dart';
import '../../logic/shallow_entry_status.dart';
import '../../logic/swim_suitability.dart';
import '../../logic/unit_preferences.dart';
import '../theme/verdict_palette.dart';

const String _noData = 'No data';

/// A short word for [SwimSuitabilityLevel], compact enough for a
/// comparison column (unlike [SwimVerdict.message]'s full sentence).
String _swimLevelLabel(SwimSuitabilityLevel level) {
  switch (level) {
    case SwimSuitabilityLevel.good:
      return 'Good';
    case SwimSuitabilityLevel.caution:
      return 'Caution';
    case SwimSuitabilityLevel.poor:
      return 'Poor';
    case SwimSuitabilityLevel.unknown:
      return _noData;
  }
}

/// Compares 2-3 beaches side by side (issue #274): wave height, wind,
/// water temperature, a plain-language depth/non-swimmer verdict (reusing
/// #256's `classifyShallowEntry`/`shallowEntryStatusLabel`, the same
/// source of truth #257's Home summary reuses) and the Home screen's own
/// swim score (`scoreSwimSuitability`), one column per beach.
///
/// [seaConditions] is supplied already-fetched (the caller already has it
/// from `NearbyBeachesProvider.seaConditionFor`, via its one batched
/// marine request for every nearby beach) — this screen only fetches, per
/// beach, what that batch call doesn't cover: weather (via
/// [weatherRepository]) and the depth profile (via [bathymetryService]).
/// Either (or both) may be omitted, e.g. in a test that only cares about
/// the sea-condition columns -- the corresponding rows then show "No
/// data" instead of loading forever.
class CompareBeachesScreen extends StatefulWidget {
  const CompareBeachesScreen({
    super.key,
    required this.beaches,
    this.seaConditions = const {},
    this.weatherRepository,
    this.bathymetryService,
    this.unitPreferencesProvider,
  });

  /// The 2-3 beaches to compare, in display order.
  final List<Beach> beaches;

  /// Already-fetched marine data per beach (wave height, water
  /// temperature), keyed the same way [beaches] is given.
  final Map<Beach, SeaCondition?> seaConditions;

  final WeatherRepository? weatherRepository;
  final BathymetryService? bathymetryService;
  final UnitPreferencesProvider? unitPreferencesProvider;

  @override
  State<CompareBeachesScreen> createState() => _CompareBeachesScreenState();
}

class _CompareBeachesScreenState extends State<CompareBeachesScreen> {
  final Map<Beach, WeatherCondition?> _weather = {};
  final Map<Beach, DepthProfile?> _depth = {};
  final Set<Beach> _loadingWeather = {};
  final Set<Beach> _loadingDepth = {};

  @override
  void initState() {
    super.initState();
    for (final beach in widget.beaches) {
      _fetchWeather(beach);
      _fetchDepth(beach);
    }
  }

  void _fetchWeather(Beach beach) {
    final repository = widget.weatherRepository;
    if (repository == null) return;
    _loadingWeather.add(beach);
    repository
        .getWeatherData(beach.latitude, beach.longitude)
        .then((data) {
          if (!mounted) return;
          setState(() {
            _weather[beach] = data;
            _loadingWeather.remove(beach);
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _loadingWeather.remove(beach));
        });
  }

  void _fetchDepth(Beach beach) {
    final service = widget.bathymetryService;
    if (service == null) return;
    _loadingDepth.add(beach);
    service
        .fetchProfile(beach)
        .then((profile) {
          if (!mounted) return;
          setState(() {
            _depth[beach] = profile;
            _loadingDepth.remove(beach);
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _loadingDepth.remove(beach));
        });
  }

  UnitSystem get _unitSystem =>
      widget.unitPreferencesProvider?.unitSystem ?? UnitSystem.metric;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare beaches')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: {
            0: const FixedColumnWidth(84),
            for (var i = 0; i < widget.beaches.length; i++)
              i + 1: const FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            _headerRow(),
            _row('Wave height', (beach) => _waveHeightCell(beach)),
            _row('Wind', (beach) => _windCell(beach)),
            _row('Water temp', (beach) => _waterTempCell(beach)),
            _row('Depth', (beach) => _depthCell(beach)),
            _row('Swim score', (beach) => _swimScoreCell(beach)),
          ],
        ),
      ),
    );
  }

  TableRow _headerRow() {
    return TableRow(
      children: [
        const SizedBox.shrink(),
        for (final beach in widget.beaches)
          Padding(
            key: Key('compare-beach-header-${beach.name}'),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              beach.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
      ],
    );
  }

  TableRow _row(String label, Widget Function(Beach beach) cellBuilder) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        for (final beach in widget.beaches)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Center(child: cellBuilder(beach)),
          ),
      ],
    );
  }

  Widget _cellText(String text, {Color? color}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: color),
    );
  }

  Widget _waveHeightCell(Beach beach) {
    final meters = widget.seaConditions[beach]?.waveHeight;
    return _cellText(
      meters == null ? _noData : formatWaveHeight(meters, _unitSystem),
    );
  }

  Widget _windCell(Beach beach) {
    if (_loadingWeather.contains(beach)) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final kmh = _weather[beach]?.windSpeed;
    return _cellText(
      kmh == null ? _noData : formatWindSpeed(kmh, _unitSystem),
    );
  }

  Widget _waterTempCell(Beach beach) {
    final celsius = widget.seaConditions[beach]?.seaSurfaceTemperature;
    return _cellText(
      celsius == null ? _noData : formatTemperature(celsius, _unitSystem),
    );
  }

  Widget _depthCell(Beach beach) {
    if (_loadingDepth.contains(beach)) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final profile = _depth[beach];
    if (profile == null) return _cellText(_noData);
    final steepness = classifyShallowEntry(profile).steepness;
    final label = shallowEntryStatusLabel(steepness);
    if (label == null) return _cellText(_noData);
    return _cellText(label, color: shallowEntryStatusColor(steepness));
  }

  Widget _swimScoreCell(Beach beach) {
    if (_loadingWeather.contains(beach)) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final weather = _weather[beach];
    final verdict = scoreSwimSuitability(
      waveHeightM: widget.seaConditions[beach]?.waveHeight,
      windSpeedKmh: weather?.windSpeed,
      rainChancePercent: weather?.rainChancePercent?.round(),
    );
    return _cellText(
      _swimLevelLabel(verdict.level),
      color: paletteForVerdict(verdict.level).gradientStart,
    );
  }
}
