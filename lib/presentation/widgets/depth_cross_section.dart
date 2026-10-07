import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/depth_profile.dart';
import '../../logic/shallow_entry.dart';
import '../../logic/transect.dart';
import '../../logic/unit_preferences.dart';

/// A reference adult height (meters) the standing-person silhouettes are
/// scaled against (issue #256) -- a typical adult, never any individual
/// beachgoer's actual height.
const double referenceAdultHeightMeters = 1.7;

/// How many standing-person silhouettes [DepthCrossSection] draws at most,
/// placed only at real, measured (non-null-depth) sample distances --
/// never an invented position between or beyond them.
const int maxPersonSilhouettes = 3;

/// One standing-person silhouette's position on the cross-section, derived
/// only from a real [DepthSample] -- never an interpolated or invented
/// point.
class DepthCrossSectionPerson {
  const DepthCrossSectionPerson({
    required this.distanceMeters,
    required this.depthMeters,
  });

  /// Distance from shore (meters) of the real sample this figure stands
  /// at.
  final double distanceMeters;

  /// The real, measured depth (meters) at [distanceMeters].
  final double depthMeters;

  /// Whether the water here is deeper than [referenceAdultHeightMeters] --
  /// the reference adult would be completely submerged ("over your
  /// head").
  bool get isOverHead => depthMeters >= referenceAdultHeightMeters;
}

/// The three depth bands [DepthCrossSection] tints the water column with,
/// matching `shallow_entry_status.dart`'s own gentle/moderate/steep
/// colors so this screen never introduces a second palette for the same
/// idea.
class DepthCrossSectionBandColors {
  const DepthCrossSectionBandColors({
    required this.standUp,
    required this.gettingDeep,
    required this.overHead,
  });

  /// `<= shallowLimitMeters` -- "stand-up" water.
  final Color standUp;

  /// `shallowLimitMeters` to `deepLimitMeters` -- "getting deep".
  final Color gettingDeep;

  /// `>= deepLimitMeters` -- "over your head".
  final Color overHead;
}

/// The water-depth detail screen's side-view cross-section (issue #256):
/// water surface on top, the seabed drawn from [samples], the water
/// column tinted by the existing shallow/deep bands
/// (`lib/logic/shallow_entry.dart`), and a few standing-person
/// silhouettes (~[referenceAdultHeightMeters]) at real sample distances so
/// the depth reads at human scale without needing to read any numbers.
///
/// Honesty about data limits (issue #256, part 4): only real (non-null)
/// [samples] are ever used to place a point or a person silhouette --
/// never an invented position. The seabed line connecting them is drawn
/// **dashed** throughout, since even the segment between two measured
/// ~115 m grid points is an inferred approximation, not a surveyed
/// continuous reading -- a solid line would overstate the data's
/// precision. A `null` [DepthSample.depthMeters] (land/NoData) is a gap in
/// the line, exactly like [DepthProfileChart]'s own gap handling.
///
/// Implemented with [CustomPaint] (no charting package dependency). The
/// painter is exposed as [DepthCrossSectionPainter] so widget tests can
/// inspect the exact points/bands/person placements it was given, rather
/// than asserting on pixels -- mirroring `DepthProfileChart`'s own
/// `DepthProfileChartPainter`.
class DepthCrossSection extends StatelessWidget {
  const DepthCrossSection({
    super.key,
    required this.samples,
    this.unitSystem = UnitSystem.metric,
    this.height = 220,
    this.semanticLabel,
  });

  /// The transect's samples, ordered by [DepthSample.distanceMeters]
  /// ascending (as `DepthProfile.samples` already is). An empty list
  /// renders a "No data" placeholder instead of an empty graphic.
  final List<DepthSample> samples;

  /// The user's display-unit preference -- kept for parity with
  /// [DepthProfileChart] even though this graphic currently carries no
  /// on-canvas axis labels of its own (the distances are spelled out in
  /// the detail screen's text labels instead).
  final UnitSystem unitSystem;

  final double height;

  /// A short text description of what the graphic shows (e.g. the
  /// stand-up/deep-from distance labels), exposed to screen readers via
  /// [Semantics] -- so a person who cannot see the picture still gets the
  /// same information, not just "image" with no content. `null` omits the
  /// semantics wrapper (falls back to the default unlabeled render
  /// object), matching `DepthProfileChart`'s own lack of a dedicated
  /// semantic label today.
  final String? semanticLabel;

