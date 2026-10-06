import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/depth_profile.dart';
import '../../logic/chart_axis.dart';
import '../../logic/shallow_entry.dart';
import '../../logic/transect.dart';
import '../../logic/unit_preferences.dart';

/// The water-depth detail screen's distance-vs-depth profile chart (issue
/// #217): x = distance from shore (0 to
/// `defaultTransectDistancesMeters.last`, 400 m by default), y = depth —
/// drawn increasing *downward* (a deeper reading sits lower on the chart,
/// the opposite of `HourlyMetricChart`'s "bigger is higher" convention,
/// matching how a cross-section of the seabed actually looks), with
/// horizontal reference lines at [shallowLimitMeters] and
/// [deepLimitMeters] (`lib/logic/shallow_entry.dart`).
///
/// A `null` [DepthSample.depthMeters] (land/NoData) is a gap in the line,
/// never plotted as a fabricated `0`, exactly like `HourlyMetricChart`.
/// Axis ticks come from `lib/logic/chart_axis.dart`'s [niceTicks] — the
/// same tick-generation this app already uses for every other chart —
/// and are labelled with the active [unitSystem] (m/ft).
///
/// Implemented with [CustomPaint] (no charting package dependency),
/// mirroring `HourlyMetricChart`. The painter is exposed as
/// [DepthProfileChartPainter] so widget tests can inspect the exact
/// points/ticks/thresholds it was given, rather than asserting on pixels.
class DepthProfileChart extends StatelessWidget {
  const DepthProfileChart({
    super.key,
    required this.samples,
    this.unitSystem = UnitSystem.metric,
    this.lineColor = Colors.white,
    this.height = 200,
  });

  /// The transect's samples, ordered by [DepthSample.distanceMeters]
  /// ascending (as `DepthProfile.samples` already is). An empty list
  /// renders a "No data" placeholder instead of an empty chart, matching
  /// `HourlyMetricChart`'s own empty-series behavior.
  final List<DepthSample> samples;

  /// The user's display-unit preference (m or ft), applied to every axis
  /// label.
  final UnitSystem unitSystem;

  final Color lineColor;
  final double height;

  static const _textSecondary = Color(0xFF8B93A6);
  static const _axisLabelStyle = TextStyle(color: _textSecondary, fontSize: 10);
  static const _shallowThresholdColor = Color(0xFFFFA726);
  static const _deepThresholdColor = Color(0xFFEF5350);

  /// At least 3 ticks (matching `HourlyMetricChart`'s own target), same
  /// "nice round numbers" sweet spot [niceTicks] aims for.
  static const int _targetTicks = 4;

  /// The transect's fixed domain: 0 to its last configured distance (400 m
  /// by default) — a constant property of the transect itself, not
  /// derived from however many samples happened to come back usable, so
  /// the x-axis never rescales just because some points are missing.
  double get _xMax => defaultTransectDistancesMeters.last;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
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

    final presentDepths = samples
        .map((sample) => sample.depthMeters)
        .whereType<double>()
        .toList();
    final maxSampleDepth = presentDepths.isEmpty
        ? 0.0
        : presentDepths.reduce(math.max);
    // Always wide enough to comfortably show the deep-limit threshold line,
    // even when every real reading stays shallower than it.
    final yMax = math.max(maxSampleDepth, deepLimitMeters) * 1.2;

    final rawXTicks = niceTicks(0, _xMax, _targetTicks);
    final xTickLabels = [
      for (final tick in rawXTicks) formatDistanceMeters(tick, unitSystem),
    ];
    final rawYTicks = niceTicks(0, yMax, _targetTicks);
    final yTickLabels = [
      for (final tick in rawYTicks) formatDepthMeters(tick, unitSystem),
    ];

