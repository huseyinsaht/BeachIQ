import 'package:flutter/material.dart';

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

/// A reusable hourly line/area chart for the metric detail screens (shared
/// foundation for issue #165 and the metric-specific PRs that follow it):
/// a "Now" marker at [nowIndex], optional threshold lines, and an optional
/// colored area band under the line. `null` hours in [points] are gaps —
/// the line breaks there instead of dipping to zero.
///
/// Implemented with [CustomPaint] (no charting package dependency). The
/// painter is exposed as [HourlyMetricChartPainter] so widget tests can
/// inspect the exact points it was given, rather than asserting on pixels.
class HourlyMetricChart extends StatelessWidget {
  const HourlyMetricChart({
    super.key,
    required this.points,
    this.nowIndex,
    this.thresholds = const [],
    this.lineColor = Colors.white,
    this.bandColor,
    this.height = 160,
  });

  /// The hourly series to plot, left to right in order (oldest first).
  final List<HourlyChartPoint> points;

  /// Index into [points] that represents "now" (typically 0, matching the
  /// Home screen's hourly row convention of starting with "Now"). Null
  /// hides the marker entirely; an out-of-range index or a null value at
  /// that index also hides it rather than throwing.
  final int? nowIndex;

  final List<HourlyChartThreshold> thresholds;
  final Color lineColor;

  /// Fills the area between the line and the chart's bottom edge when set.
  /// Null (the default) draws the line only.
  final Color? bandColor;

  final double height;

  static const _textSecondary = Color(0xFF8B93A6);

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

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);
          final painter = HourlyMetricChartPainter(
            points: points,
            minValue: minValue,
            maxValue: maxValue,
            lineColor: lineColor,
            bandColor: bandColor,
            thresholds: thresholds,
          );
          final marker = _nowMarkerPosition(size, minValue, maxValue);
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
  Offset? _nowMarkerPosition(Size size, double minValue, double maxValue) {
    final index = nowIndex;
    if (index == null || index < 0 || index >= points.length) return null;
    final value = points[index].value;
    if (value == null) return null;
    final x = points.length <= 1
        ? 0.0
        : size.width * index / (points.length - 1);
    final range = maxValue - minValue;
    final y = size.height * (1 - (value - minValue) / range);
    return Offset(x, y);
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
/// values, plus any [thresholds] as horizontal reference lines.
///
/// Public (not private) so widget tests can find the [CustomPaint] in the
/// tree and inspect this painter's fields directly — e.g. asserting that a
/// `null` hour is still present in [points] with its `value` unchanged
/// (never rewritten to `0`) rather than trying to assert on rendered
/// pixels.
class HourlyMetricChartPainter extends CustomPainter {
  const HourlyMetricChartPainter({
    required this.points,
    required this.minValue,
    required this.maxValue,
    required this.lineColor,
    required this.bandColor,
    required this.thresholds,
  });

  final List<HourlyChartPoint> points;
  final double minValue;
  final double maxValue;
  final Color lineColor;
  final Color? bandColor;
  final List<HourlyChartThreshold> thresholds;

  double get _range {
    final range = maxValue - minValue;
    return range.abs() < 1e-9 ? 1.0 : range;
  }

  Offset? _offsetFor(int index, Size size) {
    final value = points[index].value;
    if (value == null) return null;
    final x = points.length <= 1
        ? 0.0
        : size.width * index / (points.length - 1);
    final y = size.height * (1 - (value - minValue) / _range);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final thresholdPaint = Paint()..strokeWidth = 1;
    for (final threshold in thresholds) {
      final y = size.height * (1 - (threshold.value - minValue) / _range);
      thresholdPaint.color = threshold.color;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), thresholdPaint);
    }

    if (bandColor != null) {
      _paintBand(canvas, size, bandColor!);
    }
    _paintLine(canvas, size);
  }

  /// Draws the data line as one or more disconnected [Path]s, starting a
  /// fresh path after every `null` value so a gap is a real visual break
  /// instead of a straight segment through a fabricated zero.
  void _paintLine(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path? current;
    for (var i = 0; i < points.length; i++) {
      final offset = _offsetFor(i, size);
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

  void _paintBand(Canvas canvas, Size size, Color color) {
    final bandPaint = Paint()..color = color;
    Path? current;
    double? firstX;
    double? lastX;

    void flush() {
      final path = current;
      final left = firstX;
      final right = lastX;
      if (path != null && left != null && right != null) {
        path.lineTo(right, size.height);
        path.lineTo(left, size.height);
        path.close();
        canvas.drawPath(path, bandPaint);
      }
      current = null;
      firstX = null;
      lastX = null;
    }

    for (var i = 0; i < points.length; i++) {
      final offset = _offsetFor(i, size);
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
        oldDelegate.thresholds != thresholds;
  }
}
