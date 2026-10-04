import 'package:flutter/material.dart';

import '../../logic/chart_axis.dart';

/// One hourly data point for [HourlyMetricChart]: a timestamp and a
/// nullable value. A `null` [value] renders as a gap in the line — it is
/// never plotted as zero, since zero is a valid real value for several
/// metrics (e.g. rain chance).
class HourlyChartPoint {
  const HourlyChartPoint({required this.time, this.value});

  final DateTime time;
  final double? value;
}

/// A horizontal reference line drawn across the chart at a fixed [value]
/// (e.g. a "storm risk" pressure cutoff), with an optional [label].
///
/// Metric-specific detail screens (pressure, UV index, wind, ...) each pick
/// their own thresholds; this widget just draws whatever it is given.
class HourlyChartThreshold {
  const HourlyChartThreshold({
    required this.value,
    required this.color,
    this.label,
  });

  final double value;
  final Color color;
  final String? label;
}

/// A colored background band covering a fixed range of *values* (not an
/// x-axis range), e.g. the UV index detail screen's low/moderate/high/very
/// high/extreme bands (issue #178). Unlike [bandColor] (which fills the
/// area under the data line, shaped by the data itself), a value band
/// always covers the same horizontal strip of the chart regardless of
/// where the line goes — it represents a fixed classification range.
///
/// Generic/value-range-keyed rather than UV-specific so later metrics can
/// reuse it for their own bands (e.g. a wind-speed scale).
///
/// [max] of `null` means "and above" — the topmost band extends to the top
/// of the chart's visible value range (e.g. UV 11+).
class HourlyChartValueBand {
  const HourlyChartValueBand({
    required this.min,
    this.max,
    required this.color,
    this.label,
  });

  final double min;
  final double? max;
  final Color color;
  final String? label;
}

/// A reusable hourly line/area chart for the metric detail screens (shared
/// foundation for issue #165 and the metric-specific PRs that follow it):
/// a "Now" marker at [nowIndex], optional threshold lines, an optional
/// colored area band under the line, optional fixed-range [valueBands]
/// (e.g. UV index's colored bands), and a value scale (y-axis) + hour
/// labels (x-axis, issue #212). `null` hours in [points] are gaps — the
/// line breaks there instead of dipping to zero.
///
/// Implemented with [CustomPaint] (no charting package dependency). The
/// painter is exposed as [HourlyMetricChartPainter] so widget tests can
/// inspect the exact points it was given, rather than asserting on pixels.
///
/// Axis labels (issue #212): [valueFormatter] formats a raw tick value
/// (e.g. `1010.0 -> "1010"`), and [unitLabel] (e.g. `"hPa"`) is appended to
/// every formatted tick — with no separating space when the unit attaches
/// directly to the number by typographic convention (`°`, `%`), and a
/// space otherwise, matching how the rest of the app already formats units
/// (`unit_preferences.dart`'s `formatTemperature`/`formatWaveHeight`/etc.).
/// Both are optional: a caller that doesn't pass them still gets a value
/// scale, just with bare rounded numbers.
class HourlyMetricChart extends StatelessWidget {
  const HourlyMetricChart({
    super.key,
    required this.points,
    this.nowIndex,
    this.thresholds = const [],
    this.valueBands = const [],
    this.lineColor = Colors.white,
    this.bandColor,
    this.height = 160,
    this.valueFormatter,
    this.unitLabel,
  });

  /// The hourly series to plot, left to right in order (oldest first).
  final List<HourlyChartPoint> points;

  /// Index into [points] that represents "now" (typically 0, matching the
  /// Home screen's hourly row convention of starting with "Now"). Null
  /// hides the marker entirely; an out-of-range index or a null value at
  /// that index also hides it rather than throwing. Also the index whose
  /// x-axis label reads "Now" instead of its clock hour.
  final int? nowIndex;

  final List<HourlyChartThreshold> thresholds;

  /// Fixed value-range bands (e.g. UV index's low/moderate/.../extreme),
  /// painted first as full-width background strips so the threshold lines,
  /// data line/area and "Now" marker all render on top of them.
  final List<HourlyChartValueBand> valueBands;

  final Color lineColor;

  /// Fills the area between the line and the chart's bottom edge when set.
  /// Null (the default) draws the line only.
  final Color? bandColor;

  final double height;

  /// Formats a y-axis tick's raw value, e.g. `(v) => v.round().toString()`.
  /// Null defaults to a plain rounded integer. See this class's doc
  /// comment for how it combines with [unitLabel].
  final String Function(double value)? valueFormatter;

