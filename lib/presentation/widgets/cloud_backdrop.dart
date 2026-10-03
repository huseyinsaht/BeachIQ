import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One blurred ellipse cluster making up [CloudBackdrop]'s texture: a
/// center (in fractions of the backdrop's own size, 0-1 on each axis, so
/// the cluster scales with whatever box it's given rather than using fixed
/// pixel offsets), a radius (also a fraction of the backdrop's shortest
/// side) and an opacity.
@immutable
class _CloudPuff {
  const _CloudPuff({
    required this.centerFraction,
    required this.radiusFraction,
    required this.opacity,
  });

  final Offset centerFraction;
  final double radiusFraction;
  final double opacity;
}

/// Fixed, hand-picked puff layout for the faint cloud texture described in
/// docs/design.md (a decorative texture behind the header, top-right on
/// Home). Deterministic by construction — no `Random()`, no animation — so
/// [CloudBackdropPainter] always paints the exact same pixels for a given
/// size and widget tests can assert on it reliably (see
/// `test/presentation/widgets/cloud_backdrop_test.dart`).
///
/// Clustered toward the top-right (small/negative x, small y) with a couple
/// of softer, larger puffs reaching further down/left so the texture reads
/// as one diffuse shape rather than a row of discs, matching the mockup's
/// single soft cloud mass rather than distinct blobs.
const _puffs = [
  _CloudPuff(
    centerFraction: Offset(0.80, 0.18),
    radiusFraction: 0.55,
    opacity: 1,
  ),
  _CloudPuff(
    centerFraction: Offset(1.05, 0.05),
    radiusFraction: 0.42,
    opacity: 0.8,
  ),
  _CloudPuff(
    centerFraction: Offset(0.55, 0.0),
    radiusFraction: 0.32,
    opacity: 0.65,
  ),
  _CloudPuff(
    centerFraction: Offset(0.90, 0.45),
    radiusFraction: 0.30,
    opacity: 0.5,
  ),
];

/// Paints [_puffs] as heavily blurred white ellipses scaled by [size], each
/// at [CloudBackdrop.opacity] times its own relative opacity. Pure function
/// of (size, opacity) — no external state — so it always produces the same
/// pixels for the same inputs ([shouldRepaint] reflects exactly that).
class CloudBackdropPainter extends CustomPainter {
  const CloudBackdropPainter({required this.opacity});

  /// The backdrop's overall opacity (see [CloudBackdrop.opacity]); each
  /// puff is additionally scaled by its own relative [_CloudPuff.opacity]
  /// so the cluster reads as one uneven, soft shape rather than flat discs.
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || size.isEmpty) return;
    final shortestSide = size.shortestSide;
    final paint = Paint()
      ..color = Colors.white
      ..maskFilter = MaskFilter.blur(ui.BlurStyle.normal, shortestSide * 0.25);
    for (final puff in _puffs) {
      final center = Offset(
        puff.centerFraction.dx * size.width,
        puff.centerFraction.dy * size.height,
      );
      final radius = puff.radiusFraction * shortestSide;
      paint.color = Colors.white.withValues(alpha: opacity * puff.opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CloudBackdropPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

/// A faint, procedurally-painted cloud texture behind the Home screen's
/// header (docs/design.md: "a decorative photographic cloud texture in the
/// top-right behind the status bar/header" — "until supplied, use a
/// procedural backdrop instead"). No image asset and no new dependency: a
/// few large, heavily blurred, low-opacity white ellipses painted with
/// [CustomPainter].
///
/// Sits behind the screen's real content in a [Stack], sized to [width] x
/// [height] and positioned by the caller (top-right on Home). Wrapped in:
/// - [IgnorePointer] — purely decorative, must never intercept taps meant
///   for whatever is stacked on top of it (acceptance criterion).
/// - [RepaintBoundary] — isolates its (static) paint from the rest of the
///   scrolling content, so scrolling the screen never asks this to repaint.
///
/// Deterministic (see [CloudBackdropPainter]/`_puffs`): no randomness, no
/// animation, so a widget test gets the exact same output every run.
class CloudBackdrop extends StatelessWidget {
  const CloudBackdrop({
    super.key,
    this.width = 260,
    this.height = 200,
    this.opacity = 0.12,
  }) : assert(
         opacity >= 0.08 && opacity <= 0.15,
         'Per docs/design.md this must stay faint (0.08-0.15) so it never '
         'reduces text contrast over the header.',
       );

  /// The backdrop's painted width, in logical pixels.
  final double width;

  /// The backdrop's painted height, in logical pixels.
  final double height;

  /// Overall opacity of the cloud texture (0.08-0.15 per docs/design.md),
  /// deliberately kept low enough to never reduce contrast for the white
  /// header text painted on top of it.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(painter: CloudBackdropPainter(opacity: opacity)),
        ),
      ),
    );
  }
}
