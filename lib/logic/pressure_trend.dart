/// Pressure trend classification for the Pressure detail screen (issue
/// #165), in the same small-pure-function-module style as
/// `lib/logic/swim_suitability.dart`.
library;

/// Direction a sea-level pressure reading is moving in, shown as the
/// Pressure detail screen's trend text.
enum PressureTrend { rising, steady, falling }

// The minimum pressure change (in hPa) over the comparison window that
// counts as a genuine trend rather than ordinary hour-to-hour noise. Sea
// -level pressure readings commonly wobble by a few tenths of an hPa
// between consecutive hours without anything meteorologically changing;
// meteorological practice treats roughly 1 hPa per 3 hours as the
// threshold for a "rapid" pressure change, so this picks the same 1 hPa
// figure as the cutoff between "steady" and a real rising/falling trend.
//
// The threshold is inclusive: a change of *exactly* +-1.0 hPa already
// counts as rising/falling. Only a change strictly smaller in magnitude
// than 1.0 hPa (e.g. +-0.9 hPa) is "steady" — see
// `classifyPressureTrend`'s tests for the exact boundary cases.
const double pressureTrendThresholdHpa = 1.0;

/// Classifies how pressure has moved from [earlierHpa] to [currentHpa].
///
/// Pure function: the same two numbers always return the same trend, with
/// no side effects and no dependency on the real clock. Returns `null`
/// when either reading is missing — "not enough data" is a distinct state
/// from "steady", so callers should show their own "no data" copy instead
/// of treating a `null` as steady.
PressureTrend? classifyPressureTrend({
  required double? currentHpa,
  required double? earlierHpa,
}) {
  if (currentHpa == null || earlierHpa == null) return null;
  final delta = currentHpa - earlierHpa;
  if (delta >= pressureTrendThresholdHpa) return PressureTrend.rising;
  if (delta <= -pressureTrendThresholdHpa) return PressureTrend.falling;
  return PressureTrend.steady;
}

/// A short capitalized label for [trend] (e.g. "Rising"), for the Pressure
/// detail screen's hero trend line.
String pressureTrendLabel(PressureTrend trend) {
  switch (trend) {
    case PressureTrend.rising:
      return 'Rising';
    case PressureTrend.steady:
      return 'Steady';
    case PressureTrend.falling:
      return 'Falling';
  }
}

/// A one-line explanation of what [trend] typically means for the
/// weather, shown under [pressureTrendLabel] on the Pressure detail
/// screen.
String pressureTrendExplanation(PressureTrend trend) {
  switch (trend) {
    case PressureTrend.rising:
      return 'usually a sign of clearing, calmer weather on the way.';
    case PressureTrend.steady:
      return 'conditions are settled, with no big change expected soon.';
    case PressureTrend.falling:
      return 'often signals clouds, wind or rain moving in.';
  }
}
