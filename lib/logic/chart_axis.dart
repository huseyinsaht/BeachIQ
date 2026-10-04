import 'dart:math' as math;

/// Generates "nice" axis tick values for the inclusive range `[min, max]`,
/// aiming for roughly [targetCount] ticks (D3's `ticks()` algorithm: pick a
/// round step size — 1, 2 or 5 times a power of ten — then enumerate every
/// multiple of that step that falls inside the range).
///
/// A pure function: the same inputs always produce the same output, with no
/// side effects and no dependency on anything outside its arguments, so
/// [HourlyMetricChart] can call it once per build/paint and reuse the exact
/// same list for the grid lines and their labels — the chart's line is
/// already drawn against `[min, max]`, so ticks computed from that same
/// pair of numbers can never show a value the line's own scale disagrees
/// with.
///
/// Edge cases, all handled without throwing or returning NaN/Infinity:
/// - `min > max`: the two are swapped first, so the function is tolerant of
///   either order.
/// - `min == max` (a flat series): there is no real "range" to divide into
///   ticks, so the domain is widened around that single value first — by
///   10% of its magnitude, or by exactly 1 when the value is 0 (where 10%
///   would widen by nothing) — before generating ticks, the same way
///   [HourlyMetricChart] already widens a flat line's own `[min, max]` so
///   the line and its ticks never collapse onto the same pixel row.
/// - A tiny range (e.g. `0.001`): the step size is chosen on a log10 scale,
///   so it shrinks (and ticks keep fractional digits) right along with the
///   range instead of rounding everything down to the same value.
/// - A huge range (e.g. `1e9`): the same log10 step selection scales up,
///   picking a step like `5e8` rather than iterating a step of `1`.
/// - `targetCount <= 0`: treated as `1`.
///
/// The returned list is sorted ascending, contains no duplicates, and every
/// value lies within the (possibly widened) `[min, max]` actually used —
/// never outside it, so a caller drawing a grid line at each tick never has
/// to clip against the visible range itself.
List<double> niceTicks(double min, double max, int targetCount) {
  var lo = min;
  var hi = max;
  if (lo > hi) {
    final swap = lo;
    lo = hi;
    hi = swap;
  }

  if (lo == hi) {
    final pad = lo == 0 ? 1.0 : lo.abs() * 0.1;
    lo -= pad;
    hi += pad;
  }

  final count = targetCount <= 0 ? 1 : targetCount;
  final range = hi - lo;
  final step = _niceStep(range / count);

  final firstTick = (lo / step).ceil() * step;
  final ticks = <double>[];
  // `+2` guards against the loop running short by one tick on the upper
  // bound purely from floating-point rounding of `firstTick`/`step`; the
  // `value > hi` check (with a small tolerance) is what actually stops it.
  final maxIterations = ((hi - firstTick) / step).round() + 2;
  for (var i = 0; i <= maxIterations; i++) {
    final value = _cleanFloat(firstTick + i * step);
    if (value > hi + step * 1e-9) break;
    if (value < lo - step * 1e-9) continue;
    ticks.add(value);
  }
  return ticks;
}

/// Geometric-mean thresholds between consecutive "nice" multipliers
/// (1, 2, 5, 10): `sqrt(1*2)`, `sqrt(2*5)`, `sqrt(5*10)`. Picking the
/// multiplier by comparing to these (rather than to the multipliers
/// themselves) chooses whichever of 1/2/5/10 [rawStep] is closest to on a
/// log scale, the same tie-break D3's `tickStep` uses — e.g. a raw step of
/// `2.25` lands closer to `2` than to `5`, so it should round to `2`, not
/// overshoot to `5`.
const double _e2 = 1.4142135623730951; // sqrt(2)
const double _e5 = 3.1622776601683795; // sqrt(10)
const double _e10 = 7.0710678118654755; // sqrt(50)

/// Rounds [rawStep] to the nearest "nice" step: 1, 2, 5 or 10 times a power
/// of ten (e.g. `0.02`, `5`, `200`), the same small set of round numbers
/// D3 and most other charting libraries pick axis steps from.
double _niceStep(double rawStep) {
  if (rawStep <= 0 || rawStep.isNaN || rawStep.isInfinite) return 1.0;

  final exponent = (math.log(rawStep) / math.ln10).floor();
  var step = math.pow(10, exponent).toDouble();
  final error = rawStep / step;

  if (error >= _e10) {
    step *= 10;
  } else if (error >= _e5) {
    step *= 5;
  } else if (error >= _e2) {
    step *= 2;
  }
  return step;
}

/// Strips float noise (e.g. `1010.0000000000002`) from a computed tick
/// value by round-tripping it through a fixed number of significant
/// digits — enough precision for any realistic chart range (from tiny
/// fractional ranges to huge ones) while discarding binary-float error.
double _cleanFloat(double value) {
  if (value == 0) return 0.0;
  return double.parse(value.toStringAsPrecision(12));
}
