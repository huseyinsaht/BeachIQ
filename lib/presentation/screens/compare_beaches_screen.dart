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

// Same navy as Home's background (home_screen.dart's _bgBase/_bgGradientBottom).
const Color _bgBase = Color(0xFF0D1220);
const Color _bgBottom = Color(0xFF2A3145);
const Color _cardFill = Color(0xFF1E2434);
const Color _textSecondary = Color(0xFF8B93A6);
const Color _bestBorder = Color(0xFF66BB6A);

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

  SwimVerdict _verdictFor(Beach beach) {
    final weather = _weather[beach];
    return scoreSwimSuitability(
      waveHeightM: widget.seaConditions[beach]?.waveHeight,
      windSpeedKmh: weather?.windSpeed,
      rainChancePercent: weather?.rainChancePercent?.round(),
      weatherCode: weather?.weatherCode,
      airTemperatureC: weather?.temperature,
    );
  }

  /// The beach to flag "Best today": only when the weather has loaded for
  /// every beach (a beach whose weather failed is never crowned), the top verdict is [SwimSuitabilityLevel.good], and one
  /// beach is strictly ahead of the rest (verdict level, then the lower wave
  /// height, then the lower wind). A tie, or a day with no good beach,
  /// flags nothing -- never an arbitrary pick.
  Beach? _bestBeach() {
    if (widget.beaches.length < 2 || _loadingWeather.isNotEmpty) return null;
    // Crowning a beach needs the weather of every beach, not just the waves.
    if (widget.beaches.any((b) => _weather[b] == null)) return null;
    final keyed = <Beach, List<double>>{};
    for (final beach in widget.beaches) {
      final verdict = _verdictFor(beach);
      keyed[beach] = [
        verdict.level.index.toDouble(),
        widget.seaConditions[beach]?.waveHeight ?? double.infinity,
        _weather[beach]?.windSpeed ?? double.infinity,
      ];
    }
    int compare(List<double> a, List<double> b) {
      for (var i = 0; i < a.length; i++) {
        final c = a[i].compareTo(b[i]);
        if (c != 0) return c;
      }
      return 0;
    }

    final ordered = keyed.entries.toList()
      ..sort((a, b) => compare(a.value, b.value));
    final best = ordered.first;
    if (best.value[0] != SwimSuitabilityLevel.good.index) return null;
    if (compare(best.value, ordered[1].value) == 0) return null;
    return best.key;
  }

  @override
  Widget build(BuildContext context) {
    final best = _bestBeach();
    return Scaffold(
      backgroundColor: _bgBase,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Compare beaches'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgBase, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
            children: [
              for (final beach in widget.beaches) ...[
                _BeachCompareCard(
                  key: Key('compare-card-${beach.name}'),
                  beach: beach,
                  isBest: identical(beach, best),
                  verdict: _verdictFor(beach),
                  verdictLoading: _loadingWeather.contains(beach),
                  metrics: _metricsFor(beach),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<_Metric> _metricsFor(Beach beach) {
    final sea = widget.seaConditions[beach];
    final weather = _weather[beach];

    String? depthLabel;
    Color? depthColor;
    final profile = _depth[beach];
    if (profile != null) {
      final steepness = classifyShallowEntry(profile).steepness;
      depthLabel = shallowEntryStatusLabel(steepness);
      depthColor = shallowEntryStatusColor(steepness);
    }

    return [
      _Metric(
        icon: Icons.waves,
        label: 'Wave height',
        value: sea?.waveHeight == null
            ? null
            : formatWaveHeight(sea!.waveHeight!, _unitSystem),
      ),
      _Metric(
        icon: Icons.air,
        label: 'Wind',
        loading: _loadingWeather.contains(beach),
        value: weather?.windSpeed == null
            ? null
            : formatWindSpeed(weather!.windSpeed, _unitSystem),
      ),
      _Metric(
        icon: Icons.thermostat,
        label: 'Water temp',
        value: sea?.seaSurfaceTemperature == null
            ? null
            : formatTemperature(sea!.seaSurfaceTemperature!, _unitSystem),
      ),
      _Metric(
        icon: Icons.straighten,
        label: 'Depth',
        loading: _loadingDepth.contains(beach),
        value: depthLabel,
        color: depthColor,
      ),
    ];
  }
}

/// One comparison row of a [_BeachCompareCard]: a value, "No data" when
/// [value] is null, or a spinner while [loading].
class _Metric {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.loading = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool loading;
  final Color? color;
}

class _BeachCompareCard extends StatelessWidget {
  const _BeachCompareCard({
    super.key,
    required this.beach,
    required this.isBest,
    required this.verdict,
    required this.verdictLoading,
    required this.metrics,
  });

  final Beach beach;
  final bool isBest;
  final SwimVerdict verdict;
  final bool verdictLoading;
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final palette = paletteForVerdict(verdict.level);
    final summary = [
      beach.name,
      if (!verdictLoading) verdict.message,
      for (final m in metrics)
        if (!m.loading) '${m.label}: ${m.value ?? _noData}',
    ].join('. ');

    return Semantics(
      container: true,
      label: summary,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isBest ? _bestBorder : Colors.white12,
              width: isBest ? 1.5 : 1,
            ),
          ),
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
                          beach.name,
                          key: Key('compare-beach-header-${beach.name}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (beach.city.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              beach.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isBest) ...[
                    const SizedBox(width: 8),
                    Container(
                      key: const Key('compare-best-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _bestBorder.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _bestBorder),
                      ),
                      child: const Text(
                        'Best today',
                        style: TextStyle(
                          color: _bestBorder,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                key: Key('compare-verdict-${beach.name}'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [palette.gradientStart, palette.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: verdictLoading
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            palette.icon,
                            size: 18,
                            color: palette.foreground,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              verdict.message,
                              style: TextStyle(
                                color: palette.foreground,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 10.0;
                  final tileWidth = (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final metric in metrics)
                        SizedBox(
                          width: tileWidth,
                          child: _MetricTile(metric: metric),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final hasValue = metric.value != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, size: 15, color: _textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (metric.loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              metric.value ?? _noData,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasValue
                    ? (metric.color ?? Colors.white)
                    : _textSecondary,
                fontSize: hasValue ? 16 : 14,
                fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}
