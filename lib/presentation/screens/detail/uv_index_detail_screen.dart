import 'package:flutter/material.dart';

import '../../../data/models/weather_condition.dart';
import '../../../logic/uv_band.dart';
import '../../widgets/hourly_metric_chart.dart';
import '../../widgets/metric_detail_scaffold.dart';

String _formatUv(double? uv) => uv == null ? '--' : uv.toStringAsFixed(1);

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

// The five UV index bands as colored chart backgrounds (issue #178), using
// the standard WHO/EPA UV-index color scale (green -> yellow -> orange ->
// red -> violet) so the bands read correctly to anyone already familiar
// with UV forecasts, while staying distinguishable from this app's own
// palette (docs/design.md's `icon.sun` #FFC94D and the swim-verdict pill
// greens/oranges/reds): violet in particular is not used anywhere else in
// BeachIQ. Each is drawn at ~20% opacity (alpha `0x33`) over `uvBandColor`'s
// solid hue (the same color the Home stat grid's UV tile shows at full
// opacity, issue #215) so the data line and "Now" marker stay legible on
// top of them. Boundaries match `uvBandFor`'s cutoffs exactly (3 / 6 / 8 /
// 11); the top band has no `max`, extending to the top of the chart's
// visible range.
List<HourlyChartValueBand> get uvChartBands => [
  HourlyChartValueBand(
    min: 0,
    max: 3,
    color: uvBandColor(UvBand.low).withAlpha(0x33),
    label: 'Low',
  ),
  HourlyChartValueBand(
    min: 3,
    max: 6,
    color: uvBandColor(UvBand.moderate).withAlpha(0x33),
    label: 'Moderate',
  ),
  HourlyChartValueBand(
    min: 6,
    max: 8,
    color: uvBandColor(UvBand.high).withAlpha(0x33),
    label: 'High',
  ),
  HourlyChartValueBand(
    min: 8,
    max: 11,
    color: uvBandColor(UvBand.veryHigh).withAlpha(0x33),
    label: 'Very high',
  ),
  HourlyChartValueBand(
    min: 11,
    color: uvBandColor(UvBand.extreme).withAlpha(0x33),
    label: 'Extreme',
  ),
];

/// UV index detail screen (issue #178): the day's hourly UV index
/// (`WeatherHourly.uvIndex`) as a chart with the five colored risk bands
/// (`uvChartBands`) and a "Now" marker, a min/max/now summary, and a
/// one-line sun-protection hint for the current reading's [UvBand]
/// (`uvBandFor`/`uvProtectionHint`).
///
/// Pushed from [HomeScreen]'s UV index `StatTile` via
/// `buildDetailRoute(DetailMetric.uvIndex, ...)`
/// (`lib/presentation/navigation/detail_routes.dart`).
class UvIndexDetailScreen extends StatelessWidget {
  const UvIndexDetailScreen({
    super.key,
    required this.hourly,
    this.currentUvIndex,
    this.now,
  });

  /// The day's hourly UV index series, oldest first (as the API returns
  /// it) — not pre-sliced to "upcoming only" like Home's hourly row, since
  /// this screen also shows the hours before "now" for the day's min/max.
  final List<WeatherHourly> hourly;

  /// The weather provider's "current" UV index reading, shown as the hero
  /// value. Falls back to the nearest hourly entry's own UV index when
  /// null, so the hero value still renders for a caller that only has the
  /// hourly series.
  final double? currentUvIndex;

  /// Overridable "now" source, so widget tests can pin it instead of
  /// depending on the real clock. Defaults to [DateTime.now].
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final nowTime = (now ?? DateTime.now)();
    final nowIndex = nowHourIndex(hourly, nowTime);
    final nowEntryUv = nowIndex == null ? null : hourly[nowIndex].uvIndex;
    final heroValue = currentUvIndex ?? nowEntryUv;

    final presentValues = hourly
        .map((entry) => entry.uvIndex)
        .whereType<double>()
        .toList();
    final minValue = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a < b ? a : b);
    final maxValue = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a > b ? a : b);

    final band = heroValue == null ? null : uvBandFor(heroValue);

    return MetricDetailScaffold(
      title: 'UV Index',
      heroValue: _formatUv(heroValue),
      statusLabel: band == null ? null : uvBandLabel(band),
      statusColor: band == null ? null : uvBandColor(band),
      trendText: band == null
          ? 'Not enough data yet to show a sun-protection tip.'
          : '${uvBandLabel(band)} — ${uvProtectionHint(band)}',
      chart: HourlyMetricChart(
        points: [
          for (final entry in hourly)
            HourlyChartPoint(time: entry.time, value: entry.uvIndex),
        ],
        nowIndex: nowIndex,
        valueBands: uvChartBands,
        valueFormatter: (value) => value.toStringAsFixed(1),
      ),
      minValueLabel: _formatUv(minValue),
      nowValueLabel: _formatUv(heroValue),
      maxValueLabel: _formatUv(maxValue),
      explanation:
          'The UV index measures how strong the sun\'s ultraviolet '
          'radiation is right now. Higher values mean skin and eyes burn '
          'faster, so the protection you need — shade, sunscreen, a hat — '
          'scales up with it.',
    );
  }
}
