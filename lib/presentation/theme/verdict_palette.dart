import 'package:flutter/material.dart';

import '../../logic/swim_suitability.dart';

/// The smart suggestion pill's visual treatment for one
/// [SwimSuitabilityLevel]: a two-stop background gradient, a single
/// foreground color used for both the icon and the text, and the icon
/// itself.
///
/// Every variant keeps >= 4.5:1 contrast between [foreground] and both
/// gradient stops (WCAG AA for normal text), computed with the standard
/// relative-luminance formula; see `verdict_palette_test.dart`.
class VerdictPalette {
  const VerdictPalette({
    required this.gradientStart,
    required this.gradientEnd,
    required this.foreground,
    required this.icon,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color foreground;
  final IconData icon;
}

/// Today's existing neutral grey pill (the mockup's only variant), kept as
/// the [SwimSuitabilityLevel.unknown] treatment.
const _unknownPalette = VerdictPalette(
  gradientStart: Color(0xFFD9DBDF),
  gradientEnd: Color(0xFFF2F3F5),
  foreground: Color(0xFF2E3057),
  icon: Icons.help_outline,
);

const _goodPalette = VerdictPalette(
  gradientStart: Color(0xFF1B5E20),
  gradientEnd: Color(0xFF2E7D32),
  foreground: Color(0xFFFFFFFF),
  icon: Icons.pool,
);

const _cautionPalette = VerdictPalette(
  gradientStart: Color(0xFF92400E),
  gradientEnd: Color(0xFFB45309),
  foreground: Color(0xFFFFFFFF),
  icon: Icons.warning_amber_rounded,
);

const _poorPalette = VerdictPalette(
  gradientStart: Color(0xFF7F1D1D),
  gradientEnd: Color(0xFF9A3412),
  foreground: Color(0xFFFFFFFF),
  icon: Icons.dangerous_outlined,
);

/// Pure mapping from a swim verdict level to its pill treatment. The Home
/// screen's own background gradient is a separate, unrelated constant and
/// is never touched by this mapping.
VerdictPalette paletteForVerdict(SwimSuitabilityLevel level) {
  switch (level) {
    case SwimSuitabilityLevel.good:
      return _goodPalette;
    case SwimSuitabilityLevel.caution:
      return _cautionPalette;
    case SwimSuitabilityLevel.poor:
      return _poorPalette;
    case SwimSuitabilityLevel.unknown:
      return _unknownPalette;
  }
}