  /// The unit suffix appended to every y-axis tick label (e.g. `"hPa"`,
  /// `"m"`, `"°C"`, `"%"`). Null omits the unit (e.g. UV index, which has
  /// none). See this class's doc comment for the exact spacing rule.
  final String? unitLabel;

  static const _textSecondary = Color(0xFF8B93A6);
  static const _axisLabelStyle = TextStyle(
    color: _textSecondary,
    fontSize: 10,
  );

  /// At least 3 ticks (acceptance criterion) and not so many they crowd a
  /// narrow gutter; 4 is [niceTicks]'s usual sweet spot (see its own doc
  /// comment), typically returning 4-6 actual ticks.
  static const int _targetYTicks = 4;

  /// Minimum horizontal pixels between two x-axis hour labels before a
  /// coarser hour step is tried instead, so labels never visually overlap
  /// at narrow widths — see [_xAxisStepHours].
  static const double _minXLabelSpacing = 48;

  /// Candidate hour steps for the x-axis, smallest first. Starts at 3h
  /// (the acceptance criterion's "every 3-6h" floor) rather than 1h so a
  /// wide chart with hourly data doesn't end up with a label on every
  /// single point.
  static const List<int> _xAxisStepCandidates = [3, 4, 6, 8, 12, 24];

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No data',
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    final presentValues = points
        .map((p) => p.value)
        .whereType<double>()
        .toList();
    var minValue = presentValues.isEmpty
        ? 0.0
        : presentValues.reduce((a, b) => a < b ? a : b);
    var maxValue = presentValues.isEmpty
        ? 1.0
        : presentValues.reduce((a, b) => a > b ? a : b);
    // Widen a flat/near-flat range so threshold lines and the data line
    // don't collapse onto the same pixel row.
    if ((maxValue - minValue).abs() < 1e-9) {
      minValue -= 1;
      maxValue += 1;
    }

    // Computed once, right here, from the exact same minValue/maxValue the
    // line itself is about to be drawn against (just below) — the single
    // source of truth both the line and the y-axis ticks read from, so
    // they can never diverge (issue #212's explicit requirement).
    final rawYTicks = niceTicks(minValue, maxValue, _targetYTicks);
    final rawYTickLabels = [for (final tick in rawYTicks) _tickLabel(tick)];
    final (yTicks, yTickLabels) = _dedupeTicks(rawYTicks, rawYTickLabels);

