import 'package:flutter/material.dart';

import '../../data/models/beach_amenity.dart';
import 'amenity_marker.dart';

/// A fixed, stable display order for the legend/toggle row, independent of
/// whatever order amenities happen to arrive from Overpass.
const List<AmenityKind> _amenityKindOrder = [
  AmenityKind.toilets,
  AmenityKind.shower,
  AmenityKind.changingRoom,
  AmenityKind.parking,
  AmenityKind.cafe,
  AmenityKind.beachResort,
  AmenityKind.lifeguard,
];

/// A horizontally scrollable row of toggle chips, one per amenity kind
/// actually present in [presentKinds] (never a chip for a kind with no
/// amenities nearby). Each chip shows [amenityIcon]/[amenityColor] and
/// [amenityLabel]; tapping one calls [onToggle] with that kind, and a kind
/// in [hiddenKinds] renders dimmed/outlined to show it is currently hidden.
class AmenityLegend extends StatelessWidget {
  const AmenityLegend({
    super.key,
    required this.presentKinds,
    required this.hiddenKinds,
    required this.onToggle,
  });

  final Set<AmenityKind> presentKinds;
  final Set<AmenityKind> hiddenKinds;
  final ValueChanged<AmenityKind> onToggle;

  @override
  Widget build(BuildContext context) {
    final orderedKinds = [
      for (final kind in _amenityKindOrder)
        if (presentKinds.contains(kind)) kind,
    ];
    if (orderedKinds.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final kind in orderedKinds)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _LegendChip(
                kind: kind,
                hidden: hiddenKinds.contains(kind),
                onTap: () => onToggle(kind),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.kind,
    required this.hidden,
    required this.onTap,
  });

  final AmenityKind kind;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = amenityColor(kind);
    return Semantics(
      label: '${amenityLabel(kind)}, ${hidden ? 'hidden' : 'shown'}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hidden ? Colors.white.withValues(alpha: 0.85) : color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                amenityIcon(kind),
                size: 14,
                color: hidden ? color : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                amenityLabel(kind),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: hidden ? color : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
