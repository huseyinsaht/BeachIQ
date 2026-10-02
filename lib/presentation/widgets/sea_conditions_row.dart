import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/sea_condition.dart';
import '../../logic/unit_preferences.dart';

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
class SeaConditionsRow extends StatelessWidget {
  const SeaConditionsRow({
    super.key,
    required this.data,
    required this.unitSystem,
  });

  final SeaCondition? data;
  final UnitSystem unitSystem;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    final condition = data;
    if (condition == null) return const SizedBox.shrink();

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
          height: 78,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _SeaStatTile(
                icon: Icons.waves,
                label: 'Wave height',
                value: _formatWaveHeight(condition.waveHeight, unitSystem),
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
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: SizedBox(
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
class _SeaDirectionStatTile extends StatelessWidget {
  const _SeaDirectionStatTile({
    super.key,
    required this.label,
    required this.arrowRotationDegrees,
    required this.value,
  });

  final String label;
  final double? arrowRotationDegrees;
  final String value;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    final degrees = arrowRotationDegrees;
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: SizedBox(
        width: 120,
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
          ],
        ),
      ),
    );
  }
}
