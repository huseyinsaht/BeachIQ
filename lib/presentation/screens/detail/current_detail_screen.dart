import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/sea_condition.dart';
import '../../../logic/unit_preferences.dart';
import '../../../logic/wave_shore_relation.dart';
import '../../widgets/hourly_metric_chart.dart';
import '../../widgets/metric_detail_scaffold.dart';

const Color _textSecondary = Color(0xFF8B93A6);
const Color _warning = Color(0xFFEF5350);

/// Below this current speed (km/h), BeachIQ never shows the drift-out
/// warning even when the current flows away from shore: NOAA swimmer-safety
/// guidance treats currents at or above roughly 0.5 m/s (~1.8 km/h) as
/// strong enough to sweep an average swimmer off their feet
/// (https://oceanservice.noaa.gov/facts/ripcurrent.html), rounded here to a
/// clean 2.0 km/h so weaker outward currents are not flagged as hazardous.
const double driftOutWarningSpeedKmh = 2.0;

/// Converts [kmh] to the unit [unitSystem] displays, mirroring
/// `unit_preferences.dart`'s `formatWindSpeed` but returning the raw number
/// (for chart points, which need a `double`, not a formatted string).
double _displayKmh(double kmh, UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial ? kmhToMph(kmh) : kmh;

String _unitLabel(UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial ? 'mph' : 'km/h';

/// Formats a current speed already in km/h as a bare number (no unit) in
/// [unitSystem], e.g. `"6"` — the hero/min/max summary values show their
/// unit separately, matching the other metric detail screens.
String _formatValue(double? kmh, UnitSystem unitSystem) =>
    kmh == null ? '--' : _displayKmh(kmh, unitSystem).round().toString();

/// Maps a compass bearing (degrees clockwise from true north, any range) to
/// its nearest 8-point cardinal label.
///
/// A copy of `sea_conditions_row.dart`'s `_cardinalLabel` (that file's own
/// doc comments establish the "small per-screen copy" convention for these
/// metric-detail helpers).
String _cardinalLabel(double degrees) {
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final normalized = ((degrees % 360) + 360) % 360;
  final index = ((normalized + 22.5) / 45).floor() % 8;
  return points[index];
}

/// Index of the hourly entry at or immediately before [now] (treated as
/// "the current hour"); the last index if every entry is before [now]; `0`
/// if every entry is after [now]. `null` only when [hourly] is empty.
///
/// A copy of `pressure_detail_screen.dart`'s `nowHourIndex` (issue #165's
/// own doc comment on it says to keep it as a small per-screen copy rather
/// than share it across metric screens), adapted to [SeaHourly].
int? nowHourIndex(List<SeaHourly> hourly, DateTime now) {
  if (hourly.isEmpty) return null;
  var best = 0;
  for (var i = 0; i < hourly.length; i++) {
    if (hourly[i].time.isAfter(now)) break;
    best = i;
  }
  return best;
}

/// Shown in place of the chart when [SeaHourly.currentVelocity] is null for
/// every hour in the series (including an empty series). Open-Meteo's ocean
/// current grid is coarse (several km) and often has no data very close to
/// shore (see `SeaCondition.currentVelocity`'s doc comment) — this message
/// explains that rather than just saying "no data".
const String noCurrentDataForLocationText =
    "Open-Meteo's ocean current data is coarse and often unavailable close "
    'to shore — no data for this location.';

/// A one-line status for the current hero reading: the drift-out warning
/// when it applies, the shore relation otherwise, or an explanation of why
/// neither can be shown — never an invented relation.
String? _statusLine({
  required double? speedKmh,
  required ShoreRelation? relation,
  required bool hasGeometry,
  required UnitSystem unitSystem,
}) {
  if (speedKmh == null) return null;
  final speedLabel = formatWindSpeed(speedKmh, unitSystem);
  if (!hasGeometry) {
    return 'Flowing at $speedLabel. No beach geometry for this location — '
        'shore relation unknown.';
  }
  switch (relation) {
    case null:
      return 'Flowing at $speedLabel. Not enough data to show the shore '
          'relation.';
    case ShoreRelation.awayFromShore:
      return speedKmh >= driftOutWarningSpeedKmh
          ? 'Flowing away from shore at $speedLabel.'
          : 'Flowing away from shore at $speedLabel — below the drift-out '
                'warning threshold.';
    case ShoreRelation.towardShore:
      return 'Flowing toward shore at $speedLabel.';
    case ShoreRelation.alongShore:
      return 'Flowing along the shore at $speedLabel.';
  }
}

/// Ocean current detail screen (issue #181): the day's hourly current speed
/// (`SeaHourly.currentVelocity`) as a chart, an hourly direction arrow strip,
/// and a clear drift-out warning when the current flows
/// [ShoreRelation.awayFromShore] at or above [driftOutWarningSpeedKmh].
///
/// Pushed from [SeaConditionsRow]'s current speed/direction tiles via
/// `buildDetailRoute(DetailMetric.current, ...)`
/// (`lib/presentation/navigation/detail_routes.dart`).
class CurrentDetailScreen extends StatelessWidget {
  const CurrentDetailScreen({
    super.key,
    required this.hourly,
    this.currentSpeedKmh,
    this.currentDirectionDegrees,
    this.seawardBearingDegrees,
    this.unitSystem = UnitSystem.metric,
    this.now,
  });

  /// The day's hourly marine series, oldest first (as the API returns it)
  /// — not pre-sliced to "upcoming only", since this screen also shows the
  /// hours before "now" for the day's min/max and the direction strip.
  final List<SeaHourly> hourly;

  /// `MarineProvider.currentData`'s "current" ocean current speed reading
  /// (in km/h), shown as the hero value. Falls back to the nearest hourly
  /// entry's own reading when null.
  final double? currentSpeedKmh;

  /// `MarineProvider.currentData`'s "current" ocean current direction
  /// (`SeaCondition.currentDirection`'s "flowing toward" convention). Falls
  /// back to the nearest hourly entry's own reading when null.
  final double? currentDirectionDegrees;

  /// The selected beach's shore-normal bearing (see `wave_shore_relation.dart`),
  /// null when no beach geometry is available for the current location — in
  /// that case this screen shows the speed/direction only and NEVER an
  /// invented shore relation.
  final double? seawardBearingDegrees;

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
    final nowEntry = nowIndex == null ? null : hourly[nowIndex];
    final heroSpeed = currentSpeedKmh ?? nowEntry?.currentVelocity;
    final heroDirection = currentDirectionDegrees ?? nowEntry?.currentDirection;

    final presentSpeeds = hourly
        .map((entry) => entry.currentVelocity)
        .whereType<double>()
        .toList();
    final minKmh = presentSpeeds.isEmpty
        ? null
        : presentSpeeds.reduce((a, b) => a < b ? a : b);
    final maxKmh = presentSpeeds.isEmpty
        ? null
        : presentSpeeds.reduce((a, b) => a > b ? a : b);
    final hasSeries = presentSpeeds.isNotEmpty;

    final seaward = seawardBearingDegrees;
    final relation = (seaward == null || heroDirection == null)
        ? null
        : classifyDirection(
            degrees: heroDirection,
            convention: DirectionConvention.flowingToward,
            seawardBearingDegrees: seaward,
          );

    final showDriftWarning =
        relation == ShoreRelation.awayFromShore &&
        heroSpeed != null &&
        heroSpeed >= driftOutWarningSpeedKmh;

    return MetricDetailScaffold(
      title: 'Ocean Current',
      heroValue: _formatValue(heroSpeed, unitSystem),
      heroUnit: heroSpeed == null ? null : _unitLabel(unitSystem),
      trendText: _statusLine(
        speedKmh: heroSpeed,
        relation: relation,
        hasGeometry: seaward != null,
        unitSystem: unitSystem,
      ),
      chart: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDriftWarning)
            _DriftOutWarningBanner(
              speedLabel: formatWindSpeed(heroSpeed, unitSystem),
            ),
          if (showDriftWarning) const SizedBox(height: 16),
          hasSeries
              ? HourlyMetricChart(
                  points: [
                    for (final entry in hourly)
                      HourlyChartPoint(
                        time: entry.time,
                        value: entry.currentVelocity == null
                            ? null
                            : _displayKmh(entry.currentVelocity!, unitSystem),
                      ),
                  ],
                  nowIndex: nowIndex,
                )
              : SizedBox(
                  key: const Key('current-no-data'),
                  height: 160,
                  child: Center(
                    child: Text(
                      noCurrentDataForLocationText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
          if (hourly.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Direction',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _CurrentDirectionStrip(hourly: hourly),
          ],
        ],
      ),
      minValueLabel: _formatValue(minKmh, unitSystem),
      nowValueLabel: _formatValue(heroSpeed, unitSystem),
      maxValueLabel: _formatValue(maxKmh, unitSystem),
      explanation:
          'Ocean current shows how fast and in which direction the water '
          'itself is moving — separate from waves and wind. A current '
          'flowing away from the shore (the opposite of the shore-facing '
          'direction) can pull even strong swimmers further out than they '
          'realize, so BeachIQ flags that above '
          '${formatWindSpeed(driftOutWarningSpeedKmh, unitSystem)}.',
    );
  }
}

/// A prominent red warning banner shown when the current is flowing away
/// from shore above [driftOutWarningSpeedKmh] — the one safety-relevant
/// condition this screen must never bury in a quiet gray status line.
class _DriftOutWarningBanner extends StatelessWidget {
  const _DriftOutWarningBanner({required this.speedLabel});

  final String speedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('drift-out-warning-banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _warning.withAlpha(0x33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Flowing away from shore at $speedLabel — stay close, this '
              'can pull swimmers out.',
              style: const TextStyle(
                color: _warning,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontally scrollable strip of per-hour current-direction arrows with
/// cardinal labels (e.g. "toward SE"), one per [hourly] entry. An entry with
/// a null [SeaHourly.currentDirection] shows a non-rotated, muted arrow and
/// "No data" rather than a fabricated bearing.
class _CurrentDirectionStrip extends StatelessWidget {
  const _CurrentDirectionStrip({required this.hourly});

  final List<SeaHourly> hourly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('current-direction-strip'),
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hourly.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final entry = hourly[index];
          final degrees = entry.currentDirection;
          return SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _hourLabel(entry.time),
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Transform.rotate(
                  angle: degrees == null ? 0 : degrees * math.pi / 180,
                  child: const Icon(
                    Icons.navigation,
                    size: 18,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  degrees == null ? 'No data' : _cardinalLabel(degrees),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _hourLabel(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