    final textScaler = MediaQuery.textScalerOf(context);
    final gutterWidth = _maxTextWidth(yTickLabels, _axisLabelStyle, textScaler) + 8;
    final bottomAxisHeight =
        _textHeight('Now', _axisLabelStyle, textScaler) + 6;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);
          // Clamp so a long unit label at a huge text scale narrows the
          // plot area rather than pushing it to (or past) zero width.
          final clampedGutter = gutterWidth.clamp(0.0, size.width * 0.4);
          final clampedBottom = bottomAxisHeight.clamp(0.0, size.height * 0.4);
          final plotRect = Rect.fromLTWH(
            clampedGutter,
            0,
            (size.width - clampedGutter).clamp(0.0, size.width),
            (size.height - clampedBottom).clamp(0.0, size.height),
          );
          final xAxisLabels = _buildXAxisLabels(plotRect.width);

          final painter = HourlyMetricChartPainter(
            points: points,
            minValue: minValue,
            maxValue: maxValue,
            lineColor: lineColor,
            bandColor: bandColor,
            thresholds: thresholds,
            valueBands: valueBands,
            plotRect: plotRect,
            yTicks: yTicks,
            yTickLabels: yTickLabels,
            xAxisLabels: xAxisLabels,
            axisLabelStyle: _axisLabelStyle,
            textScaler: textScaler,
          );
          final marker = _nowMarkerPosition(plotRect, minValue, maxValue);
          return Stack(
            children: [
              CustomPaint(size: size, painter: painter),
              if (marker != null)
                Positioned(
                  left: (marker.dx - 14).clamp(0.0, size.width),
                  top: (marker.dy - 28).clamp(0.0, size.height),
                  child: const _NowMarkerLabel(),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The pixel position of the "Now" marker, or null when it shouldn't be
  /// shown (no [nowIndex], it's out of range, or that hour has no data).
  Offset? _nowMarkerPosition(Rect plotRect, double minValue, double maxValue) {
    final index = nowIndex;
    if (index == null || index < 0 || index >= points.length) return null;
    final value = points[index].value;
    if (value == null) return null;
    final x = points.length <= 1
        ? plotRect.left
        : plotRect.left + plotRect.width * index / (points.length - 1);
    final range = maxValue - minValue;
    final y = plotRect.top + plotRect.height * (1 - (value - minValue) / range);
    return Offset(x, y);
  }

  /// Formats [value] per this widget's [valueFormatter]/[unitLabel] doc
  /// comment: the formatted number, then the unit with no separating space
  /// when it attaches directly to the number by convention (`°`, `%`).
  String _tickLabel(double value) {
    final formatted = (valueFormatter ?? _defaultTickFormat)(value);
    final unit = unitLabel;
    if (unit == null || unit.isEmpty) return formatted;
    final attachesDirectly = unit.startsWith('°') || unit.startsWith('%');
    return attachesDirectly ? '$formatted$unit' : '$formatted $unit';
  }

  static String _defaultTickFormat(double value) => value.round().toString();

  /// Drops any tick whose formatted label duplicates the previously kept
  /// one (issue #212 functional verification: a narrow value range can
  /// make [niceTicks] pick a fractional step — e.g. `0.5` on a 2-unit
  /// pressure range — that two formatted labels round to the same string,
  /// such as `1010, 1010, 1011, 1012, 1012`). Two ticks sharing a label
  /// would sit at different pixel heights but read as the same value,
  /// which is misleading, so every label shown must be distinct. This can
  /// leave fewer than [_targetYTicks]/3 ticks when the formatter's
  /// precision genuinely can't distinguish that many values in the range
  /// (e.g. a 1-degree-wide series rounded to whole degrees has only two
  /// distinct integers to show) — an unavoidable precision limit, not a
  /// bug, the same way a flat series already shows fewer meaningful ticks.
  (List<double>, List<String>) _dedupeTicks(
    List<double> ticks,
    List<String> labels,
  ) {
    final dedupedTicks = <double>[];
    final dedupedLabels = <String>[];
    for (var i = 0; i < ticks.length; i++) {
      if (dedupedLabels.isNotEmpty && dedupedLabels.last == labels[i]) {
        continue;
      }
      dedupedTicks.add(ticks[i]);
      dedupedLabels.add(labels[i]);
    }
    return (dedupedTicks, dedupedLabels);
  }

  /// Picks the hour step between x-axis labels: the smallest candidate in
  /// [_xAxisStepCandidates] whose pixel spacing (at this series' density)
  /// is at least [_minXLabelSpacing], falling back to the coarsest
  /// candidate when even that isn't enough room (e.g. a very narrow chart
  /// with lots of hourly points).
  int _xAxisStepHours(double plotWidth) {
    if (points.length <= 1) return _xAxisStepCandidates.first;
    final pxPerPoint = plotWidth / (points.length - 1);
    for (final step in _xAxisStepCandidates) {
      if (step * pxPerPoint >= _minXLabelSpacing) return step;
    }
    return _xAxisStepCandidates.last;
  }

  /// The x-axis labels to draw: every [_xAxisStepHours]-th hour (by index,
  /// since [points] is always consecutive hourly entries) plus [nowIndex]
  /// itself (labeled "Now" rather than its clock hour) even when it falls
  /// off that grid.
  List<({double dx, String text})> _buildXAxisLabels(double plotWidth) {
    final n = points.length;
    final step = _xAxisStepHours(plotWidth);
    final indices = <int>{for (var i = 0; i < n; i += step) i};
    final now = nowIndex;
    if (now != null && now >= 0 && now < n) indices.add(now);

    final sorted = indices.toList()..sort();
    return [
      for (final i in sorted)
        (
          dx: n <= 1 ? 0.0 : i / (n - 1),
          text: i == now ? 'Now' : _axisHourLabel(points[i].time),
        ),
    ];
  }

  /// 12-hour clock label for an hour, e.g. `"3PM"`, `"12AM"` — the same
  /// format `home_screen.dart`'s hourly row and the detail screens' own
  /// period/direction strips already use.
  String _axisHourLabel(DateTime time) {
    final hour = time.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour$period';
  }

  static double _maxTextWidth(
    List<String> texts,
    TextStyle style,
    TextScaler textScaler,
  ) {
    var max = 0.0;
    for (final text in texts) {
      final width = _measure(text, style, textScaler).width;
      if (width > max) max = width;
    }
    return max;
  }

  static double _textHeight(
    String text,
    TextStyle style,
    TextScaler textScaler,
  ) {
    return _measure(text, style, textScaler).height;
  }

  static Size _measure(String text, TextStyle style, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return painter.size;
  }
}

class _NowMarkerLabel extends StatelessWidget {
  const _NowMarkerLabel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: Key('hourly-chart-now-marker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Now',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        _NowDot(),
      ],
    );
  }
}