  static const _textSecondary = Color(0xFF8B93A6);
  static const _standUpColor = Color(0xFF2E7D32);
  static const _gettingDeepColor = Color(0xFFFFA726);
  static const _overHeadColor = Color(0xFFEF5350);
  static const _seabedColor = Color(0xFFD9C9A3);
  static const _personColor = Colors.white;
  static const _personSubmergedColor = Color(0x80FFFFFF);

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
    final yMax = math.max(maxSampleDepth, deepLimitMeters) * 1.2;

    final validSamples = [
      ...samples.where((sample) => sample.depthMeters != null),
    ]..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final personSamples = _pickPersonSamples(validSamples);

    final content = SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);
          // A margin reserved above the water-surface line so a person
          // standing in shallow water can visibly show their head/
          // shoulders above the surface, rather than clipping at the top
          // of the canvas.
          final aboveSurfaceMargin = math.min(
            size.height * 0.35,
            size.height * (referenceAdultHeightMeters / yMax),
          );
          final plotRect = Rect.fromLTWH(
            0,
            aboveSurfaceMargin,
            size.width,
            size.height - aboveSurfaceMargin,
          );

          final painter = DepthCrossSectionPainter(
            samples: samples,
            personSamples: personSamples,
            xMax: _xMax,
            yMax: yMax,
            plotRect: plotRect,
            bandColors: const DepthCrossSectionBandColors(
              standUp: _standUpColor,
              gettingDeep: _gettingDeepColor,
              overHead: _overHeadColor,
            ),
            seabedColor: _seabedColor,
            personColor: _personColor,
            personSubmergedColor: _personSubmergedColor,
          );
          return CustomPaint(size: size, painter: painter);
        },
      ),
    );

    final label = semanticLabel;
    if (label == null) return content;
    return Semantics(label: label, image: true, child: content);
  }

  /// Picks up to [maxPersonSilhouettes] samples from [validSamples],
  /// spread evenly across the measured range (always including the first
  /// and last) rather than clustering -- never a sample invented at a
  /// distance that was not actually measured.
  static List<DepthCrossSectionPerson> _pickPersonSamples(
    List<DepthSample> validSamples,
  ) {
    if (validSamples.isEmpty) return const [];
    final picks = <DepthSample>[];
    if (validSamples.length <= maxPersonSilhouettes) {
      picks.addAll(validSamples);
    } else {
      final step = (validSamples.length - 1) / (maxPersonSilhouettes - 1);
      final seenIndices = <int>{};
      for (var i = 0; i < maxPersonSilhouettes; i++) {
        final index = (i * step).round();
        if (seenIndices.add(index)) picks.add(validSamples[index]);
      }
    }
    return [
      for (final sample in picks)
        DepthCrossSectionPerson(
          distanceMeters: sample.distanceMeters,
          depthMeters: sample.depthMeters!,
        ),
    ];
  }
}

/// Paints [DepthCrossSection]'s side-view graphic: three horizontal water
/// bands (stand-up/getting-deep/over-head, from [bandColors]), a dashed
/// seabed line with solid dots at [samples]' real points (gaps at `null`
/// depths, exactly like `DepthProfileChartPainter`), and a simple
/// head-and-body silhouette for each [personSamples] entry.
///
/// Public (not private) so widget tests can find the [CustomPaint] in the
/// tree and inspect this painter's fields directly instead of asserting on
/// pixels.
class DepthCrossSectionPainter extends CustomPainter {
  const DepthCrossSectionPainter({
    required this.samples,
    required this.personSamples,
    required this.xMax,
    required this.yMax,
    required this.plotRect,
    required this.bandColors,
    required this.seabedColor,
    required this.personColor,
    required this.personSubmergedColor,
  });

  final List<DepthSample> samples;
  final List<DepthCrossSectionPerson> personSamples;
  final double xMax;
  final double yMax;
  final Rect plotRect;
  final DepthCrossSectionBandColors bandColors;
  final Color seabedColor;
  final Color personColor;
  final Color personSubmergedColor;

  double get _xRange => xMax.abs() < 1e-9 ? 1.0 : xMax;
  double get _yRange => yMax.abs() < 1e-9 ? 1.0 : yMax;

