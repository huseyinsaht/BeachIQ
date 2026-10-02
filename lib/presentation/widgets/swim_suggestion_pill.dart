import 'package:flutter/material.dart';

import '../../logic/swim_suitability.dart';
import '../theme/verdict_palette.dart';

/// The home screen's "smart suggestion pill", per docs/design.md §
/// "Screen: Home / location detail": a single full-width rounded pill with
/// a leading icon and one short line of text. Muted, not a primary CTA.
///
/// The pill's background gradient, foreground color and icon follow the
/// swim verdict's level via [paletteForVerdict] (good = green, caution =
/// orange, poor = red-orange, unknown = the mockup's neutral grey). The
/// Home screen's own navy background gradient is unrelated and never
/// changes. A color change (the verdict improving/worsening on refresh)
/// animates rather than snapping.
///
/// Pure presentational widget — no network or provider dependency; the
/// caller supplies the already-computed [SwimVerdict] (see
/// [scoreSwimSuitability]).
class SwimSuggestionPill extends StatelessWidget {
  const SwimSuggestionPill({super.key, required this.verdict});

  final SwimVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final palette = paletteForVerdict(verdict.level);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [palette.gradientStart, palette.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Icon(palette.icon, size: 20, color: palette.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              verdict.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.foreground, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