class _NowDot extends StatelessWidget {
  const _NowDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Paints [points] as a line (and optional filled band) with gaps at `null`
/// values, plus any [thresholds] as horizontal reference lines, and the
/// value scale (y-axis)/hour labels (x-axis) from [yTicks]/[xAxisLabels]
/// (issue #212).
///
/// Public (not private) so widget tests can find the [CustomPaint] in the
/// tree and inspect this painter's fields directly — e.g. asserting that a
/// `null` hour is still present in [points] with its `value` unchanged
/// (never rewritten to `0`) rather than trying to assert on rendered
/// pixels.
///
/// [plotRect]/[yTicks]/[yTickLabels]/[xAxisLabels]/[axisLabelStyle]/
/// [textScaler] default to "no axes" (a null [plotRect] falls back to the
/// painter's full canvas, matching this class's pre-#212 behavior) so code
/// that constructs this painter directly without them — as some tests
/// still do — keeps compiling and painting the line/bands/thresholds
/// exactly as before.
class HourlyMetricChartPainter extends CustomPainter {
  const HourlyMetricChartPainter({
    required this.points,
    required this.minValue,
    required this.maxValue,
    required this.lineColor,
    required this.bandColor,
    required this.thresholds,
    this.valueBands = const [],
    this.plotRect,
    this.yTicks = const [],
    this.yTickLabels = const [],
    this.xAxisLabels = const [],
    this.axisLabelStyle = const TextStyle(
      color: Color(0xFF8B93A6),
      fontSize: 10,
    ),
    this.textScaler = TextScaler.noScaling,
  });

  final List<HourlyChartPoint> points;
  final double minValue;
  final double maxValue;
  final Color lineColor;
  final Color? bandColor;
  final List<HourlyChartThreshold> thresholds;
  final List<HourlyChartValueBand> valueBands;

  /// The area the line/bands/thresholds/grid are drawn in, inset from the
  /// full canvas to leave room for the y-axis gutter (left) and x-axis
  /// labels (bottom). Null means "use the whole canvas" (no axes).
  final Rect? plotRect;

  /// Pre-computed tick values (from [minValue]/[maxValue] — see this
  /// class's doc comment on why that ordering matters) to draw as grid
  /// lines + y-axis labels.
  final List<double> yTicks;

  /// [yTicks]' formatted labels, in the same order.
  final List<String> yTickLabels;

  /// Hour labels to draw along the x-axis.
  final List<({double dx, String text})> xAxisLabels;

  final TextStyle axisLabelStyle;
  final TextScaler textScaler;

  static final Paint _gridLinePaint = Paint()
    ..color = const Color(0x1FFFFFFF)
    ..strokeWidth = 1;

  double get _range {
    final range = maxValue - minValue;
    return range.abs() < 1e-9 ? 1.0 : range;
  }

  Rect _plotRectFor(Size size) =>
      plotRect ?? Rect.fromLTWH(0, 0, size.width, size.height);

  Offset? _offsetFor(int index, Rect rect) {
    final value = points[index].value;
    if (value == null) return null;
    final x = points.length <= 1
        ? rect.left
        : rect.left + rect.width * index / (points.length - 1);
    final y = rect.top + rect.height * (1 - (value - minValue) / _range);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final rect = _plotRectFor(size);

    canvas.save();
    canvas.clipRect(rect);

    for (final band in valueBands) {
      _paintValueBand(canvas, rect, band);
    }

    _paintYGridLines(canvas, rect);

    final thresholdPaint = Paint()..strokeWidth = 1;
    for (final threshold in thresholds) {
      final y = rect.top + rect.height * (1 - (threshold.value - minValue) / _range);
      thresholdPaint.color = threshold.color;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), thresholdPaint);
    }

    if (bandColor != null) {
      _paintBand(canvas, rect, bandColor!);
    }
    _paintLine(canvas, rect);

    canvas.restore();

