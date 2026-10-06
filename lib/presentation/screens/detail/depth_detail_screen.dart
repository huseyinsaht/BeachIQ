import 'package:flutter/material.dart';

import '../../../data/models/beach.dart';
import '../../../data/models/depth_profile.dart';
import '../../../logic/shallow_entry.dart';
import '../../../logic/shallow_entry_status.dart';
import '../../../logic/unit_preferences.dart';
import '../../../logic/wave_shore_relation.dart';
import '../../widgets/depth_profile_chart.dart';
import '../../widgets/metric_detail_scaffold.dart';
// `driftOutWarningSpeedKmh` (issue #164's drift-out threshold) is defined
// on `CurrentDetailScreen`, the screen it was first added for — reused
// from there rather than duplicated, so this screen's drift-out warning
// can never drift from the Ocean Current screen's own number.
import 'current_detail_screen.dart' show driftOutWarningSpeedKmh;

const Color _textSecondary = Color(0xFF8B93A6);
const Color _warning = Color(0xFFEF5350);

/// EMODnet Bathymetry's attribution line. Follows EMODnet's terms of use
/// (https://emodnet.ec.europa.eu/en/terms-use-emodnet-online-services-data-and-data-products):
/// data products are owned by the EU and licensed CC BY 4.0, and the
/// dataset's catalog entry says not to use it for navigation.
const String depthDataAttribution =
    'Depth data: EMODnet Bathymetry (https://emodnet.ec.europa.eu/en/), '
    '© European Union, CC BY 4.0. EMODnet Digital Bathymetry (DTM 2024), '
    'completed with GEBCO 2024 and IBCAO V4 where survey data is missing. '
    '~115 m grid resolution. Approximate, not for navigation.';

String _formatDepth(double? meters, UnitSystem unitSystem) =>
    meters == null ? '--' : formatDepthMeters(meters, unitSystem);

/// Water depth / shallow-entry detail screen (issue #217): how far out a
/// beach stays "comfortably shallow" before the seabed drops away, from
/// the #216 data layer's [DepthProfile]/[classifyShallowEntry] — an
/// approximate, non-swimmer indication, never a safety guarantee.
///
/// Pushed from [HomeScreen]'s water-depth `StatTile` via
/// `buildDetailRoute(DetailMetric.depth, ...)`
/// (`lib/presentation/navigation/detail_routes.dart`).
class DepthDetailScreen extends StatelessWidget {
  const DepthDetailScreen({
    super.key,
    this.profile,
    this.beach,
    this.currentWaveHeightMeters,
    this.currentSpeedKmh,
    this.currentDirectionDegrees,
    this.seawardBearingDegrees,
    this.unitSystem = UnitSystem.metric,
  });

  /// The fetched nearshore depth profile. `null` (not yet fetched, or no
  /// [DepthProvider] at all) is treated exactly like
  /// [DepthProfile.unavailable] — "No data", never a crash or a
  /// fabricated value.
  final DepthProfile? profile;

  /// The beach this profile was fetched for, read here only for
  /// [Beach.hasLifeguard] in the context row below the chart. Null omits
  /// that row entry cleanly.
  final Beach? beach;

  /// `MarineProvider.currentData`'s current wave height (in meters),
  /// shown in the context row. Null omits that row entry.
  final double? currentWaveHeightMeters;

  /// `MarineProvider.currentData`'s current ocean current speed (in
  /// km/h), used (with [currentDirectionDegrees]/[seawardBearingDegrees])
  /// to decide whether to show the issue #164 drift-out warning.
  final double? currentSpeedKmh;

  /// `MarineProvider.currentData`'s current ocean current direction
  /// (`SeaCondition.currentDirection`'s "flowing toward" convention).
  final double? currentDirectionDegrees;

  /// The selected beach's shore-normal bearing (see
  /// `wave_shore_relation.dart`), null when no beach geometry is
  /// available — in that case the drift-out warning is never shown
  /// (never an invented shore relation).
  final double? seawardBearingDegrees;

  /// The user's display-unit preference (m or ft). Defaults to metric,
  /// matching every other detail screen's default.
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final effectiveProfile = profile ?? const DepthProfile.unavailable();
    final classification = classifyShallowEntry(effectiveProfile);
    final validSamples = effectiveProfile.validSamples;

    final minDepth = validSamples.isEmpty
        ? null
        : validSamples
              .map((sample) => sample.depthMeters!)
              .reduce((a, b) => a < b ? a : b);
    final maxDepth = validSamples.isEmpty
        ? null
        : validSamples
              .map((sample) => sample.depthMeters!)
              .reduce((a, b) => a > b ? a : b);
    double? referenceDepth;
    for (final sample in effectiveProfile.samples) {
      if (sample.distanceMeters == classificationReferenceDistanceMeters) {
        referenceDepth = sample.depthMeters;
        break;
      }
    }

