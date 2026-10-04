import 'package:flutter/material.dart';

import '../../../data/models/sea_condition.dart';
import '../../../logic/unit_preferences.dart';
import '../../widgets/hourly_metric_chart.dart';
import '../../widgets/metric_detail_scaffold.dart';

/// Water-temperature comfort bands (issue #180's documented constants, in
/// Celsius — the unit [SeaHourly.seaSurfaceTemperature] is always given in):
/// below 16 C is [cold], 16-20 C [cool], 20-24 C [pleasant], above 24 C
/// [warm].
enum WaterTempBand { cold, cool, pleasant, warm }

// The band cutoffs, in Celsius (see [WaterTempBand]'s doc comment). Each
// cutoff is the first value that belongs to the *next* band (e.g. exactly
// 16.0 is already "cool", not "cold") - see `waterTempBandFor`'s tests for
// the exact boundary cases.
const double _coolCutoffC = 16;
const double _pleasantCutoffC = 20;
const double _warmCutoffC = 24;

/// Classifies a sea surface temperature reading (in Celsius) into its
/// [WaterTempBand].
///
/// Pure function: the same input always returns the same band, with no
/// side effects.
WaterTempBand waterTempBandFor(double celsius) {
  if (celsius < _coolCutoffC) return WaterTempBand.cold;
  if (celsius < _pleasantCutoffC) return WaterTempBand.cool;
  if (celsius < _warmCutoffC) return WaterTempBand.pleasant;
  return WaterTempBand.warm;
}

/// A short capitalized label for [band] (e.g. "Pleasant"), for the water
/// temperature detail screen's hero trend line.
String waterTempBandLabel(WaterTempBand band) {
  switch (band) {
    case WaterTempBand.cold:
      return 'Cold';
    case WaterTempBand.cool:
      return 'Cool';
    case WaterTempBand.pleasant:
      return 'Pleasant';
    case WaterTempBand.warm:
      return 'Warm';
  }
}

/// A one-line comfort hint for [band], shown under the water temperature
/// detail screen's hero value (after [waterTempBandLabel] and a dash,
/// matching `uv_band.dart`'s `uvBandLabel`/`uvProtectionHint` pairing).
String waterTempComfortHint(WaterTempBand band) {
  switch (band) {
    case WaterTempBand.cold:
      return 'too cold for most swimmers without a wetsuit.';
    case WaterTempBand.cool:
      return 'bracing, but fine for a quick dip.';
    case WaterTempBand.pleasant:
      return 'comfortable for most swimmers.';
    case WaterTempBand.warm:
      return 'warm and comfortable, even for a long swim.';
  }
}

/// A floor well below any realistic sea surface temperature in either unit
/// system, so [_waterTempChartBands]'s coldest band always reads as
/// "open-ended on the low side" (the chart widget clips a band's [min]
/// against its own visible range — see `HourlyMetricChart`'s doc comment —
/// there is no literal "no minimum" the band class can express).
const double _openLowFloorC = -50;

/// The four comfort bands as colored chart backgrounds, converted to
/// [unitSystem]'s display unit. Colors are distinct from UV index's bands
/// (issue #178) and the swim-verdict palette: blue for cold, teal for cool,
/// green for pleasant, amber for warm — each at ~20% opacity (hex alpha
/// `33`) so the data line and "Now" marker stay legible on top of them.
List<HourlyChartValueBand> _waterTempChartBands(UnitSystem unitSystem) {
  return [
    HourlyChartValueBand(
      min: _displayCelsius(_openLowFloorC, unitSystem),
      max: _displayCelsius(_coolCutoffC, unitSystem),
      color: const Color(0x334FC3F7),
      label: 'Cold',
    ),
    HourlyChartValueBand(
      min: _displayCelsius(_coolCutoffC, unitSystem),
      max: _displayCelsius(_pleasantCutoffC, unitSystem),
      color: const Color(0x334DD0E1),
      label: 'Cool',
    ),
    HourlyChartValueBand(
      min: _displayCelsius(_pleasantCutoffC, unitSystem),
      max: _displayCelsius(_warmCutoffC, unitSystem),
      color: const Color(0x3366BB6A),
      label: 'Pleasant',
    ),
    HourlyChartValueBand(
      min: _displayCelsius(_warmCutoffC, unitSystem),
      color: const Color(0x33FFA726),
      label: 'Warm',
    ),
  ];
}

