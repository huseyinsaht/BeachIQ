import 'package:flutter/material.dart';

import 'stat_tile.dart';

/// One labelled row of the Home screen's 3x3 stat grid (issue #251): a
/// small uppercase `text.secondary` heading (icon + label, matching the
/// "Sea"/"Hourly forecast" section labels elsewhere on Home) over exactly
/// three equal-width [StatTile]s side by side.
///
/// Each tile gets an equal share of the available width (`Expanded`), which
/// is all a tile's own `FittedBox` needs to shrink a long value rather than
/// overflow; a tile's height is left to grow with its own content (e.g. a
/// wrapped status line), so the row's height is simply the tallest of its
/// three tiles rather than a fixed, artificially-matched one.
///
/// Pure presentational widget — no network, provider, or repository
/// dependency.
class StatTileGroup extends StatelessWidget {
  const StatTileGroup({
    super.key,
    required this.label,
    required this.icon,
    required this.tiles,
  });

  /// The group's small uppercase heading, e.g. "Sea", "Current", "Air".
  final String label;

  /// The heading's small leading icon.
  final IconData icon;

  /// Exactly three tiles, rendered left to right in this order.
  final List<StatTile> tiles;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    assert(
      tiles.length == 3,
      'Each Home stat group is exactly three tiles (issue #251\'s 3x3 '
      'grid) — a group with more or fewer would break the "all nine tiles '
      'are one size, 3 columns x 3 rows" layout.',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: _textSecondary),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 12),
            Expanded(child: tiles[1]),
            const SizedBox(width: 12),
            Expanded(child: tiles[2]),
          ],
        ),
      ],
    );
  }
}
