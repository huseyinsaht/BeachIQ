import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/sea_condition.dart';
import '../../../logic/swim_suitability.dart';
import '../../../logic/unit_preferences.dart';
import '../../widgets/hourly_metric_chart.dart';
import '../../widgets/metric_detail_scaffold.dart';

const Color _textSecondary = Color(0xFF8B93A6);

/// The chart's two swim-suitability threshold lines, reusing
/// `swim_suitability.dart`'s exact cutoffs (never re-derived here) so this
/// screen can never drift from the numbers behind the home screen's swim
/// suggestion pill. [_roughThresholdColor] matches `color.warning`
/// (`#EF5350`, docs/design.md) — the same red already used for the pressure
/// screen's storm-risk threshold and the Sea section's away-from-shore
/// warning — so red consistently flags "be careful" across the app; the
/// lower, less severe cutoff gets a softer amber.
const Color _choppyThresholdColor = Color(0xFFFFA726);
const Color _roughThresholdColor = Color(0xFFEF5350);

/// Shown in place of the chart/period-direction block when [SeaHourly.
/// waveHeight] is null for every hour in the series (including an empty
/// series) — this location simply has no wave-height forecast, which is
/// common very close to shore since Open-Meteo's marine grid is coarse.
const String noWaveDataForLocationText = 'No data for this location.';