/// Converts [celsius] to the unit [unitSystem] displays, mirroring
/// `unit_preferences.dart`'s `formatTemperature` but returning the raw
/// number (for chart points/bands, which need a `double`, not a formatted
/// string).
double _displayCelsius(double celsius, UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial ? celsiusToFahrenheit(celsius) : celsius;

String _formatValue(double? celsius, UnitSystem unitSystem) => celsius == null
    ? '--'
    : _displayCelsius(celsius, unitSystem).round().toString();

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

/// Shown in place of the chart when [SeaHourly.seaSurfaceTemperature] is
/// null for every hour in the series (including an empty series) — this
/// location simply has no water-temperature forecast.
const String noWaterTempDataForLocationText = 'No data for this location.';

/// Water temperature detail screen (issue #180): the day's hourly sea
/// surface temperature (`SeaHourly.seaSurfaceTemperature`) as a chart with
/// the four colored comfort bands ([_waterTempChartBands]) and a "Now"
/// marker, a min/max/now summary, and a one-line comfort hint for the
/// current reading's [WaterTempBand].
///
/// Pushed from [SeaConditionsRow]'s water temperature tile via
/// `buildDetailRoute(DetailMetric.waterTemperature, ...)`
/// (`lib/presentation/navigation/detail_routes.dart`).
class WaterTemperatureDetailScreen extends StatelessWidget {
  const WaterTemperatureDetailScreen({
    super.key,
    required this.hourly,
    this.currentWaterTemperatureCelsius,
    this.unitSystem = UnitSystem.metric,
    this.now,
  });

  /// The day's hourly marine series, oldest first (as the API returns it)
  /// — not pre-sliced to "upcoming only" like Home's hourly row, since this
  /// screen also shows the hours before "now" for the day's min/max.
  final List<SeaHourly> hourly;

  /// `MarineProvider.currentData`'s "current" sea surface temperature
  /// reading (in Celsius), shown as the hero value. Falls back to the
  /// nearest hourly entry's own reading when null, so the hero value still
  /// renders for a caller that only has the hourly series.
  final double? currentWaterTemperatureCelsius;

  /// The user's display-unit preference (Celsius or Fahrenheit). Defaults
  /// to metric, matching every other caller's default across the app.
  final UnitSystem unitSystem;

  /// Overridable "now" source, so widget tests can pin it instead of
  /// depending on the real clock. Defaults to [DateTime.now].
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final nowTime = (now ?? DateTime.now)();
    final nowIndex = nowHourIndex(hourly, nowTime);
    final nowEntryCelsius = nowIndex == null
        ? null
        : hourly[nowIndex].seaSurfaceTemperature;
    final heroCelsius = currentWaterTemperatureCelsius ?? nowEntryCelsius;

    final presentValues = hourly
        .map((entry) => entry.seaSurfaceTemperature)
        .whereType<double>()
        .toList();
    final minCelsius = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a < b ? a : b);
    final maxCelsius = presentValues.isEmpty
        ? null
        : presentValues.reduce((a, b) => a > b ? a : b);
    final hasSeries = presentValues.isNotEmpty;

    final band = heroCelsius == null ? null : waterTempBandFor(heroCelsius);

    return MetricDetailScaffold(
      title: 'Water Temperature',
      heroValue: _formatValue(heroCelsius, unitSystem),
      heroUnit: heroCelsius == null
          ? null
          : (unitSystem == UnitSystem.imperial ? '°F' : '°C'),
      trendText: band == null
          ? 'Not enough data yet to show a comfort tip.'
          : '${waterTempBandLabel(band)} — ${waterTempComfortHint(band)}',
      chart: hasSeries
          ? HourlyMetricChart(
              points: [
                for (final entry in hourly)
                  HourlyChartPoint(
                    time: entry.time,
                    value: entry.seaSurfaceTemperature == null
                        ? null
                        : _displayCelsius(
                            entry.seaSurfaceTemperature!,
                            unitSystem,
                          ),
                  ),
              ],
              nowIndex: nowIndex,
              valueBands: _waterTempChartBands(unitSystem),
              valueFormatter: (value) => value.round().toString(),
              unitLabel: unitSystem == UnitSystem.imperial ? '°F' : '°C',
            )
          : const SizedBox(
              key: Key('water-temperature-no-data'),
              height: 160,
              child: Center(
                child: Text(
                  noWaterTempDataForLocationText,
                  style: TextStyle(color: Color(0xFF8B93A6), fontSize: 13),
                ),
              ),
            ),
      minValueLabel: _formatValue(minCelsius, unitSystem),
      nowValueLabel: _formatValue(heroCelsius, unitSystem),
      maxValueLabel: _formatValue(maxCelsius, unitSystem),
      explanation:
          'Water temperature affects how long you can comfortably stay in '
          'the sea. BeachIQ treats '
          '${formatTemperature(_coolCutoffC, unitSystem)}, '
          '${formatTemperature(_pleasantCutoffC, unitSystem)} and '
          '${formatTemperature(_warmCutoffC, unitSystem)} as the points '
          'between cold, cool, pleasant and warm water.',
    );
  }
}
