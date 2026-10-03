import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/sea_condition.dart';
import '../../logic/unit_preferences.dart';
import '../../logic/wave_shore_relation.dart';
import '../navigation/detail_routes.dart';

/// Shown for any null field in [SeaConditionsRow]'s tiles, matching
/// `home_screen.dart`'s `_noData` constant: "no data for this hour/point",
/// never a fabricated `0`.
const String _noSeaData = 'No data';

/// Maps a compass bearing (degrees clockwise from true north, any range —
/// callers may pass values outside 0-360, e.g. close to a wrap-around like
/// 350 -> 360) to its nearest 8-point cardinal label.
///
/// Boundaries sit at the midpoints between points (22.5° wide either side
/// of N/NE/E/.../NW), so e.g. 350° (within 10° of north) resolves to "N".
String _cardinalLabel(double degrees) {
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final normalized = ((degrees % 360) + 360) % 360;
  final index = ((normalized + 22.5) / 45).floor() % 8;
  return points[index];
}

/// Formats [waveDirectionDegrees] per [SeaCondition.waveDirection]'s
/// meteorological "coming from" convention, e.g. `"from NW"`.
String _waveDirectionLabel(double? waveDirectionDegrees) {
  if (waveDirectionDegrees == null) return _noSeaData;
  return 'from ${_cardinalLabel(waveDirectionDegrees)}';
}

/// Formats [currentDirectionDegrees] per [SeaCondition.currentDirection]'s
/// oceanographic "flowing toward" convention, e.g. `"toward SE"`.
String _currentDirectionLabel(double? currentDirectionDegrees) {
  if (currentDirectionDegrees == null) return _noSeaData;
  return 'toward ${_cardinalLabel(currentDirectionDegrees)}';
}

String _formatWaveHeight(double? meters, UnitSystem unitSystem) {
  if (meters == null) return _noSeaData;
  return formatWaveHeight(meters, unitSystem);
}

String _formatWaterTemperature(double? celsius, UnitSystem unitSystem) {
  if (celsius == null) return _noSeaData;
  return formatTemperature(celsius, unitSystem);
}

String _formatCurrentSpeed(double? kmh, UnitSystem unitSystem) {
  if (kmh == null) return _noSeaData;
  return formatWindSpeed(kmh, unitSystem);
}

/// The short suffix shown under a direction tile's value once a
/// [ShoreRelation] is known (i.e. [SeaConditionsRow.seawardBearingDegrees]
/// was supplied). [ShoreRelation.awayFromShore] gets a stronger warning
/// ("stay close!") since it signals drift-out / rip-current risk.
String _shoreRelationLabel(ShoreRelation relation) {
  switch (relation) {
    case ShoreRelation.towardShore:
      return '(towards shore)';
    case ShoreRelation.awayFromShore:
      return '(away from shore — stay close!)';
    case ShoreRelation.alongShore:
      return '(along shore)';
  }
}

/// A section under the Home screen's smart suggestion pill showing the
/// current [SeaCondition] (`MarineProvider.currentData`): wave height,
/// water temperature, wave direction, current speed and current direction.
///
/// Not in docs/assets/mockup-home.png (the mockup has no wave/current
/// fields at all) — this deliberately extends it, matching
/// docs/design.md's "Stat grid" styling (icon + label + value, no tile
/// background) so it reads as a natural continuation of that grid rather
/// than a visually distinct widget. Unlike `StatTile`, these tiles have no
/// trend indicator: none of these five values have a meaningful "delta
/// since last hour" the rest of the app already surfaces.
///
/// Renders nothing when [data] is null (no `SeaCondition` fetched yet),
/// matching the existing "no data" treatment driven by
/// `MarineProvider.isLoading`/`.error` at the screen level: this widget is
/// only ever built once `MarineProvider.currentData` is non-null. Any
/// individual null field inside a present [data] shows "No data" (never a
/// fabricated `0`).
///
/// Pure presentational widget — no network, provider, or repository
/// dependency.
///
/// [seawardBearingDegrees] is the selected beach's shore-normal bearing
/// (degrees clockwise from true north, pointing from the beach straight out
/// to open water) when it can be derived from the beach's OSM geometry; see
/// `wave_shore_relation.dart`. It is null whenever no beach geometry is
/// available for the current location — in that case the direction tiles
/// show today's cardinal-only labels and NEVER an invented shore relation.
/// When non-null, the current-direction tile (primary) and the
/// wave-direction tile (secondary) each append a `ShoreRelation` label,
/// with [ShoreRelation.awayFromShore] visually flagged since it signals
/// drift-out / rip-current risk.
class SeaConditionsRow extends StatelessWidget {
  const SeaConditionsRow({
    super.key,
    required this.data,
    required this.unitSystem,
    this.seawardBearingDegrees,
  });

  final SeaCondition? data;
  final UnitSystem unitSystem;
  final double? seawardBearingDegrees;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    final condition = data;
    if (condition == null) return const SizedBox.shrink();

