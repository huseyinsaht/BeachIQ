/// UV index band classification for the UV index detail screen (issue
/// #178), in the same small-pure-function-module style as
/// `lib/logic/pressure_trend.dart`.
library;

/// The standard UV index risk bands (WHO/EPA scale), used to color the UV
/// index detail screen's hourly chart and to pick a one-line protection
/// hint for "now".
enum UvBand { low, moderate, high, veryHigh, extreme }

// The band cutoffs, per the issue's documented ranges:
//   low        0  - 2
//   moderate   3  - 5
//   high       6  - 7
//   very high  8  - 10
//   extreme    11+
//
// Each cutoff below is the first value that belongs to the *next* band
// (e.g. 3.0 is already "moderate", not "low") - see `uvBandFor`'s tests for
// the exact boundary cases (2.9, 3.0, 5.9, 6.0, 7.9, 8.0, 10.9, 11.0).
const double _moderateCutoff = 3;
const double _highCutoff = 6;
const double _veryHighCutoff = 8;
const double _extremeCutoff = 11;

/// Classifies a UV index reading into its [UvBand].
///
/// Pure function: the same input always returns the same band, with no
/// side effects. Table-driven against the cutoffs above rather than a
/// metric-specific one-off, so the boundaries are easy to audit and test.
UvBand uvBandFor(double uvIndex) {
  if (uvIndex < _moderateCutoff) return UvBand.low;
  if (uvIndex < _highCutoff) return UvBand.moderate;
  if (uvIndex < _veryHighCutoff) return UvBand.high;
  if (uvIndex < _extremeCutoff) return UvBand.veryHigh;
  return UvBand.extreme;
}

/// A short capitalized label for [band] (e.g. "Very high"), for the UV
/// index detail screen's hero trend line.
String uvBandLabel(UvBand band) {
  switch (band) {
    case UvBand.low:
      return 'Low';
    case UvBand.moderate:
      return 'Moderate';
    case UvBand.high:
      return 'High';
    case UvBand.veryHigh:
      return 'Very high';
    case UvBand.extreme:
      return 'Extreme';
  }
}

/// A one-line sun-protection hint for [band], shown under the UV index
/// detail screen's hero value (after [uvBandLabel] and a dash, matching
/// `pressure_trend.dart`'s `pressureTrendLabel`/`pressureTrendExplanation`
/// pairing).
String uvProtectionHint(UvBand band) {
  switch (band) {
    case UvBand.low:
      return 'minimal protection needed — sunglasses on bright days are '
          'enough.';
    case UvBand.moderate:
      return 'wear sunscreen and sunglasses, and seek shade around midday.';
    case UvBand.high:
      return 'wear sunscreen, a hat and sunglasses, and limit midday sun.';
    case UvBand.veryHigh:
      return 'minimize sun exposure between 10am and 4pm; cover up and '
          'reapply sunscreen.';
    case UvBand.extreme:
      return 'avoid the sun between 10am and 4pm; seek shade and cover up '
          'fully.';
  }
}
