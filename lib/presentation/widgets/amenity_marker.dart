import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../data/models/beach_amenity.dart';

/// One color per [AmenityKind], per the owner's Google-Maps-style palette
/// (issue #172's 2026-10-01 update): food & drink orange, toilets/showers/
/// changing rooms blue, parking blue-grey, beach club/umbrella teal,
/// lifeguard red.
Color amenityColor(AmenityKind kind) {
  switch (kind) {
    case AmenityKind.cafe:
      return const Color(0xFFF57C00);
    case AmenityKind.toilets:
    case AmenityKind.shower:
    case AmenityKind.changingRoom:
      return const Color(0xFF1A73E8);
    case AmenityKind.parking:
      return const Color(0xFF5F6368);
    case AmenityKind.beachResort:
      return const Color(0xFF00897B);
    case AmenityKind.lifeguard:
      return const Color(0xFFD93025);
  }
}

/// The Material glyph shown inside the marker/legend chip for [kind], per
/// the owner's palette update.
IconData amenityIcon(AmenityKind kind) {
  switch (kind) {
    case AmenityKind.cafe:
      return Icons.local_cafe;
    case AmenityKind.toilets:
      return Icons.wc;
    case AmenityKind.shower:
      return Icons.shower;
    case AmenityKind.changingRoom:
      return Icons.checkroom;
    case AmenityKind.parking:
      return Icons.local_parking;
    case AmenityKind.beachResort:
      return Icons.beach_access;
    case AmenityKind.lifeguard:
      return Icons.health_and_safety;
  }
}

/// A human-readable label for [kind], used by the legend and the marker's
/// own semantics/tooltip.
String amenityLabel(AmenityKind kind) {
  switch (kind) {
    case AmenityKind.cafe:
      return 'Cafe';
    case AmenityKind.toilets:
      return 'Toilets';
    case AmenityKind.shower:
      return 'Shower';
    case AmenityKind.changingRoom:
      return 'Changing room';
    case AmenityKind.parking:
      return 'Parking';
    case AmenityKind.beachResort:
      return 'Beach club';
    case AmenityKind.lifeguard:
      return 'Lifeguard';
  }
}

/// Width/height of the box an [AmenityMarker] needs when [AmenityMarker.
/// showLabel] is true, so callers (the map's `Marker`) can size and anchor
/// it correctly — see [AmenityMarker.pointAlignment].
const double amenityMarkerLabeledWidth = 64;
const double amenityMarkerLabeledHeight = 48;

/// A single amenity pin on the map: a filled colored circle (per
/// [amenityColor]) with a white glyph (per [amenityIcon]) and a soft drop
/// shadow, matching the Google-Maps-style visual language the owner asked
/// for (issue #172) without copying any Google asset or logo.
///
/// Grows slightly and gains a stronger shadow when [selected]; parking
/// shows a "P" badge instead of its icon, per the owner's note. When
/// [showLabel] is true (the owner's "a short label under the pin at high
/// zoom" note), a small name-or-kind label is drawn below the circle — the
/// circle itself stays the real geographic anchor (see [pointAlignment]),
/// not the label or the taller box around both.
class AmenityMarker extends StatelessWidget {
  const AmenityMarker({
    super.key,
    required this.kind,
    this.name,
    this.selected = false,
    this.showLabel = false,
    this.onTap,
  });

  final AmenityKind kind;
  final String? name;
  final bool selected;
  final bool showLabel;
  final VoidCallback? onTap;

  static const double _baseSize = 28;
  static const double _selectedSize = 36;

  /// The `Marker.alignment` a caller must pass alongside
  /// [amenityMarkerLabeledWidth]/[amenityMarkerLabeledHeight] so the
  /// circle's center — not the taller label box's center — sits on the
  /// real geographic point.
  static final Alignment pointAlignment = Marker.computePixelAlignment(
    width: amenityMarkerLabeledWidth,
    height: amenityMarkerLabeledHeight,
    left: amenityMarkerLabeledWidth / 2,
    top: _baseSize / 2,
  );

  @override
  Widget build(BuildContext context) {
    final size = selected ? _selectedSize : _baseSize;
    final effectiveLabel = name ?? amenityLabel(kind);
    return Semantics(
      label: name == null ? amenityLabel(kind) : '${amenityLabel(kind)}, $name',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: amenityColor(kind),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: selected ? 0.45 : 0.3,
                    ),
                    blurRadius: selected ? 6 : 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: kind == AmenityKind.parking
                    ? const Text(
                        'P',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : Icon(amenityIcon(kind), color: Colors.white, size: 16),
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 2),
              Text(
                effectiveLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 3),
                    Shadow(color: Colors.black87, blurRadius: 3),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
