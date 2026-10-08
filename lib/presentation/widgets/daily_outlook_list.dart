import 'package:flutter/material.dart';

import '../../logic/daily_outlook.dart';
import '../theme/verdict_palette.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// A short weekday label for [date]: "Today" when [date] is the same
/// calendar day as [now], otherwise the three-letter weekday name.
/// Comparing against [now] rather than "is this the first entry" means a
/// stale first entry (e.g. cached data checked after midnight, with no
/// fresh fetch yet) never mislabels a past day as "Today".
String dayLabelFor(DateTime date, {required DateTime now}) {
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Today';
  }
  return _weekdayLabels[date.weekday - 1];
}

/// Home screen's "7-14 day outlook" section (issue #273): one row per
/// forecast day with its weekday label, a swim-verdict icon/color (the
/// same [paletteForVerdict] mapping the smart suggestion pill uses — good
/// = green, caution = orange, poor = red-orange, unknown = neutral grey)
/// and its high/low temperature, already formatted by the caller so this
/// widget stays unit-agnostic (matching [DailyOutlookEntry] itself, which
/// carries raw values).
///
/// A plain vertical [Column], not its own scroll view — the Home screen's
/// body is already one [SingleChildScrollView], and nesting an unbounded
/// scrollable inside it would break layout.
///
/// Pure presentational widget — no network, provider or repository
/// dependency; the caller supplies the already-combined [entries] (see
/// `buildDailyOutlook`).
class DailyOutlookList extends StatelessWidget {
  const DailyOutlookList({
    super.key,
    required this.entries,
    required this.formatTemperature,
    this.now,
  });

  final List<DailyOutlookEntry> entries;

  /// Formats a nullable raw temperature into display text (e.g. "28°C"
  /// or "--°" when null), matching the unit system the rest of the Home
  /// screen's header/hourly row use.
  final String Function(double? value) formatTemperature;

  /// "Current time" for deciding which row (if any) reads "Today" — see
  /// [dayLabelFor]. Defaults to the real clock; the Home screen passes its
  /// own `effectiveNow` so widget tests can pin it, matching
  /// `HourlyForecastItem.time`'s same reasoning.
  final DateTime? now;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    final effectiveNow = now ?? DateTime.now();
    return Column(
      key: const Key('daily-outlook-list'),
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Divider(height: 1, color: _textSecondary.withValues(alpha: 0.15)),
          _DailyOutlookRow(
            entry: entries[i],
            dayLabel: dayLabelFor(entries[i].date, now: effectiveNow),
            formatTemperature: formatTemperature,
          ),
        ],
      ],
    );
  }
}

class _DailyOutlookRow extends StatelessWidget {
  const _DailyOutlookRow({
    required this.entry,
    required this.dayLabel,
    required this.formatTemperature,
  });

  final DailyOutlookEntry entry;
  final String dayLabel;
  final String Function(double? value) formatTemperature;

  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    final palette = paletteForVerdict(entry.verdict.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              dayLabel,
              style: const TextStyle(color: _textPrimary, fontSize: 14),
            ),
          ),
          Icon(palette.icon, size: 18, color: palette.gradientEnd),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.verdict.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatTemperature(entry.highTemperature),
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatTemperature(entry.lowTemperature),
            style: const TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
