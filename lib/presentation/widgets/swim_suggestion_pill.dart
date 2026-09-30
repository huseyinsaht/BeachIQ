import 'package:flutter/material.dart';

import '../../logic/swim_suitability.dart';

/// The home screen's "smart suggestion pill", per docs/design.md §
/// "Screen: Home / location detail": a single full-width rounded pill with
/// the light grey gradient (`surface.pill`), a leading icon and one short
/// line of `text.onPaper`-style text. Muted, not a primary CTA.
///
/// Pure presentational widget — no network or provider dependency; the
/// caller supplies the already-computed [SwimVerdict] (see
/// [scoreSwimSuitability]).
class SwimSuggestionPill extends StatelessWidget {
  const SwimSuggestionPill({super.key, required this.verdict});

  final SwimVerdict verdict;

  static const _pillGradientStart = Color(0xFFD9DBDF);
  static const _pillGradientEnd = Color(0xFFF2F3F5);
  static const _textOnPaper = Color(0xFF2E3057);

  IconData get _icon {
    switch (verdict.level) {
      case SwimSuitabilityLevel.good:
        return Icons.pool;
      case SwimSuitabilityLevel.caution:
        return Icons.warning_amber_rounded;
      case SwimSuitabilityLevel.poor:
        return Icons.dangerous_outlined;
      case SwimSuitabilityLevel.unknown:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_pillGradientStart, _pillGradientEnd],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 20, color: _textOnPaper),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              verdict.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textOnPaper, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
