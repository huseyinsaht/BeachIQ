import 'package:flutter/material.dart';

import '../../logic/beach_surface.dart';
import '../../logic/nearshore_depth_estimate.dart';
import '../../logic/unit_preferences.dart';

const Color _textPrimary = Color(0xFFFFFFFF);
const Color _textSecondary = Color(0xFF8B93A6);
const Color _estimateAmber = Color(0xFFFFB300);

/// Honest limits shown with every estimate (issue #392).
const String nearshoreEstimateCaveat =
    'Estimated from the beach surface and the ~115 m depth data, not '
    'measured. Steps, sandbars and drop-offs are not visible in that data, '
    'so the water can be deeper than this.';

/// The estimate sentence for [estimate], in the user's units.
String nearshoreEstimateText(
  NearshoreDepthEstimate estimate,
  UnitSystem unitSystem,
) {
  switch (estimate.kind) {
    case NearshoreEstimateKind.range:
      return 'About 10 m from the water\'s edge the depth is probably '
          '${estimate.rangeText(unitSystem)}.';
    case NearshoreEstimateKind.mayBeDeep:
      return 'The water may be waist-deep or more within 10 m of the '
          'water\'s edge.';
    case NearshoreEstimateKind.steepBeachType:
      return '${beachSurfaceLabel(estimate.surface)} beaches are usually '
          'steeper than sandy ones: the bottom can drop away quickly within '
          'the first few metres. No depth estimate.';
  }
}

/// The "Beach surface: Sand (OpenStreetMap)" line shown on the Water depth
/// screen whenever the surface is known (issue #392).
class BeachSurfaceRow extends StatelessWidget {
  const BeachSurfaceRow({super.key, required this.surface});

  final BeachSurface surface;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Beach surface: ${beachSurfaceLabel(surface)} (OpenStreetMap)',
      key: const Key('beach-surface-row'),
      style: const TextStyle(color: _textSecondary, fontSize: 13),
    );
  }
}

/// The "First 10 m" estimate block of the Water depth detail screen for
/// beaches without an on-site measurement (issue #392): an amber
/// **ESTIMATE** badge, the estimate sentence and the caveat that it is not
/// measured and the water can be deeper. See [NearshoreDepthEstimate] for
/// how it is derived.
class NearshoreEstimateCard extends StatelessWidget {
  const NearshoreEstimateCard({
    super.key,
    required this.estimate,
    this.unitSystem = UnitSystem.metric,
  });

  final NearshoreDepthEstimate estimate;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final text = nearshoreEstimateText(estimate, unitSystem);
    return Semantics(
      container: true,
      label:
          'Estimate for the first 10 metres. $text '
          '$nearshoreEstimateCaveat',
      child: Column(
        key: const Key('nearshore-estimate-card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'First 10 m from the water',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                key: const Key('nearshore-estimate-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _estimateAmber.withValues(alpha: 0.16),
                  border: Border.all(color: _estimateAmber),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ESTIMATE',
                  style: TextStyle(
                    color: _estimateAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            key: const Key('nearshore-estimate-text'),
            style: const TextStyle(color: _textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            nearshoreEstimateCaveat,
            key: Key('nearshore-estimate-caveat'),
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
