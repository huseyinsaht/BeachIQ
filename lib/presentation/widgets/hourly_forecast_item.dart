import 'package:flutter/material.dart';

/// A single entry (time label, weather icon, bold temperature) for the home
/// screen's horizontally scrollable hourly forecast row.
///
/// Pure presentational widget — no network, provider, or repository
/// dependency.
class HourlyForecastItem extends StatelessWidget {
  const HourlyForecastItem({
    super.key,
    required this.timeLabel,
    required this.icon,
    required this.temperature,
  });

  /// e.g. "Now", "3PM".
  final String timeLabel;
  final IconData icon;
  final String temperature;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeLabel,
          style: const TextStyle(color: _textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Icon(icon, size: 24, color: Colors.white),
        const SizedBox(height: 8),
        Text(
          temperature,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
