import 'package:flutter/material.dart';

import '../../logic/daily_outlook.dart';
import '../../logic/forecast_alerts.dart';
import '../widgets/daily_outlook_list.dart';
import '../widgets/forecast_alert_list.dart';

/// Forecast screen (issue #289, Vaen decision 2026-10-08: "one note on
/// Home, everything else in a detail screen"). Replaces Home's old inline
/// per-type `ForecastAlertList` rows and 7-14 day outlook with a dedicated
/// screen: Home itself only ever shows the single next-hour note.
///
/// Two sections: **Alerts** (every day-prefixed alert from
/// `buildForecastAlerts`, severity sorted, full text wrapped — no
/// ellipsis — "No alerts" when [alerts] is empty) and **7-14 day outlook**
/// (`DailyOutlookList`, full verdict message wrapped, high/low). Same dark
/// `bg.base`/`bg.gradientBottom` gradient and small-uppercase section-label
/// style as the Metric detail screens (`MetricDetailScaffold`), with a back
/// button — but not built on that scaffold itself, since it has no single
/// hero value or chart to show.
///
/// Pushed from [HomeScreen] with a snapshot of the selected location's
/// already-computed `forecastAlerts`/`dailyOutlook` (the same
/// `buildForecastAlerts`/`buildDailyOutlook` results Home itself would
/// otherwise have rendered), the same pattern `buildDetailRoute` uses for
/// every per-metric detail screen — it "follows the selected location" in
/// that it always reflects whichever location was selected on Home when
/// the row/note was tapped, not by holding a live provider reference of
/// its own.
class ForecastScreen extends StatelessWidget {
  const ForecastScreen({
    super.key,
    required this.alerts,
    required this.dailyOutlook,
    required this.formatTemperature,
    this.now,
  });

  /// Every upcoming alert for the selected location, from
  /// `buildForecastAlerts` — unlike Home's collapsed sheet, never trimmed
  /// to a single row.
  final List<ForecastAlert> alerts;

  /// The 7-14 day outlook entries, from `buildDailyOutlook`.
  final List<DailyOutlookEntry> dailyOutlook;

  /// Formats a nullable raw temperature into display text, matching the
  /// unit system Home's own header/hourly row use.
  final String Function(double? value) formatTemperature;

  /// Overridable "now" source (day labels on the alerts, "Today" on the
  /// outlook), so widget tests can pin it instead of depending on the real
  /// clock. Defaults to [DateTime.now].
  final DateTime Function()? now;

  static const _bgBase = Color(0xFF0D1220);
  static const _bgGradientBottom = Color(0xFF2A3145);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF8B93A6);

  Widget _buildSectionLabel({required String label, required IconData icon}) {
    return Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveNow = (now ?? DateTime.now)();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgBase, _bgGradientBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: _textPrimary),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    ),
                    const Expanded(
                      child: Text(
                        'Forecast',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    // Balances the leading back button so the title stays
                    // visually centered, matching MetricDetailScaffold's
                    // header.
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionLabel(
                  label: 'Alerts',
                  icon: Icons.notifications_none,
                ),
                const SizedBox(height: 12),
                if (alerts.isEmpty)
                  const Text(
                    'No alerts',
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  )
                else
                  ForecastAlertList(
                    alerts: alerts,
                    now: effectiveNow,
                    wrap: true,
                  ),
                const SizedBox(height: 24),
                _buildSectionLabel(
                  label: '7-14 day outlook',
                  icon: Icons.calendar_month,
                ),
                const SizedBox(height: 12),
                DailyOutlookList(
                  entries: dailyOutlook,
                  formatTemperature: formatTemperature,
                  now: effectiveNow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