    final seaward = seawardBearingDegrees;
    final direction = currentDirectionDegrees;
    final relation = (seaward == null || direction == null)
        ? null
        : classifyDirection(
            degrees: direction,
            convention: DirectionConvention.flowingToward,
            seawardBearingDegrees: seaward,
          );
    final speed = currentSpeedKmh;
    final showDriftWarning =
        relation == ShoreRelation.awayFromShore &&
        speed != null &&
        speed >= driftOutWarningSpeedKmh;

    return MetricDetailScaffold(
      title: 'Water depth',
      heroValue: formatShallowEntrySummary(classification, unitSystem),
      statusLabel: shallowEntryStatusLabel(classification.steepness),
      statusColor: shallowEntryStatusColor(classification.steepness),
      chart: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DepthProfileChart(
            samples: effectiveProfile.samples,
            unitSystem: unitSystem,
          ),
          const SizedBox(height: 20),
          _ContextRow(
            hasLifeguard: beach?.hasLifeguard,
            currentWaveHeightMeters: currentWaveHeightMeters,
            unitSystem: unitSystem,
            showDriftWarning: showDriftWarning,
            driftSpeedLabel: speed == null
                ? null
                : formatWindSpeed(speed, unitSystem),
          ),
        ],
      ),
      // MetricDetailScaffold's summary row is fixed to "Min"/"Now"/"Max"
      // labels, built for an hourly time series — this screen has no time
      // dimension, so these are repurposed for the spatial profile
      // instead: the shallowest/deepest valid reading along the transect,
      // and ("Now") the reading at classificationReferenceDistanceMeters
      // (100 m), the exact point classifyShallowEntry itself reads to
      // decide gentle/moderate/steep.
      minValueLabel: _formatDepth(minDepth, unitSystem),
      nowValueLabel: _formatDepth(referenceDepth, unitSystem),
      maxValueLabel: _formatDepth(maxDepth, unitSystem),
      explanation:
          'This shows roughly how far out from shore the water stays '
          'shallow before it gets deeper, based on a coarse (~115 m grid) '
          'bathymetry dataset — an approximate, non-swimmer indication, '
          'never a safety guarantee. A sandbar, drop-off or rip channel can '
          'exist well inside a single grid cell. Waves, currents and '
          'whether a lifeguard is on duty matter just as much, so always '
          'check real conditions before entering the water.\n\n'
          '$depthDataAttribution',
    );
  }
}

/// A short list of info-only context facts below the chart (issue #217):
/// lifeguard presence, the current wave height, and (only when it
/// applies) the issue #164 drift-out warning. No combined score — each
/// row is independent, and any item with no data simply isn't rendered
/// (never a placeholder row), so the whole section renders nothing when
/// none apply.
class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.hasLifeguard,
    required this.currentWaveHeightMeters,
    required this.unitSystem,
    required this.showDriftWarning,
    required this.driftSpeedLabel,
  });

  final bool? hasLifeguard;
  final double? currentWaveHeightMeters;
  final UnitSystem unitSystem;
  final bool showDriftWarning;
  final String? driftSpeedLabel;

  @override
  Widget build(BuildContext context) {
    final waveHeight = currentWaveHeightMeters;
    final lifeguard = hasLifeguard;
    final items = <Widget>[
      if (lifeguard != null)
        _ContextItem(
          key: const Key('depth-context-lifeguard'),
          icon: Icons.shield_outlined,
          text: lifeguard ? 'Lifeguard on duty nearby' : 'No lifeguard nearby',
        ),
      if (waveHeight != null)
        _ContextItem(
          key: const Key('depth-context-wave-height'),
          icon: Icons.waves,
          text:
              'Current wave height: ${formatWaveHeight(waveHeight, unitSystem)}',
        ),
      if (showDriftWarning && driftSpeedLabel != null)
        _ContextItem(
          key: const Key('depth-context-drift-warning'),
          icon: Icons.warning_amber_rounded,
          text:
              'Current flowing away from shore at $driftSpeedLabel — stay '
              'close, this can pull swimmers out.',
          color: _warning,
          bold: true,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('depth-context-row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          items[i],
          if (i < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ContextItem extends StatelessWidget {
  const _ContextItem({
    super.key,
    required this.icon,
    required this.text,
    this.color = _textSecondary,
    this.bold = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