    final textScaler = MediaQuery.textScalerOf(context);
    final gutterWidth =
        _maxTextWidth(yTickLabels, _axisLabelStyle, textScaler) + 8;
    final bottomAxisHeight =
        _maxTextHeight(xTickLabels, _axisLabelStyle, textScaler) + 6;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);
          final clampedGutter = gutterWidth.clamp(0.0, size.width * 0.4);
          final clampedBottom = bottomAxisHeight.clamp(0.0, size.height * 0.4);
          final plotRect = Rect.fromLTWH(
            clampedGutter,
            0,
            (size.width - clampedGutter).clamp(0.0, size.width),
            (size.height - clampedBottom).clamp(0.0, size.height),
          );

          final painter = DepthProfileChartPainter(
            samples: samples,
            xMax: _xMax,
            yMax: yMax,
            lineColor: lineColor,
            thresholds: const [
              DepthChartThreshold(
                valueMeters: shallowLimitMeters,
                color: _shallowThresholdColor,
                label: 'Shallow limit',
              ),
              DepthChartThreshold(
                valueMeters: deepLimitMeters,
                color: _deepThresholdColor,
                label: 'Deep limit',
              ),
            ],
            plotRect: plotRect,
            xTicks: rawXTicks,
            xTickLabels: xTickLabels,
            yTicks: rawYTicks,
            yTickLabels: yTickLabels,
            axisLabelStyle: _axisLabelStyle,
            textScaler: textScaler,
          );
          return CustomPaint(size: size, painter: painter);
        },
      ),
    );
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

  static double _maxTextHeight(
    List<String> texts,
    TextStyle style,
    TextScaler textScaler,
  ) {
    var max = 0.0;
    for (final text in texts) {
      final height = _measure(text, style, textScaler).height;
      if (height > max) max = height;
    }
    return max;
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

/// A horizontal reference line on [DepthProfileChart] at a fixed depth
/// (e.g. [shallowLimitMeters]), with an optional [label] — kept on the
/// model for test introspection (and future use), matching
/// `HourlyMetricChart`'s own `HourlyChartThreshold.label`, which the chart
/// painter itself also does not render as on-canvas text.
class DepthChartThreshold {
  const DepthChartThreshold({
    required this.valueMeters,
    required this.color,
    this.label,
  });

  final double valueMeters;
  final Color color;
  final String? label;
}

/// Paints [samples] as a line with gaps at `null` depths, the two
/// [thresholds] as horizontal reference lines, and the distance/depth
/// axis ticks from [xTicks]/[yTicks] — depth increasing *downward* (see
/// [DepthProfileChart]'s own doc comment).
///
/// Public (not private) so widget tests can find the [CustomPaint] in the
/// tree and inspect this painter's fields directly instead of asserting
/// on rendered pixels.
class DepthProfileChartPainter extends CustomPainter {
  const DepthProfileChartPainter({
    required this.samples,
    required this.xMax,
    required this.yMax,
    required this.lineColor,
    required this.thresholds,
    required this.plotRect,
    this.xTicks = const [],
    this.xTickLabels = const [],
    this.yTicks = const [],
    this.yTickLabels = const [],
    this.axisLabelStyle = const TextStyle(
      color: Color(0xFF8B93A6),
      fontSize: 10,
    ),
    this.textScaler = TextScaler.noScaling,
  });

  final List<DepthSample> samples;
  final double xMax;
  final double yMax;
  final Color lineColor;
  final List<DepthChartThreshold> thresholds;
  final Rect plotRect;
  final List<double> xTicks;
  final List<String> xTickLabels;
  final List<double> yTicks;
  final List<String> yTickLabels;
  final TextStyle axisLabelStyle;
  final TextScaler textScaler;

  static final Paint _gridLinePaint = Paint()
    ..color = const Color(0x1FFFFFFF)
    ..strokeWidth = 1;

  double get _xRange => xMax.abs() < 1e-9 ? 1.0 : xMax;
  double get _yRange => yMax.abs() < 1e-9 ? 1.0 : yMax;

  Offset? _offsetFor(int index) {
    final sample = samples[index];
    final depth = sample.depthMeters;
    if (depth == null) return null;
    final x =
        plotRect.left + plotRect.width * (sample.distanceMeters / _xRange);
    // Depth grows downward: a bigger depth maps to a bigger y (further
    // from the plot's top edge), the opposite of a normal "bigger is
    // higher" chart.
    final y = plotRect.top + plotRect.height * (depth / _yRange);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    canvas.save();
    canvas.clipRect(plotRect);

    _paintYGridLines(canvas);

    final thresholdPaint = Paint()..strokeWidth = 1;
    for (final threshold in thresholds) {
      final y =
          plotRect.top + plotRect.height * (threshold.valueMeters / _yRange);
      thresholdPaint.color = threshold.color;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        thresholdPaint,
      );
    }

    _paintLine(canvas);

    canvas.restore();

    _paintYAxisLabels(canvas);
    _paintXAxisLabels(canvas, size);
  }

  void _paintYGridLines(Canvas canvas) {
    for (final tick in yTicks) {
      final y = plotRect.top + plotRect.height * (tick / _yRange);
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        _gridLinePaint,
      );
    }
  }

  void _paintYAxisLabels(Canvas canvas) {
    for (var i = 0; i < yTicks.length && i < yTickLabels.length; i++) {
      final y = plotRect.top + plotRect.height * (yTicks[i] / _yRange);
      final painter = TextPainter(
        text: TextSpan(text: yTickLabels[i], style: axisLabelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: plotRect.left);
      final dy = (y - painter.height / 2).clamp(0.0, double.infinity);
      painter.paint(canvas, Offset(plotRect.left - 6 - painter.width, dy));
    }
  }

  void _paintXAxisLabels(Canvas canvas, Size size) {
    for (var i = 0; i < xTicks.length && i < xTickLabels.length; i++) {
      final x = plotRect.left + plotRect.width * (xTicks[i] / _xRange);
      final painter = TextPainter(
        text: TextSpan(text: xTickLabels[i], style: axisLabelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final maxDx = (size.width - painter.width) < 0
          ? 0.0
          : size.width - painter.width;
      final dx = (x - painter.width / 2).clamp(0.0, maxDx);
      painter.paint(canvas, Offset(dx, plotRect.bottom + 4));
    }
  }

  void _paintLine(Canvas canvas) {
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path? current;
    for (var i = 0; i < samples.length; i++) {
      final offset = _offsetFor(i);
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

  @override
  bool shouldRepaint(covariant DepthProfileChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.xMax != xMax ||
        oldDelegate.yMax != yMax ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.thresholds != thresholds ||
        oldDelegate.plotRect != plotRect ||
        oldDelegate.xTicks != xTicks ||
        oldDelegate.yTicks != yTicks;
  }
}
