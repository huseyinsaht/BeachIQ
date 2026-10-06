import 'package:flutter/material.dart';

import '../../../data/models/weather_condition.dart';
import '../../../logic/swim_suitability.dart';
import '../../../logic/unit_preferences.dart';
import '../../../logic/wind_status.dart';
import '../../widgets/hourly_metric_chart.dart';
import '../../widgets/metric_detail_scaffold.dart';

const Color _textSecondary = Color(0xFF8B93A6);

/// The chart's two swim-suitability threshold lines, reusing
/// `swim_suitability.dart`'s exact cutoffs (never re-derived here) so this
/// screen can never drift from the numbers behind the home screen's swim
/// suggestion pill. Colors match the wave height detail screen's choppy/
/// rough thresholds, so red consistently flags "be careful" across the app.
const Color _moderateThresholdColor = Color(0xFFFFA726);
const Color _highThresholdColor = Color(0xFFEF5350);

/// Converts [kmh] to the unit [unitSystem] displays, mirroring
/// `unit_preferences.dart`'s `formatWindSpeed` but returning the raw number
/// (for chart points/thresholds, which need a `double`, not a formatted
/// string).
double _displayKmh(double kmh, UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial ? kmhToMph(kmh) : kmh;

String _unitLabel(UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial ? 'mph' : 'km/h';

/// Formats a wind speed already in km/h as a bare number (no unit) in
/// [unitSystem], e.g. `"12"` or `"7"` — the hero/min/max summary values show
/// their unit separately, matching the pressure/UV/wave height detail
/// screens.
String? _formatValue(double? kmh, UnitSystem unitSystem) {
  if (kmh == null) return null;
  return _displayKmh(kmh, unitSystem).round().toString();
}

/// A one-line status comparing [windSpeedKmh] against the swim thresholds
/// from `swim_suitability.dart`, in [unitSystem]'s unit.
String? _windStatusText(double? windSpeedKmh, UnitSystem unitSystem) {
  if (windSpeedKmh == null) return null;
  if (windSpeedKmh >= highWindSpeedKmh) {
    return 'Strong — above the '
        '${formatWindSpeed(highWindSpeedKmh, unitSystem)} threshold most '
        'swimmers should avoid.';
  }
  if (windSpeedKmh >= moderateWindSpeedKmh) {
    return 'Moderate — above the '
        '${formatWindSpeed(moderateWindSpeedKmh, unitSystem)} calm-air '
        'threshold.';
  }
  return 'Calm — below the '
      '${formatWindSpeed(moderateWindSpeedKmh, unitSystem)} calm-air '
      'threshold.';
}

/// Index of the hourly entry at or immediately before [now] (treated as
/// "the current hour"); the last index if every entry is before [now]; `0`
/// if every entry is after [now] (e.g. the series starts in the future).
/// `null` only when [hourly] is empty.
///
/// A copy of `pressure_detail_screen.dart`'s `nowHourIndex` (issue #165's
/// own doc comment on it says to keep it as a small per-screen copy rather
/// than share it across metric screens).
int? nowHourIndex(List<WeatherHourly> hourly, DateTime now) {
  if (hourly.isEmpty) return null;
  var best = 0;
  for (var i = 0; i < hourly.length; i++) {
    if (hourly[i].time.isAfter(now)) break;
    best = i;
  }
  return best;
}

/// Wind speed detail screen (issue #166): the day's hourly wind speed
/// (`WeatherHourly.windSpeed`) as a chart with the two swim-relevant
/// threshold lines (20/40 km/h "moderate"/"strong", from
/// `swim_suitability.dart`), a min/max/now summary, a one-line status
/// against those thresholds, and — underneath the chart — the day's wind
/// gusts as a second chart.
///
/// Pushed from [HomeScreen]'s wind speed `StatTile` via
/// `buildDetailRoute(DetailMetric.wind, ...)`
/// (`lib/presentation/navigation/detail_routes.dart`).
class WindDetailScreen extends StatelessWidget {
  const WindDetailScreen({
    super.key,
    required this.hourly,
    this.currentWindSpeedKmh,
    this.unitSystem = UnitSystem.metric,
    this.now,
  });

  /// The day's hourly weather series, oldest first (as the API returns
  /// it) — not pre-sliced to "upcoming only" like Home's hourly row, since
  /// this screen also shows the hours before "now" for the day's min/max.
  final List<WeatherHourly> hourly;

  /// `WeatherProvider.currentData`'s "current" wind speed reading (in
  /// km/h), shown as the hero value. Falls back to the nearest hourly
  /// entry's own wind speed when null, so the hero value still renders for
  /// a caller that only has the hourly series.
  final double? currentWindSpeedKmh;

  /// The user's display-unit preference (km/h or mph). Defaults to metric,
  /// matching every other caller's default across the app.
  final UnitSystem unitSystem;

  /// Overridable "now" source, so widget tests can pin it instead of
  /// depending on the real clock. Defaults to [DateTime.now].
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final nowTime = (now ?? DateTime.now)();
    final nowIndex = nowHourIndex(hourly, nowTime);
    final nowEntrySpeed = nowIndex == null ? null : hourly[nowIndex].windSpeed;
    final heroKmh = currentWindSpeedKmh ?? nowEntrySpeed;

    final presentSpeeds = hourly
        .map((entry) => entry.windSpeed)
        .whereType<double>()
        .toList();
    final minKmh = presentSpeeds.isEmpty
        ? null
        : presentSpeeds.reduce((a, b) => a < b ? a : b);
    final maxKmh = presentSpeeds.isEmpty
        ? null
        : presentSpeeds.reduce((a, b) => a > b ? a : b);

    final presentGusts = hourly
        .map((entry) => entry.windGusts)
        .whereType<double>()
        .toList();
    final hasGustSeries = presentGusts.isNotEmpty;

    final windStatus = windStatusFor(heroKmh);

    return MetricDetailScaffold(
      title: 'Wind Speed',
      heroValue: _formatValue(heroKmh, unitSystem) ?? '--',
      heroUnit: heroKmh == null ? null : _unitLabel(unitSystem),
      statusLabel: windStatus == null ? null : windStatusLabel(windStatus),
      statusColor: windStatus == null ? null : windStatusColor(windStatus),
      trendText: _windStatusText(heroKmh, unitSystem),
      chart: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HourlyMetricChart(
            points: [
              for (final entry in hourly)
                HourlyChartPoint(
                  time: entry.time,
                  value: entry.windSpeed == null
                      ? null
                      : _displayKmh(entry.windSpeed!, unitSystem),
                ),
            ],
            nowIndex: nowIndex,
            thresholds: [
              HourlyChartThreshold(
                value: _displayKmh(moderateWindSpeedKmh, unitSystem),
                color: _moderateThresholdColor,
                label:
                    'Moderate '
                    '(${formatWindSpeed(moderateWindSpeedKmh, unitSystem)})',
              ),
              HourlyChartThreshold(
                value: _displayKmh(highWindSpeedKmh, unitSystem),
                color: _highThresholdColor,
                label:
                    'Strong '
                    '(${formatWindSpeed(highWindSpeedKmh, unitSystem)})',
              ),
            ],
            valueFormatter: (value) => value.round().toString(),
            unitLabel: _unitLabel(unitSystem),
          ),
          if (hasGustSeries) ...[
            const SizedBox(height: 20),
            const Text(
              'Gusts',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            HourlyMetricChart(
              key: const Key('wind-gusts-chart'),
              points: [
                for (final entry in hourly)
                  HourlyChartPoint(
                    time: entry.time,
                    value: entry.windGusts == null
                        ? null
                        : _displayKmh(entry.windGusts!, unitSystem),
                  ),
              ],
              nowIndex: nowIndex,
              height: 100,
              valueFormatter: (value) => value.round().toString(),
              unitLabel: _unitLabel(unitSystem),
            ),
          ],
        ],
      ),
      minValueLabel: _formatValue(minKmh, unitSystem) ?? '--',
      nowValueLabel: _formatValue(heroKmh, unitSystem) ?? '--',
      maxValueLabel: _formatValue(maxKmh, unitSystem) ?? '--',
      explanation:
          'Wind speed affects how choppy the water gets and how hard it is '
          'to swim back against it. BeachIQ treats '
          '${formatWindSpeed(moderateWindSpeedKmh, unitSystem)} and '
          '${formatWindSpeed(highWindSpeedKmh, unitSystem)} as the points '
          'where casual swimmers should get more careful, then stay out — '
          'the same cutoffs behind the home screen\'s swim suggestion.',
    );
  }
}
