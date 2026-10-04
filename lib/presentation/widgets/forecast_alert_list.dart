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

/// A compact "09:00 - 10:00" label, distinct from [ForecastAlert.message]
/// (which already spells the same window out as a sentence, e.g. "Wind
/// picks up between 09:00 and 10:00.") — this is the scannable summary the
/// issue's "icon + one line + time window" layout asks for underneath that
/// sentence.
String _timeWindowLabel(ForecastAlert alert) =>
    '${_formatHour(alert.start)} - ${_formatHour(alert.end)}';

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

/// The Home screen's upcoming-forecast-alerts list (issue #169), per
/// docs/design.md "Home: alert list": sits between the smart suggestion
/// pill and the stat grid, one row per [ForecastAlert] — a type icon
/// (colored by [ForecastAlert.severity] via [_colorForSeverity]), the
/// alert's one-line [ForecastAlert.message], and a compact time-window
/// label underneath — sorted most severe first via [sortAlertsBySeverity].
///
/// Renders nothing — `const SizedBox.shrink()`, not a gap-leaving spacer —
/// when [alerts] is empty, so the Home screen never shows a dangling blank
/// space when there is nothing to warn about. `home_screen.dart` mirrors
/// this by only inserting its own spacing before this widget when
/// [alerts] is non-empty.
///
/// Pure presentational widget: no network, provider, or clock dependency.
/// The caller (`home_screen.dart`) computes [alerts] via
/// `buildForecastAlerts` from the real `WeatherProvider`/`MarineProvider`
/// data, the same pattern `SeaConditionsRow` and `StatTile` already follow.
class ForecastAlertList extends StatelessWidget {
  const ForecastAlertList({super.key, required this.alerts});

  final List<ForecastAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    final sorted = sortAlertsBySeverity(alerts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _ForecastAlertRow(alert: sorted[i]),
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
  const _ForecastAlertRow({required this.alert});

  final ForecastAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = _colorForSeverity(alert.severity);
    final windowLabel = _timeWindowLabel(alert);

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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