/// Converts [meters] to the unit [unitSystem] displays, mirroring
/// `unit_preferences.dart`'s `formatWaveHeight` but returning the raw
/// number (for chart points/thresholds, which need a `double`, not a
/// formatted string).
double _displayMeters(double meters, UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial ? metersToFeet(meters) : meters;

String _unitLabel(UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial ? 'ft' : 'm';

/// Formats a wave height already in meters as a bare number (no unit) in
/// [unitSystem], e.g. `"1.2"` or `"3.9"` — the hero/min/max summary values
/// show their unit separately, matching the pressure/UV detail screens.
String? _formatValue(double? meters, UnitSystem unitSystem) {
  if (meters == null) return null;
  return _displayMeters(meters, unitSystem).toStringAsFixed(1);
}

String _formatPeriod(double? seconds) =>
    seconds == null ? '--' : '${seconds.toStringAsFixed(1)}s';

/// Maps a compass bearing (degrees clockwise from true north, any range) to
/// its nearest 8-point cardinal label.
///
/// A copy of `sea_conditions_row.dart`'s private `_cardinalLabel` (same
/// boundaries, same wrap-around handling) — kept as its own small
/// per-screen copy rather than shared, matching how `nowHourIndex` is
/// already duplicated per metric detail screen (see this file's own
/// `nowHourIndex` doc comment).
String _cardinalLabel(double degrees) {
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final normalized = ((degrees % 360) + 360) % 360;
  final index = ((normalized + 22.5) / 45).floor() % 8;
  return points[index];
}

/// Formats a wave-direction bearing per [SeaCondition.waveDirection]'s
/// meteorological "coming from" convention (issue #154) — e.g. `"from
/// NW"` — the exact same format `sea_conditions_row.dart` uses for the Sea
/// section's wave-direction tile, reused here rather than re-derived.
String _waveDirectionLabel(double? waveDirectionDegrees) {
  if (waveDirectionDegrees == null) return 'No data';
  return 'from ${_cardinalLabel(waveDirectionDegrees)}';
}

/// The arrow's rotation (degrees clockwise from "up"), pointing where the
/// wave is actually heading rather than the raw "coming from" bearing —
/// the same `+ 180` convention `sea_conditions_row.dart` uses for its
/// wave-direction tile.
double? _arrowRotationDegrees(double? waveDirectionDegrees) =>
    waveDirectionDegrees == null ? null : waveDirectionDegrees + 180;

/// A one-line status comparing [waveHeightMeters] against the swim
/// thresholds from `swim_suitability.dart`, in [unitSystem]'s unit.
String? _waveStatusText(double? waveHeightMeters, UnitSystem unitSystem) {
  if (waveHeightMeters == null) return null;
  if (waveHeightMeters >= highWaveHeightM) {
    return 'Rough — above the '
        '${formatWaveHeight(highWaveHeightM, unitSystem)} threshold most '
        'swimmers should avoid.';
  }
  if (waveHeightMeters >= moderateWaveHeightM) {
    return 'Choppy — above the '
        '${formatWaveHeight(moderateWaveHeightM, unitSystem)} calm-water '
        'threshold.';
  }
  return 'Calm — below the '
      '${formatWaveHeight(moderateWaveHeightM, unitSystem)} calm-water '
      'threshold.';
}

/// Index of the hourly entry at or immediately before [now] (treated as
/// "the current hour"); the last index if every entry is before [now]; `0`
/// if every entry is after [now] (e.g. the series starts in the future).
/// `null` only when [hourly] is empty.
///
/// A copy of `pressure_detail_screen.dart`'s `nowHourIndex` (issue #165's
/// own doc comment on it says to keep it as a small per-screen copy rather
/// than share it across metric screens), adapted to [SeaHourly] instead of
/// `WeatherHourly`.
int? nowHourIndex(List<SeaHourly> hourly, DateTime now) {
  if (hourly.isEmpty) return null;
  var best = 0;
  for (var i = 0; i < hourly.length; i++) {
    if (hourly[i].time.isAfter(now)) break;
    best = i;
  }
  return best;
}

/// Wave height detail screen (issue #167): the day's hourly wave height
/// (`SeaHourly.waveHeight`) as a chart with the two swim-suitability
/// threshold lines (0.6 m "choppy" / 1.2 m "rough", from
/// `swim_suitability.dart`), a min/max/now summary, a one-line status
/// against those thresholds, and — underneath the chart — the day's wave
/// period and direction per hour (an arrow + cardinal label, using the
/// "coming from" convention from issue #154, plus the period in seconds).
///
/// Pushed from [SeaConditionsRow]'s wave height tile via
/// `buildDetailRoute(DetailMetric.waveHeight, ...)`
/// (`lib/presentation/navigation/detail_routes.dart`).
class WaveHeightDetailScreen extends StatelessWidget {
  const WaveHeightDetailScreen({
    super.key,
    required this.hourly,
    this.currentWaveHeightMeters,
    this.unitSystem = UnitSystem.metric,
    this.now,
  });

  /// The day's hourly marine series (wave height/period/direction), oldest
  /// first (as the API returns it) — not pre-sliced to "upcoming only"
  /// like Home's hourly row, since this screen also shows the hours before
  /// "now" for the day's min/max.
  final List<SeaHourly> hourly;

  /// `MarineProvider.currentData`'s "current" wave height reading (in
  /// meters), shown as the hero value. Falls back to the nearest hourly
  /// entry's own wave height when null, so the hero value still renders
  /// for a caller that only has the hourly series.
  final double? currentWaveHeightMeters;

  /// The user's display-unit preference (meters or feet). Defaults to
  /// metric, matching every other caller's default across the app.
  final UnitSystem unitSystem;

  /// Overridable "now" source, so widget tests can pin it instead of
  /// depending on the real clock. Defaults to [DateTime.now].
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final nowTime = (now ?? DateTime.now)();
    final nowIndex = nowHourIndex(hourly, nowTime);
    final nowEntryHeight = nowIndex == null
        ? null
        : hourly[nowIndex].waveHeight;
    final heroMeters = currentWaveHeightMeters ?? nowEntryHeight;

    final presentValues = hourly
        .map((entry) => entry.waveHeight)
        .whereType<double>()
        .toList();
    final minMeters = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a < b ? a : b);
    final maxMeters = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a > b ? a : b);

    // The whole series (not just this screen's hero value) has no wave
    // height at all — e.g. very close to shore, where the marine model's
    // grid is too coarse. Showing an empty chart plus an empty
    // period/direction row would just be a wall of "No data"/"--"; a single
    // explicit message is clearer.
    final hasWaveSeries = presentValues.isNotEmpty;

    return MetricDetailScaffold(
      title: 'Wave Height',
      heroValue: _formatValue(heroMeters, unitSystem) ?? '--',
      heroUnit: heroMeters == null ? null : _unitLabel(unitSystem),
      trendText: _waveStatusText(heroMeters, unitSystem),
      chart: hasWaveSeries
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HourlyMetricChart(
                  points: [
                    for (final entry in hourly)
                      HourlyChartPoint(
                        time: entry.time,
                        value: entry.waveHeight == null
                            ? null
                            : _displayMeters(entry.waveHeight!, unitSystem),
                      ),
                  ],
                  nowIndex: nowIndex,
                  thresholds: [
                    HourlyChartThreshold(
                      value: _displayMeters(moderateWaveHeightM, unitSystem),
                      color: _choppyThresholdColor,
                      label:
                          'Choppy '
                          '(${formatWaveHeight(moderateWaveHeightM, unitSystem)})',
                    ),
                    HourlyChartThreshold(
                      value: _displayMeters(highWaveHeightM, unitSystem),
                      color: _roughThresholdColor,
                      label:
                          'Rough '
                          '(${formatWaveHeight(highWaveHeightM, unitSystem)})',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Wave period & direction',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _PeriodDirectionRow(hourly: hourly, nowIndex: nowIndex),
              ],
            )
          : const SizedBox(
              key: Key('wave-height-no-data'),
              height: 160,
              child: Center(
                child: Text(
                  noWaveDataForLocationText,
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ),
            ),
      minValueLabel: _formatValue(minMeters, unitSystem) ?? '--',
      nowValueLabel: _formatValue(heroMeters, unitSystem) ?? '--',
      maxValueLabel: _formatValue(maxMeters, unitSystem) ?? '--',
      explanation:
          'Wave height tracks how big the swell is right now. BeachIQ treats '
          '${formatWaveHeight(moderateWaveHeightM, unitSystem)} and '
          '${formatWaveHeight(highWaveHeightM, unitSystem)} as the points '
          'where casual swimmers should get more careful, then stay out — '
          'the same cutoffs behind the home screen\'s swim suggestion.',
    );
  }
}

/// A horizontally scrollable row showing [SeaHourly.wavePeriod]/
/// [SeaHourly.waveDirection] for every hour in [hourly], one
/// [_PeriodDirectionTile] per hour, with the entry at [nowIndex] labeled
/// "Now" instead of its clock time.
class _PeriodDirectionRow extends StatelessWidget {
  const _PeriodDirectionRow({required this.hourly, required this.nowIndex});

  final List<SeaHourly> hourly;
  final int? nowIndex;

  /// e.g. "Now", "3PM" — a small per-screen copy of `home_screen.dart`'s
  /// private `_hourLabel`, the same 12-hour-clock format used for the
  /// hourly forecast row.
  String _hourLabel(DateTime time, int index) {
    if (index == nowIndex) return 'Now';
    final hour = time.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour$period';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hourly.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final entry = hourly[index];
          return _PeriodDirectionTile(
            timeLabel: _hourLabel(entry.time, index),
            waveDirectionDegrees: entry.waveDirection,
            wavePeriodSeconds: entry.wavePeriod,
          );
        },
      ),
    );
  }
}