    final seaward = seawardBearingDegrees;
    final waveShoreRelation = seaward == null || condition.waveDirection == null
        ? null
        : classifyDirection(
            degrees: condition.waveDirection!,
            convention: DirectionConvention.comingFrom,
            seawardBearingDegrees: seaward,
          );
    final currentShoreRelation =
        seaward == null || condition.currentDirection == null
        ? null
        : classifyDirection(
            degrees: condition.currentDirection!,
            convention: DirectionConvention.flowingToward,
            seawardBearingDegrees: seaward,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.waves, size: 14, color: _textSecondary),
            SizedBox(width: 6),
            Text('Sea', style: TextStyle(color: _textSecondary, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          // Taller once a shore-relation line can appear under a direction
          // tile's value (only when seawardBearingDegrees is known). The
          // longest label ("away from shore — stay close!") wraps onto a
          // second line at the tile's width (see _SeaDirectionStatTile's
          // widened tile below), so this allows for two lines, not one.
          height: seaward == null ? 78 : 124,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _SeaStatTile(
                key: const Key('wave-height-tile'),
                icon: Icons.waves,
                label: 'Wave height',
                value: _formatWaveHeight(condition.waveHeight, unitSystem),
                // Opens the wave height detail screen (issue #167): its own
                // page/route, with the day's marine hourly series for the
                // chart and the current reading as the hero value.
                onTap: () => Navigator.of(context).push(
                  buildDetailRoute(
                    DetailMetric.waveHeight,
                    hourly: const [],
                    seaHourly: condition.hourly,
                    currentValue: condition.waveHeight,
                    unitSystem: unitSystem,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              _SeaStatTile(
                icon: Icons.thermostat,
                label: 'Water temp',
                value: _formatWaterTemperature(
                  condition.seaSurfaceTemperature,
                  unitSystem,
                ),
              ),
              const SizedBox(width: 20),
              _SeaDirectionStatTile(
                key: const Key('wave-direction-tile'),
                label: 'Wave direction',
                // The wave direction bearing is where the wave comes FROM,
                // so the arrow is drawn pointing the opposite way — where
                // the wave is actually heading — rather than at the raw
                // bearing itself (see _waveDirectionLabel/
                // SeaCondition.waveDirection's doc comment).
                arrowRotationDegrees: condition.waveDirection == null
                    ? null
                    : condition.waveDirection! + 180,
                value: _waveDirectionLabel(condition.waveDirection),
                shoreRelation: waveShoreRelation,
              ),
              const SizedBox(width: 20),
              _SeaStatTile(
                icon: Icons.speed,
                label: 'Current speed',
                value: _formatCurrentSpeed(
                  condition.currentVelocity,
                  unitSystem,
                ),
              ),
              const SizedBox(width: 20),
              _SeaDirectionStatTile(
                key: const Key('current-direction-tile'),
                label: 'Current direction',
                // The current direction bearing already is where the
                // current is flowing TOWARD, so the arrow is drawn
                // pointing straight at that raw bearing (see
                // _currentDirectionLabel/SeaCondition.currentDirection's
                // doc comment) — the opposite of the wave tile above.
                arrowRotationDegrees: condition.currentDirection,
                value: _currentDirectionLabel(condition.currentDirection),
                shoreRelation: currentShoreRelation,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single tile in [SeaConditionsRow]'s scrollable row: a small leading
/// icon, a `text.secondary` label, and a bold white value — the same visual
/// language as `StatTile`, minus its trend row (see [SeaConditionsRow]'s
/// doc comment for why).
class _SeaStatTile extends StatelessWidget {
  const _SeaStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Opens this metric's own detail screen (issue #167's wave height tile
  /// is the first to use it) when set. Null (the default) keeps every
  /// other tile's existing behavior exactly: no `InkWell`/ripple, no tap
  /// target at all — matching `StatTile`'s own `onTap` convention.
  final VoidCallback? onTap;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _textSecondary),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: onTap == null
          ? content
          : InkWell(
              key: const Key('sea-stat-tile-tap-target'),
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

/// A direction variant of [_SeaStatTile]: a rotated arrow icon (pointing
/// [arrowRotationDegrees] clockwise from "up", matching the compass-bearing
/// convention documented on `SeaCondition`) in place of the plain icon, and
/// a cardinal-direction value such as "from NW"/"toward SE" (already built
/// by the caller as [value]) in place of a bare value.
///
/// Shows a non-rotated, muted arrow and "No data" when
/// [arrowRotationDegrees] is null, instead of defaulting to a fabricated
/// bearing of 0.
///
/// [shoreRelation] is only non-null once a beach's seaward bearing is known
/// (see [SeaConditionsRow.seawardBearingDegrees]); when present, its label
/// (" (towards shore)" / " (away from shore — stay close!)" /
/// " (along shore)") renders as a small line under the value, with
/// [ShoreRelation.awayFromShore] shown in a warning color since it signals
/// drift-out / rip-current risk. Null shows nothing extra — never an
/// invented relation.
class _SeaDirectionStatTile extends StatelessWidget {
  const _SeaDirectionStatTile({
    super.key,
    required this.label,
    required this.arrowRotationDegrees,
    required this.value,
    this.shoreRelation,
  });

  final String label;
  final double? arrowRotationDegrees;
  final String value;
  final ShoreRelation? shoreRelation;

  static const _textSecondary = Color(0xFF8B93A6);
  static const _warning = Color(0xFFEF5350);

  @override
  Widget build(BuildContext context) {
    final degrees = arrowRotationDegrees;
    final relation = shoreRelation;
    final relationLabel = relation == null
        ? null
        : _shoreRelationLabel(relation);
    return Semantics(
      label: relationLabel == null
          ? '$label, $value'
          : '$label, $value $relationLabel',
      excludeSemantics: true,
      child: SizedBox(
        // Wider than the other tiles' 120px: the shore-relation label (e.g.
        // "(away from shore — stay close!)") needs the extra room to wrap
        // onto two lines instead of being clipped (see relationLabel below)
        // — clipping the one safety-relevant warning this row shows is
        // worse than a slightly wider tile.
        width: relationLabel == null ? 120 : 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: degrees == null ? 0 : degrees * math.pi / 180,
              child: const Icon(
                Icons.navigation,
                size: 18,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (relationLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                relationLabel,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: relation == ShoreRelation.awayFromShore
                      ? _warning
                      : _textSecondary,
                  fontSize: 11,
                  fontWeight: relation == ShoreRelation.awayFromShore
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
