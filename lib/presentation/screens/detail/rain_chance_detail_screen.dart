import 'package:flutter/material.dart';

import '../../../data/models/weather_condition.dart';
import '../../../logic/rain_windows.dart';
import '../../../logic/swim_suitability.dart';
import '../../widgets/hourly_metric_chart.dart';
import '../../widgets/metric_detail_scaffold.dart';

/// The chart's two swim-suitability threshold lines, reusing
/// `swim_suitability.dart`'s exact cutoffs (never re-derived here) so this
/// screen can never drift from the numbers behind the home screen's swim
/// suggestion pill. Colors match the wave height/wind detail screens'
/// moderate/high thresholds.
const Color _moderateThresholdColor = Color(0xFFFFA726);
const Color _highThresholdColor = Color(0xFFEF5350);

String _formatPercent(double? percent) =>
    percent == null ? '--' : '${percent.round()}%';

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

/// Rain chance detail screen (issue #179): the day's hourly rain
/// probability (`WeatherHourly.rainChancePercent`) as a chart with the two
/// swim-relevant threshold lines (40%/70%, from `swim_suitability.dart`),
/// a min/max/now summary, and a plain-language summary of the upcoming
/// rain windows (`rain_windows.dart`), e.g. "Rain likely between 14:00 and
/// 17:00." or "No rain expected today.".
///
/// Pushed from [HomeScreen]'s rain chance `StatTile` via
/// `buildDetailRoute(DetailMetric.rainChance, ...)`
/// (`lib/presentation/navigation/detail_routes.dart`).
class RainChanceDetailScreen extends StatelessWidget {
  const RainChanceDetailScreen({
    super.key,
    required this.hourly,
    this.currentRainChancePercent,
    this.now,
  });

  /// The day's hourly weather series, oldest first (as the API returns
  /// it) — not pre-sliced to "upcoming only" like Home's hourly row, since
  /// this screen also shows the hours before "now" for the day's min/max.
  /// The rain-window summary only considers hours at/after [now] (see
  /// [rainChanceWindows]'s own future-only callers elsewhere in the app
  /// for the same convention) by filtering here before calling it.
  final List<WeatherHourly> hourly;

  /// `WeatherProvider.currentData`'s "current" rain chance reading (in
  /// percent), shown as the hero value. Falls back to the nearest hourly
  /// entry's own reading when null, so the hero value still renders for a
  /// caller that only has the hourly series.
  final double? currentRainChancePercent;

  /// Overridable "now" source, so widget tests can pin it instead of
  /// depending on the real clock. Defaults to [DateTime.now].
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final nowTime = (now ?? DateTime.now)();
    final nowIndex = nowHourIndex(hourly, nowTime);
    final nowEntryPercent = nowIndex == null
        ? null
        : hourly[nowIndex].rainChancePercent;
    final heroPercent = currentRainChancePercent ?? nowEntryPercent;

    final presentValues = hourly
        .map((entry) => entry.rainChancePercent)
        .whereType<double>()
        .toList();
    final minPercent = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a < b ? a : b);
    final maxPercent = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a > b ? a : b);

    // Only upcoming hours can start/extend a reported window — a rain
    // window that was only ever in the past isn't something to warn about
    // "today" from here on.
    final upcoming = [
      for (final entry in hourly)
        if (!entry.time.isBefore(nowTime)) entry,
    ];
    final windows = rainChanceWindows(upcoming);
    final summary = rainChanceSummary(windows);

    return MetricDetailScaffold(
      title: 'Rain Chance',
      heroValue: _formatPercent(heroPercent),
      trendText: summary,
      chart: HourlyMetricChart(
        points: [
          for (final entry in hourly)
            HourlyChartPoint(time: entry.time, value: entry.rainChancePercent),
        ],
        nowIndex: nowIndex,
        thresholds: [
          HourlyChartThreshold(
            value: moderateRainChancePercent.toDouble(),
            color: _moderateThresholdColor,
            label: 'Likely ($moderateRainChancePercent%)',
          ),
          HourlyChartThreshold(
            value: highRainChancePercent.toDouble(),
            color: _highThresholdColor,
            label: 'High ($highRainChancePercent%)',
          ),
        ],
      ),
      minValueLabel: _formatPercent(minPercent),
      nowValueLabel: _formatPercent(heroPercent),
      maxValueLabel: _formatPercent(maxPercent),
      explanation:
          'Rain chance is the forecast probability of rain each hour. '
          'BeachIQ treats $moderateRainChancePercent% and '
          '$highRainChancePercent% as the points where a wet towel becomes '
          'likely, then a storm risk — the same cutoffs behind the home '
          "screen's swim suggestion.",
    );
  }
}
