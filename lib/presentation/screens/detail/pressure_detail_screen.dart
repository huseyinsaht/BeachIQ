import 'package:flutter/material.dart';

import '../../../data/models/weather_condition.dart';
import '../../../logic/pressure_trend.dart';
import '../../widgets/hourly_metric_chart.dart';
import '../../widgets/metric_detail_scaffold.dart';

/// How many hourly entries back from "now" the trend classifier looks to
/// decide rising/steady/falling — 3 hours, matching the ~1 hPa/3h "rapid
/// change" convention documented on [pressureTrendThresholdHpa].
const int pressureTrendLookbackHours = 3;

/// A sea-level pressure reading at or below this line is a notably deep
/// low (docs/design.md's stat-grid note puts normal sea-level pressure at
/// ~1000-1030 hPa), drawn as a threshold line on the chart.
const double pressureStormRiskThresholdHpa = 1000;

String _formatHpa(double? hpa) => hpa == null ? '--' : '${hpa.round()} hPa';

/// Index of the hourly entry at or immediately before [now] (treated as
/// "the current hour"); the last index if every entry is before [now]; `0`
/// if every entry is after [now] (e.g. the series starts in the future).
/// `null` only when [hourly] is empty.
///
/// Mirrors `home_screen.dart`'s `_upcomingHourly` start-index search, kept
/// as its own (tiny) copy here: this screen needs the *index* itself, not
/// a sublist starting there, since it also wants the hours before "now"
/// for the trend lookback and the day's min/max.
int? nowHourIndex(List<WeatherHourly> hourly, DateTime now) {
  if (hourly.isEmpty) return null;
  var best = 0;
  for (var i = 0; i < hourly.length; i++) {
    if (hourly[i].time.isAfter(now)) break;
    best = i;
  }
  return best;
}

/// Pressure detail screen (issue #165): the day's hourly sea-level
/// pressure (`WeatherHourly.pressureHpa`) as a chart with a "Now" marker,
/// a min/max/now summary, and a rising/steady/falling trend classified by
/// [classifyPressureTrend] (comparing "now" to [pressureTrendLookbackHours]
/// hours earlier).
///
/// Pushed from [HomeScreen]'s pressure `StatTile` via
/// `buildDetailRoute(DetailMetric.pressure, ...)`
/// (`lib/presentation/navigation/detail_routes.dart`).
class PressureDetailScreen extends StatelessWidget {
  const PressureDetailScreen({
    super.key,
    required this.hourly,
    this.currentPressureHpa,
    this.now,
  });

  /// The day's hourly pressure series, oldest first (as the API returns
  /// it) — not pre-sliced to "upcoming only" like Home's hourly row, since
  /// this screen also shows the hours before "now" for the trend lookback
  /// and the day's min/max.
  final List<WeatherHourly> hourly;

  /// The weather provider's "current" pressure reading, shown as the hero
  /// value. Falls back to the nearest hourly entry's own pressure when
  /// null, so the hero value still renders for a caller that only has the
  /// hourly series.
  final double? currentPressureHpa;

  /// Overridable "now" source, so widget tests can pin it instead of
  /// depending on the real clock. Defaults to [DateTime.now].
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final nowTime = (now ?? DateTime.now)();
    final nowIndex = nowHourIndex(hourly, nowTime);
    final nowEntryHpa = nowIndex == null ? null : hourly[nowIndex].pressureHpa;
    final heroValue = currentPressureHpa ?? nowEntryHpa;

    final presentValues = hourly
        .map((entry) => entry.pressureHpa)
        .whereType<double>()
        .toList();
    final minValue = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a < b ? a : b);
    final maxValue = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a > b ? a : b);

    final earlierIndex = nowIndex == null
        ? null
        : nowIndex - pressureTrendLookbackHours;
    final earlierHpa = (earlierIndex != null && earlierIndex >= 0)
        ? hourly[earlierIndex].pressureHpa
        : null;
    final trend = classifyPressureTrend(
      currentHpa: nowEntryHpa ?? heroValue,
      earlierHpa: earlierHpa,
    );

    return MetricDetailScaffold(
      title: 'Pressure',
      heroValue: heroValue == null ? '--' : heroValue.round().toString(),
      heroUnit: heroValue == null ? null : 'hPa',
      trendText: trend == null
          ? 'Not enough data yet to show a pressure trend.'
          : '${pressureTrendLabel(trend)} — pressure is '
                '${pressureTrendExplanation(trend)}',
      chart: HourlyMetricChart(
        points: [
          for (final entry in hourly)
            HourlyChartPoint(time: entry.time, value: entry.pressureHpa),
        ],
        nowIndex: nowIndex,
        thresholds: const [
          HourlyChartThreshold(
            value: pressureStormRiskThresholdHpa,
            color: Color(0xFFEF5350),
            label: 'Low pressure',
          ),
        ],
      ),
      minValueLabel: _formatHpa(minValue),
      nowValueLabel: _formatHpa(heroValue),
      maxValueLabel: _formatHpa(maxValue),
      explanation:
          'Sea-level pressure reflects how the air above is moving. Rising '
          'pressure usually brings clearer, calmer weather; falling '
          'pressure often means clouds, wind or rain are on the way.',
    );
  }
}