    _paintYAxisLabels(canvas, rect);
    _paintXAxisLabels(canvas, rect, size);
  }

  /// Light horizontal grid lines at each y-tick, spanning the plot area's
  /// full width — drawn after the value bands (so they stay visible on
  /// top of a band's translucent fill) but before the threshold lines/data
  /// line/area (so those stay the most prominent thing on the chart).
  void _paintYGridLines(Canvas canvas, Rect rect) {
    for (final tick in yTicks) {
      final y = rect.top + rect.height * (1 - (tick - minValue) / _range);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), _gridLinePaint);
    }
  }

  /// Right-aligned tick labels in the left gutter (i.e. outside [rect],
  /// which is why this runs after the clipped block in [paint] restores
  /// the canvas) — one per [yTicks]/[yTickLabels] pair, vertically centered
  /// on that tick's grid line.
  void _paintYAxisLabels(Canvas canvas, Rect rect) {
    for (var i = 0; i < yTicks.length && i < yTickLabels.length; i++) {
      final y = rect.top + rect.height * (1 - (yTicks[i] - minValue) / _range);
      final painter = TextPainter(
        text: TextSpan(text: yTickLabels[i], style: axisLabelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: rect.left);
      final dy = (y - painter.height / 2).clamp(0.0, double.infinity);
      painter.paint(canvas, Offset(rect.left - 6 - painter.width, dy));
    }
  }

  /// Centered hour labels along the bottom, below [rect] — horizontally
  /// clamped to the canvas so a label near either edge never gets clipped
  /// off by going negative or past [size]'s right edge.
  void _paintXAxisLabels(Canvas canvas, Rect rect, Size size) {
    for (final label in xAxisLabels) {
      final x = rect.left + rect.width * label.dx;
      final painter = TextPainter(
        text: TextSpan(text: label.text, style: axisLabelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      // `size.width - painter.width` can go negative for a very wide label
      // on a very narrow canvas (large text scale); clamping it to 0 first
      // keeps `clamp`'s own bounds valid instead of throwing.
      final maxDx = (size.width - painter.width) < 0
          ? 0.0
          : size.width - painter.width;
      final dx = (x - painter.width / 2).clamp(0.0, maxDx);
      painter.paint(canvas, Offset(dx, rect.bottom + 4));
    }
  }

  /// Draws the data line as one or more disconnected [Path]s, starting a
  /// fresh path after every `null` value so a gap is a real visual break
  /// instead of a straight segment through a fabricated zero.
  void _paintLine(Canvas canvas, Rect rect) {
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path? current;
    for (var i = 0; i < points.length; i++) {
      final offset = _offsetFor(i, rect);
      if (offset == null) {
        if (current != null) {
          canvas.drawPath(current, linePaint);
          current = null;
        }
        continue;
      }
      if (current == null) {
        current = Path()..moveTo(offset.dx, offset.dy);
      } else {
        current.lineTo(offset.dx, offset.dy);
      }
    }
    if (current != null) {
      canvas.drawPath(current, linePaint);
    }
  }

  /// Paints [band] as a full-width horizontal strip covering its value
  /// range, clipped to the chart's visible `[minValue, maxValue]` range.
  /// Skipped entirely when the band doesn't overlap that visible range at
  /// all (e.g. a 11+ band when every reading is in the single digits).
  void _paintValueBand(Canvas canvas, Rect rect, HourlyChartValueBand band) {
    if (band.min > maxValue) return;
    if (band.max != null && band.max! < minValue) return;

    final clampedMin = band.min < minValue ? minValue : band.min;
    final bandMax = band.max;
    final clampedMax = (bandMax == null || bandMax > maxValue)
        ? maxValue
        : bandMax;
    if (clampedMax <= clampedMin) return;

    final topY = rect.top + rect.height * (1 - (clampedMax - minValue) / _range);
    final bottomY = rect.top + rect.height * (1 - (clampedMin - minValue) / _range);
    canvas.drawRect(
      Rect.fromLTRB(rect.left, topY, rect.right, bottomY),
      Paint()..color = band.color,
    );
  }

  void _paintBand(Canvas canvas, Rect rect, Color color) {
    final bandPaint = Paint()..color = color;
    Path? current;
    double? firstX;
    double? lastX;

    void flush() {
      final path = current;
      final left = firstX;
      final right = lastX;
      if (path != null && left != null && right != null) {
        path.lineTo(right, rect.bottom);
        path.lineTo(left, rect.bottom);
        path.close();
        canvas.drawPath(path, bandPaint);
      }
      current = null;
      firstX = null;
      lastX = null;
    }

    for (var i = 0; i < points.length; i++) {
      final offset = _offsetFor(i, rect);
      if (offset == null) {
        flush();
        continue;
      }
      final path = current;
      if (path == null) {
        current = Path()..moveTo(offset.dx, offset.dy);
        firstX = offset.dx;
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
      lastX = offset.dx;
    }
    flush();
  }

  @override
  bool shouldRepaint(covariant HourlyMetricChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.bandColor != bandColor ||
        oldDelegate.thresholds != thresholds ||
        oldDelegate.valueBands != valueBands ||
        oldDelegate.plotRect != plotRect ||
        oldDelegate.yTicks != yTicks ||
        oldDelegate.yTickLabels != yTickLabels ||
        oldDelegate.xAxisLabels != xAxisLabels;
  }
}
