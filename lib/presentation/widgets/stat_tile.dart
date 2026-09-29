import 'package:flutter/material.dart';

/// Direction of a [StatTile]'s trend indicator.
enum StatTrendDirection { up, down }

/// A single stat card used in the home screen's 2x2 stat grid (wind speed,
/// rain chance, pressure, UV index): a small icon at the left, a label
/// above a bold value, and a muted trend indicator at the bottom-right.
///
/// Per docs/design.md's "Stat grid", the grid has no tile background — it
/// sits directly on the screen's gradient.
///
/// Pure presentational widget — no network, provider, or repository
/// dependency.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.trendDirection,
    required this.trendDelta,
  });

  final IconData icon;
  final String label;
  final String value;
  final StatTrendDirection trendDirection;
  final String trendDelta;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    final isUp = trendDirection == StatTrendDirection.up;
    final trendWord = isUp ? 'up' : 'down';

    return Semantics(
      label: '$label, $value, trend $trendWord $trendDelta',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: _textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 16,
                  color: _textSecondary,
                ),
                Flexible(
                  child: Text(
                    trendDelta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
