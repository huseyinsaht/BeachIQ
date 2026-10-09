import 'package:flutter/material.dart';

import '../../logic/swim_safety_disclaimer.dart';
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
///
/// Issue #271: a trailing info icon opens a bottom sheet with
/// [swimSafetyDisclaimer] -- the verdict message alone can read like a
/// safety guarantee, so the disclaimer is always one tap away from it.
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
          // A plain tappable icon, not `IconButton` (whose minimum tap
          // target enforces extra height regardless of `constraints:`),
          // so this info affordance never grows the pill taller than its
          // own leading icon -- a taller pill shifts every tile below it
          // down the Home screen (see the 3x3 stat grid's
          // tap-position-sensitive tests).
          Tooltip(
            message: swimSafetyDisclaimerTitle,
            child: GestureDetector(
              key: const Key('swim-suggestion-pill-info'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _showDisclaimerSheet(context),
              child: Icon(
                Icons.info_outline,
                size: 20,
                color: palette.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDisclaimerSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  swimSafetyDisclaimerTitle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(swimSafetyDisclaimer),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
