import 'package:flutter/material.dart';

/// Direction of a [StatTile]'s trend indicator.
enum StatTrendDirection { up, down }

/// A single stat card used in the home screen's 2x2 stat grid (wind speed,
/// rain chance, water depth, UV index): a small icon at the left, a label
/// above a large value (with its unit as a visually secondary run next to
/// it), an optional short colored status word (e.g. "Calm", "High"), and an
/// optional muted trend indicator at the bottom-right.
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
    this.unit,
    this.statusLabel,
    this.statusColor,
    this.trendDirection,
    this.trendDelta,
    this.onTap,
  }) : assert(
         (statusLabel == null) == (statusColor == null),
         'statusLabel and statusColor must be supplied together, or not '
         'at all — a status word with no color (or vice versa) is never a '
         'valid state.',
       ),
       assert(
         (trendDirection == null) == (trendDelta == null),
         'trendDirection and trendDelta must be supplied together, or not '
         'at all — a metric with no meaningful delta (e.g. a spatial '
         'reading like water depth, issue #217) omits the trend row '
         'entirely rather than showing a fabricated one.',
       );

  final IconData icon;
  final String label;

  /// The tile's headline number, already formatted (e.g. "18", "1013",
  /// "4.5") — never includes the unit, which is a separate visual run (see
  /// [unit]). Null/loading data is represented by the caller passing the
  /// existing placeholder string here (e.g. "No data") with [unit] left
  /// null, exactly like before this widget had a separate unit parameter.
  final String value;

  /// A short unit string shown right after [value] as a visually smaller,
  /// secondary run on the same line (e.g. "km/h", "hPa") — never
  /// concatenated into [value] itself, so each is rendered as its own
  /// `TextSpan`. Null hides it entirely (e.g. UV index, which has no unit,
  /// or whenever [value] is itself a "No data" placeholder).
  final String? unit;

  /// A short status word (e.g. "Calm", "Moderate", "High") shown as a small
  /// colored chip under the value, for metrics that have a defined status
  /// (wind speed, rain chance, UV index band). Null omits the chip
  /// entirely — metrics without a defined status (e.g. pressure, when only
  /// a trend arrow is available) simply have no chip, never an empty one.
  /// Must be supplied together with [statusColor].
  final String? statusLabel;

  /// The color for [statusLabel]'s dot/chip. Must be supplied together with
  /// [statusLabel].
  final Color? statusColor;

  /// The trend row's arrow direction, shown at the tile's bottom-right.
  /// Null (together with [trendDelta]) omits the whole trend row — for a
  /// metric with no meaningful delta to show (e.g. water depth, issue
  /// #217, a spatial reading rather than a time series). Must be supplied
  /// together with [trendDelta].
  final StatTrendDirection? trendDirection;

  /// The trend row's delta text (e.g. "2 km/h"). Must be supplied together
  /// with [trendDirection].
  final String? trendDelta;

  /// Opens this metric's own detail screen (issue #165) when set. Null
  /// (the default) keeps today's behavior exactly: no `InkWell`/ripple, no
  /// tap target at all — every existing caller/test is unaffected.
  final VoidCallback? onTap;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    final direction = trendDirection;
    final delta = trendDelta;
    final hasTrend = direction != null && delta != null;
    final trendWord = direction == StatTrendDirection.up ? 'up' : 'down';
    // A percent sign attaches directly to its number ("55%"); every other
    // unit this app shows ("km/h", "hPa", "mph") reads as a separate word,
    // so it needs a space before it ("18 km/h"). This one rule covers both
    // without every caller having to bake its own spacing into the unit
    // string it passes in.
    final unitSeparator = unit != null && unit!.startsWith('%') ? '' : ' ';
    final valuePart = unit == null ? value : '$value$unitSeparator$unit';
    final trendSuffix = hasTrend ? ', trend $trendWord $delta' : '';
    final semanticsLabel = statusLabel == null
        ? '$label, $valuePart$trendSuffix'
        : '$label, $valuePart, $statusLabel$trendSuffix';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wrapped in Expanded (rather than sized by its own content) so
        // the value row below can always claim whatever vertical space is
        // left and shrink its `FittedBox` to fit it — this tile must never
        // overflow regardless of the grid's own cell height (issue #215's
        // "no overflow at 360dp + 1.3x text scale" acceptance criterion).
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: _textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    // FittedBox (not maxLines/ellipsis) so a long value at
                    // a narrow tile width/large text scale shrinks to fit
                    // instead of being clipped.
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 27,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (unit != null)
                                  TextSpan(
                                    text: '$unitSeparator$unit',
                                    style: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            key: const Key('stat-tile-value'),
                          ),
                        ),
                      ),
                    ),
                    if (statusLabel != null) ...[
                      const SizedBox(height: 2),
                      _StatusChip(label: statusLabel!, color: statusColor!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // No trend row at all (not an empty one) when this metric has no
        // meaningful delta to show — see [trendDirection]'s doc comment.
        if (hasTrend) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  direction == StatTrendDirection.up
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  size: 16,
                  color: _textSecondary,
                ),
                Flexible(
                  child: Text(
                    delta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: onTap == null
          ? content
          : InkWell(
              key: const Key('stat-tile-tap-target'),
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

/// A short colored status word with a leading dot, e.g. a green "Calm" or a
/// red "High".
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