  double _xFor(double distanceMeters) =>
      plotRect.left + plotRect.width * (distanceMeters / _xRange);

  /// Depth grows downward, matching `DepthProfileChartPainter`'s own
  /// convention: a bigger depth maps to a bigger y.
  double _yFor(double depthMeters) =>
      plotRect.top + plotRect.height * (depthMeters / _yRange);

  Offset? _seabedOffsetFor(int index) {
    final sample = samples[index];
    final depth = sample.depthMeters;
    if (depth == null) return null;
    return Offset(_xFor(sample.distanceMeters), _yFor(depth));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintBands(canvas, size);
    if (samples.isEmpty) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    _paintDashedSeabed(canvas);
    _paintSampleDots(canvas);
    canvas.restore();

    for (final person in personSamples) {
      _paintPerson(canvas, person);
    }
  }

  void _paintBands(Canvas canvas, Size size) {
    final shallowY = _yFor(shallowLimitMeters).clamp(0.0, size.height);
    final deepY = _yFor(deepLimitMeters).clamp(0.0, size.height);
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = bandColors.standUp;
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, shallowY), paint);

    paint.color = bandColors.gettingDeep;
    canvas.drawRect(Rect.fromLTRB(0, shallowY, size.width, deepY), paint);

    paint.color = bandColors.overHead;
    canvas.drawRect(Rect.fromLTRB(0, deepY, size.width, size.height), paint);
  }

  void _paintDashedSeabed(Canvas canvas) {
    final paint = Paint()
      ..color = seabedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const dashLength = 6.0;
    const gapLength = 4.0;

    Offset? previous;
    for (var i = 0; i < samples.length; i++) {
      final current = _seabedOffsetFor(i);
      if (current == null) {
        previous = null;
        continue;
      }
      if (previous != null) {
        _drawDashedLine(
          canvas,
          paint,
          previous,
          current,
          dashLength,
          gapLength,
        );
      }
      previous = current;
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    double dashLength,
    double gapLength,
  ) {
    final totalLength = (end - start).distance;
    if (totalLength <= 0) return;
    final direction = (end - start) / totalLength;
    var distanceCovered = 0.0;
    var drawing = true;
    while (distanceCovered < totalLength) {
      final segmentLength = math.min(
        drawing ? dashLength : gapLength,
        totalLength - distanceCovered,
      );
      final segmentStart = start + direction * distanceCovered;
      final segmentEnd = start + direction * (distanceCovered + segmentLength);
      if (drawing) canvas.drawLine(segmentStart, segmentEnd, paint);
      distanceCovered += segmentLength;
      drawing = !drawing;
    }
  }

  void _paintSampleDots(Canvas canvas) {
    final paint = Paint()
      ..color = seabedColor
      ..style = PaintingStyle.fill;
    for (var i = 0; i < samples.length; i++) {
      final offset = _seabedOffsetFor(i);
      if (offset == null) continue;
      canvas.drawCircle(offset, 3.5, paint);
    }
  }

  void _paintPerson(Canvas canvas, DepthCrossSectionPerson person) {
    final x = _xFor(person.distanceMeters);
    final feetY = _yFor(person.depthMeters);
    final personHeightPixels =
        plotRect.height * (referenceAdultHeightMeters / _yRange);
    final headY = feetY - personHeightPixels;
    final color = person.isOverHead ? personSubmergedColor : personColor;

    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Head: a small circle at the top.
    final headRadius = math.max(2.0, personHeightPixels * 0.12);
    final headCenter = Offset(x, headY + headRadius);
    canvas.drawCircle(headCenter, headRadius, bodyPaint);

    // Body: a rounded rect from just under the head down to the feet.
    final bodyTop = headY + headRadius * 2;
    if (bodyTop < feetY) {
      final bodyWidth = math.max(3.0, personHeightPixels * 0.22);
      final bodyRect = Rect.fromLTRB(
        x - bodyWidth / 2,
        bodyTop,
        x + bodyWidth / 2,
        feetY,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyWidth / 2)),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DepthCrossSectionPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.personSamples != personSamples ||
        oldDelegate.xMax != xMax ||
        oldDelegate.yMax != yMax ||
        oldDelegate.plotRect != plotRect ||
        oldDelegate.bandColors != bandColors;
  }
}
