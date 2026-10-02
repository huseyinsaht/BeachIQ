import 'package:flutter/material.dart';

/// Shared layout for every per-metric detail screen (Pressure, and the UV
/// index/rain chance/wind/wave height/water temperature/current screens
/// that follow in later issues) — NOT a shared screen itself: each metric
/// still gets its own `*_detail_screen.dart` file that supplies the title,
/// hero value, chart and explanation text, and composes them with this
/// scaffold so every detail screen looks consistent with Home (same
/// `bg.base`/`bg.gradientBottom` gradient, `text.primary`/`text.secondary`
/// colors — see docs/design.md § "Screen: Metric detail").
///
/// Top to bottom: an app bar with a back button, a hero current value
/// (with an optional unit and trend line under it), a chart slot (any
/// widget — typically an [HourlyMetricChart]), a min/max/now summary row,
/// and a short explanation paragraph.
class MetricDetailScaffold extends StatelessWidget {
  const MetricDetailScaffold({
    super.key,
    required this.title,
    required this.heroValue,
    this.heroUnit,
    this.trendText,
    required this.chart,
    required this.minValueLabel,
    required this.nowValueLabel,
    required this.maxValueLabel,
    required this.explanation,
  });

  /// The app bar title, e.g. "Pressure".
  final String title;

  /// The large hero number, already formatted (e.g. "1013").
  final String heroValue;

  /// A short unit string under the hero value (e.g. "hPa"). Null hides it.
  final String? heroUnit;

  /// A one-line trend/status under the hero value (e.g. "Rising — a sign
  /// of improving weather."). Null hides it.
  final String? trendText;

  /// The detail screen's chart, e.g. an [HourlyMetricChart] configured for
  /// that metric. This scaffold only reserves the layout slot for it.
  final Widget chart;

  final String minValueLabel;
  final String nowValueLabel;
  final String maxValueLabel;

  /// A short paragraph explaining what this metric means for the weather.
  final String explanation;

  static const _bgBase = Color(0xFF0D1220);
  static const _bgGradientBottom = Color(0xFF2A3145);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
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
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    // Balances the leading back button so the title stays
                    // visually centered, matching SearchScreen's header.
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      Text(
                        heroValue,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 44,
                        ),
                      ),
                      if (heroUnit != null)
                        Text(
                          heroUnit!,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      if (trendText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          trendText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                chart,
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SummaryEntry(label: 'Min', value: minValueLabel),
                    _SummaryEntry(label: 'Now', value: nowValueLabel),
                    _SummaryEntry(label: 'Max', value: maxValueLabel),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  explanation,
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryEntry extends StatelessWidget {
  const _SummaryEntry({required this.label, required this.value});

  final String label;
  final String value;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: _textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
