import 'package:flutter/material.dart';

import '../../logic/forecast_alerts.dart';

/// Icon color for a [ForecastAlertSeverity], per docs/design.md "Home:
/// alert list": amber for a [ForecastAlertSeverity.moderate] heads-up,
/// `color.warning` (#EF5350 — the same red already used for the Sea
/// section's away-from-shore warning) for [ForecastAlertSeverity.high],
/// since both signal "this one needs real attention, not just a
/// heads-up".
const _moderateColor = Color(0xFFFFB74D);
const _highColor = Color(0xFFEF5350);
const _textSecondary = Color(0xFF8B93A6);

Color _colorForSeverity(ForecastAlertSeverity severity) {
  switch (severity) {
    case ForecastAlertSeverity.moderate:
      return _moderateColor;
    case ForecastAlertSeverity.high:
      return _highColor;
  }
}

/// A small type-specific glyph so the row reads at a glance (wind vs.
/// waves vs. an incoming current), with [_colorForSeverity] carrying the
/// urgency instead of the glyph itself changing shape.
IconData _iconForType(ForecastAlertType type) {
  switch (type) {
    case ForecastAlertType.wind:
      return Icons.air;
    case ForecastAlertType.waves:
      return Icons.waves;
    case ForecastAlertType.clouds:
      return Icons.cloud;
    case ForecastAlertType.rain:
      return Icons.water_drop_outlined;
    case ForecastAlertType.current:
      return Icons.speed;
  }
}

String _formatHour(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

const _weekdayAbbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Issue #229: a short prefix ("Tomorrow", "Wed", ...) for an alert whose
/// [time] is not the same calendar day as [now], so two alerts that land on
/// the same hour on different days (e.g. two "09:00 - 10:00" windows) never
/// read as identical. Null when [time] is today — the existing bare
/// "09:00 - 10:00" label already reads correctly for that case.
String? _dayLabelFor(DateTime time, DateTime now) {
  if (_isSameDay(time, now)) return null;
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(time.year, time.month, time.day);
  if (target.difference(today).inDays == 1) return 'Tomorrow';
  return _weekdayAbbreviations[time.weekday - 1];
}

/// A compact "09:00 - 10:00" label, distinct from [ForecastAlert.message]
/// (which already spells the same window out as a sentence, e.g. "Wind
/// picks up between 09:00 and 10:00.") — this is the scannable summary the
/// issue's "icon + one line + time window" layout asks for underneath that
/// sentence. Prefixed with a day label (see [_dayLabelFor]) when [alert]
/// does not fall on [now]'s calendar day. [now] is only used for that day
/// label: when the caller doesn't supply it (no real-world caller omits
/// it, but a test might not care about day labels), the bare window is
/// shown with no label rather than falling back to the real system clock.
String _timeWindowLabel(ForecastAlert alert, DateTime? now) {
  final window = '${_formatHour(alert.start)} - ${_formatHour(alert.end)}';
  if (now == null) return window;
  final dayLabel = _dayLabelFor(alert.start, now);
  return dayLabel == null ? window : '$dayLabel · $window';
}

/// Sorts [alerts] most severe first ([ForecastAlertSeverity.high] before
/// [ForecastAlertSeverity.moderate]), keeping `buildForecastAlerts`' own
/// ascending-start-time order as the tie-break within a severity tier
/// (`List.sort` is not guaranteed stable in Dart, so the tie-break is
/// spelled out explicitly rather than relied on implicitly). Does not
/// mutate [alerts].
List<ForecastAlert> sortAlertsBySeverity(List<ForecastAlert> alerts) {
  final sorted = List<ForecastAlert>.of(alerts);
  sorted.sort((a, b) {
    final bySeverity = b.severity.index.compareTo(a.severity.index);
    if (bySeverity != 0) return bySeverity;
    return a.start.compareTo(b.start);
  });
  return sorted;
}

/// The upcoming-forecast-alerts list (issue #169, extended by #229), per
/// docs/design.md "Home: alert list"/"Forecast screen". Issue #289 moved
/// the full list off Home onto the dedicated Forecast screen — `HomeScreen`
/// now only ever feeds this widget an empty [alerts] plus its single
/// [nextHourNote], while `ForecastScreen` feeds it the full, severity-sorted
/// list and no note — but the widget itself still supports both shapes
/// rather than forking into two near-duplicates. [nextHourNote] (issue
/// #229), when non-null, renders first as a visually distinct "Next hour"
/// row — it is based on the current time rather than daylight, so it can
/// still show after sunset while [alerts] (already daylight-filtered by the
/// caller) is empty. Below it, one row per [ForecastAlert] in [alerts] — a
/// type icon (colored by [ForecastAlert.severity] via [_colorForSeverity]),
/// the alert's message, and a compact time-window label underneath,
/// prefixed with a day label when the alert is not on [now]'s calendar day
/// — sorted most severe first via [sortAlertsBySeverity].
///
/// Renders nothing — `const SizedBox.shrink()`, not a gap-leaving spacer —
/// when both [alerts] and [nextHourNote] are empty/null, so neither Home
/// nor the Forecast screen ever shows a dangling blank space when there is
/// nothing to warn about. Both callers mirror this by only inserting their
/// own spacing before this widget when there is something to show.
///
/// [wrap] (issue #289) switches every row's message from Home's one-line,
/// ellipsized treatment (the default, `false`) to full wrapped text with no
/// line cap — the Forecast screen's "full text, wrapped, no ellipsis"
/// requirement.
///
/// Pure presentational widget: no network, provider, or clock dependency.
/// [now] only decides the day-label text; a caller that doesn't care about
/// day labels can simply omit it — a bare time window is shown instead of
/// falling back to the real system clock. The caller computes [alerts] and
/// [nextHourNote] via `buildForecastAlerts`/`buildNextHourNote` from the
/// real `WeatherProvider`/`MarineProvider` data, the same pattern
/// `SeaConditionsRow` and `StatTile` already follow.
class ForecastAlertList extends StatelessWidget {
  const ForecastAlertList({
    super.key,
    required this.alerts,
    this.nextHourNote,
    this.now,
    this.wrap = false,
  });

  final List<ForecastAlert> alerts;
  final ForecastAlert? nextHourNote;
  final DateTime? now;

  /// Issue #289: the Forecast screen shows every alert's full message,
  /// wrapped onto as many lines as it needs, instead of Home's one-line
  /// ellipsized treatment — so both [_ForecastAlertRow] and [_NextHourRow]
  /// take this flag rather than this file growing a second, near-duplicate
  /// pair of row widgets. Defaults to `false`, the original Home behavior.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty && nextHourNote == null) {
      return const SizedBox.shrink();
    }

    final sorted = sortAlertsBySeverity(alerts);
    final note = nextHourNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note != null) _NextHourRow(alert: note, wrap: wrap),
        if (note != null && sorted.isNotEmpty) const SizedBox(height: 10),
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _ForecastAlertRow(alert: sorted[i], now: now, wrap: wrap),
        ],
      ],
    );
  }
}