/// One hour's wave period + direction: a time label, a rotated arrow +
/// cardinal label (e.g. "from NW", null-safe — "No data" and a
/// non-rotated arrow when [waveDirectionDegrees] is null), and the period
/// in seconds underneath ("--" when [wavePeriodSeconds] is null). Mirrors
/// `sea_conditions_row.dart`'s `_SeaDirectionStatTile` visual language.
class _PeriodDirectionTile extends StatelessWidget {
  const _PeriodDirectionTile({
    required this.timeLabel,
    required this.waveDirectionDegrees,
    required this.wavePeriodSeconds,
  });

  final String timeLabel;
  final double? waveDirectionDegrees;
  final double? wavePeriodSeconds;

  @override
  Widget build(BuildContext context) {
    final rotationDegrees = _arrowRotationDegrees(waveDirectionDegrees);
    final directionLabel = _waveDirectionLabel(waveDirectionDegrees);
    final periodLabel = _formatPeriod(wavePeriodSeconds);
    return Semantics(
      label: '$timeLabel, $directionLabel, $periodLabel',
      excludeSemantics: true,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeLabel,
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Transform.rotate(
              angle: rotationDegrees == null
                  ? 0
                  : rotationDegrees * math.pi / 180,
              child: const Icon(
                Icons.navigation,
                size: 18,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              directionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              periodLabel,
              style: const TextStyle(color: _textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
