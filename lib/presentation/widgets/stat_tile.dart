import 'package:flutter/material.dart';

/// Direction of a [StatTile]'s trend indicator.
enum StatTrendDirection { up, down }

/// A single stat card used in the home screen's 2x2 stat grid (wind speed,
/// rain chance, pressure, UV index): a small icon, a label, a bold value,
/// and a muted trend indicator.
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
  static const _cardBackground = Color(0x14FFFFFF);

  @override
  Widget build(BuildContext context) {
    final isUp = trendDirection == StatTrendDirection.up;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _textSecondary),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 16,
                  color: _textSecondary,
                  semanticLabel: isUp ? 'up' : 'down',
                ),
                Text(
                  trendDelta,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
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