/// A single row in [ForecastAlertList]: a severity-colored type icon, the
/// alert's message (one line, ellipsized rather than wrapped, matching
/// `StatTile`/`SwimSuggestionPill`'s own single-line treatment) and its
/// compact time-window label underneath.
class _ForecastAlertRow extends StatelessWidget {
  const _ForecastAlertRow({
    required this.alert,
    required this.now,
    required this.wrap,
  });

  final ForecastAlert alert;
  final DateTime? now;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final color = _colorForSeverity(alert.severity);
    final windowLabel = _timeWindowLabel(alert, now);

    return Semantics(
      label: '${alert.message} $windowLabel',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconForType(alert.type), size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.message,
                  maxLines: wrap ? null : 1,
                  overflow: wrap ? null : TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  windowLabel,
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Issue #229's "next hour" row: visually distinct from [_ForecastAlertRow]
/// via a small "Next hour" label above the message (instead of a time
/// window underneath — the note is always about right now -> the next
/// hour, so a window label would be redundant) and the type icon inside a
/// soft tinted circle rather than bare, so it reads as a different kind of
/// row at a glance.
class _NextHourRow extends StatelessWidget {
  const _NextHourRow({required this.alert, required this.wrap});

  final ForecastAlert alert;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final color = _colorForSeverity(alert.severity);

    return Semantics(
      label: 'Next hour: ${alert.message}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(_iconForType(alert.type), size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next hour',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  maxLines: wrap ? null : 1,
                  overflow: wrap ? null : TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
