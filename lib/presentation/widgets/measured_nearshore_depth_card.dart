import 'package:flutter/material.dart';

import '../../data/models/measured_nearshore_depth.dart';
import '../../logic/unit_preferences.dart';

const Color _textPrimary = Color(0xFFFFFFFF);
const Color _textSecondary = Color(0xFF8B93A6);
const Color _measuredGreen = Color(0xFF4CAF50);
const Color _chipFill = Color(0xFF1E2230);

/// Honest limits shown with every measurement (issue #390).
const String measuredDepthCaveat =
    'Depths change with waves, the season and the water level on the day. '
    'A measurement is a guide for that day, not a safety guarantee.';

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "25 Oct 2026".
String formatMeasuredDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// A measured depth: whole centimeters under 1 m ("45 cm"), meters with two
/// decimals from 1 m ("1.20 m"); feet with one decimal for imperial.
String formatMeasuredDepth(int depthCm, UnitSystem unitSystem) {
  if (unitSystem == UnitSystem.imperial) {
    return '${metersToFeet(depthCm / 100).toStringAsFixed(1)} ft';
  }
  if (depthCm < 100) return '$depthCm cm';
  return '${(depthCm / 100).toStringAsFixed(2)} m';
}

String _formatDistance(int meters, UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial
    ? '${metersToFeet(meters.toDouble()).round()} ft'
    : '$meters m';

/// The "Measured near the shore" block of the Water depth detail screen
/// (issue #390): real on-site depths for the first ~10 m from the water's
/// edge, with a "Measured" badge, the date, who measured and how, and what
/// the distances are measured from. Shown only for beaches that have an
/// entry in `assets/measured_depths.json`; nothing here is ever estimated.
class MeasuredNearshoreDepthCard extends StatelessWidget {
  const MeasuredNearshoreDepthCard({
    super.key,
    required this.data,
    this.unitSystem = UnitSystem.metric,
  });

  final MeasuredNearshoreDepth data;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final summary = [
      for (final p in data.points)
        '${_formatDistance(p.distanceMeters, unitSystem)} from the water: '
            '${formatMeasuredDepth(p.depthCm, unitSystem)}',
    ].join('. ');

    return Semantics(
      container: true,
      label:
          'Measured depth near the shore on ${formatMeasuredDate(data.measuredOn)}. '
          '$summary. $measuredDepthCaveat',
      child: Column(
        key: const Key('measured-depth-card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Near the shore',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                key: const Key('measured-depth-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _measuredGreen.withValues(alpha: 0.18),
                  border: Border.all(color: _measuredGreen),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'MEASURED',
                  style: TextStyle(
                    color: _measuredGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Measured on ${formatMeasuredDate(data.measuredOn)} by '
            '${data.measuredBy}. ${data.method}.',
            key: const Key('measured-depth-source'),
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in data.points)
                Container(
                  key: Key('measured-depth-point-${p.distanceMeters}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _chipFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDistance(p.distanceMeters, unitSystem),
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatMeasuredDepth(p.depthCm, unitSystem),
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Distances from: ${data.reference}.',
            key: const Key('measured-depth-reference'),
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
          if (data.note != null) ...[
            const SizedBox(height: 4),
            Text(
              data.note!,
              key: const Key('measured-depth-note'),
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            measuredDepthCaveat,
            key: Key('measured-depth-caveat'),
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
