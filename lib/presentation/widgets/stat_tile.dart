import 'package:flutter/material.dart';

/// A single compact stat tile used in the Home screen's 3x3 stat grid
/// (issue #251: Sea/Current/Air groups of three tiles each, all one visual
/// size) — a small icon at the left of a `text.secondary` label, then the
/// value (with its unit as a visually secondary run next to it, when
/// supplied separately), then an optional short colored status word (e.g.
/// "Calm", "High", or the Sea section's shore-relation line).
///
/// Per docs/design.md's "Stat grid", the grid has no tile background — it
/// sits directly on the screen's gradient. Issue #251 also drops the old
/// 2x2 grid's trend row entirely (no tile on Home has a meaningful
/// time-delta to show once wave height/water temp/current speed/direction
/// share this same tile style) — the detail screens keep their own trend
/// lines, driven by `MetricDetailScaffold`, not this widget.
///
/// Sized by its own content (no forced aspect ratio): each tile sits inside
/// an `Expanded` column of a 3-wide `Row` (see `StatTileGroup`), bounding
/// its width so the value's `FittedBox` can still shrink a long string
/// rather than overflow, while its height simply grows with whatever it
/// needs to show (e.g. a wrapped shore-relation line) — see
/// [statusLabel]'s doc comment.
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
    this.iconRotationDegrees,
    this.statusLabel,
    this.statusColor,
    this.statusBold = false,
    this.onTap,
  }) : assert(
         (statusLabel == null) == (statusColor == null),
         'statusLabel and statusColor must be supplied together, or not '
         'at all — a status word with no color (or vice versa) is never a '
         'valid state.',
       );

  final IconData icon;
  final String label;

  /// The tile's headline number, already formatted (e.g. "18", "1013",
  /// "4.5", or a combined string like "0.9 m"/"<= 1.2 m for 180 m" — never
  /// a raw/unformatted number. Null/loading data is represented by the
  /// caller passing the existing placeholder string here (e.g. "No data")
  /// with [unit] left null.
  final String value;

  /// A short unit string shown right after [value] as a visually smaller,
  /// secondary run on the same line (e.g. "km/h", "hPa") — never
  /// concatenated into [value] itself, so each is rendered as its own
  /// `TextSpan`. Null hides it entirely (e.g. UV index, which has no unit,
  /// a metric whose formatter already returns a combined string such as
  /// wave height's "0.9 m", or whenever [value] is itself a "No data"
  /// placeholder).
  final String? unit;

  /// Rotates [icon] clockwise by this many degrees from "up", for the Sea
  /// section's direction tiles (current direction/wave direction): the
  /// compass-bearing convention `wave_shore_relation.dart` and
  /// `SeaCondition`'s own doc comments describe. Null (the default) keeps
  /// the icon unrotated, exactly like every non-direction tile.
  final double? iconRotationDegrees;

  /// A short status word/phrase (e.g. "Calm", "Moderate", "High", or the
  /// Sea section's shore-relation line, e.g. "(away from shore — stay
  /// close!)") shown as a small colored line under the value, for metrics
  /// that have a defined status. Null omits the line entirely — metrics
  /// without one (e.g. wave height, water temperature, current speed, or
  /// wave direction, which has no defined status at all per issue #251)
  /// simply have no third line, never an empty one. Must be supplied
  /// together with [statusColor]. Wraps onto further lines (never
  /// ellipsis-truncated) so the one safety-relevant warning this grid shows
  /// (the Sea section's away-from-shore label) is never clipped.
  final String? statusLabel;

  /// The color for [statusLabel]'s dot/text. Must be supplied together with
  /// [statusLabel].
  final Color? statusColor;

  /// Bolds [statusLabel] — used for the Sea section's away-from-shore
  /// warning (issue #164), which signals drift-out/rip-current risk and so
  /// is visually flagged beyond just its color, matching
  /// `sea_conditions_row.dart`'s pre-#251 treatment of the same case.
  /// Ignored when [statusLabel] is null.
  final bool statusBold;

  /// Opens this metric's own detail screen (issue #165) when set. Null
  /// (the default) keeps today's behavior exactly: no `InkWell`/ripple, no
  /// tap target at all — every existing caller/test is unaffected.
  final VoidCallback? onTap;

  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    // A percent sign attaches directly to its number ("55%"); every other
    // unit this app shows ("km/h", "hPa", "mph") reads as a separate word,
    // so it needs a space before it ("18 km/h"). This one rule covers both
    // without every caller having to bake its own spacing into the unit
    // string it passes in.
    final unitSeparator = unit != null && unit!.startsWith('%') ? '' : ' ';
    final valuePart = unit == null ? value : '$value$unitSeparator$unit';
    final semanticsLabel = statusLabel == null
        ? '$label, $valuePart'
        : '$label, $valuePart, $statusLabel';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: (iconRotationDegrees ?? 0) * 3.1415926535 / 180,
              child: Icon(icon, size: 16, color: _textSecondary),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Align + FittedBox (not maxLines/ellipsis) so a long value at a
        // narrow tile width/large text scale shrinks to fit instead of
        // being clipped — the tile's bounded *width* (from its parent
        // `Expanded` in `StatTileGroup`'s 3-wide row) is all `FittedBox`
        // needs for this; the tile's height is left to grow naturally
        // (issue #251's "no overflow at 360dp + large text scale"
        // acceptance criterion).
        Align(
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
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: '$unitSeparator$unit',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              key: const Key('stat-tile-value'),
            ),
          ),
        ),
        if (statusLabel != null) ...[
          const SizedBox(height: 4),
          _StatusChip(
            label: statusLabel!,
            color: statusColor!,
            bold: statusBold,
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

/// A short colored status word/phrase with a leading dot, e.g. a green
/// "Calm" or a red "High" — or, for the Sea section's shore-relation line,
/// a longer phrase that wraps onto further lines instead of being clipped
/// (see [StatTile.statusLabel]'s doc comment).
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.bold = false,
  });

  final String label;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 5),
        // No `maxLines`/`overflow` here at all (unlike every other label in
        // this widget) — the one safety-relevant line this grid shows (the
        // Sea section's away-from-shore warning) must never be clipped, so
        // it wraps onto as many lines as it needs rather than being capped.
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
