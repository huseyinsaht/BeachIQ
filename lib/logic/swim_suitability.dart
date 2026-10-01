/// Overall verdict returned by [scoreSwimSuitability], from best to worst.
/// [unknown] is reserved for when there isn't enough data to judge — it is
/// never reached by downgrading from [good].
enum SwimSuitabilityLevel { good, caution, poor, unknown }

/// A one-line swim verdict, for the "smart suggestion pill" on the home
/// screen (docs/design.md § "Screen: Home / location detail").
class SwimVerdict {
  const SwimVerdict(this.level, this.message);

  final SwimSuitabilityLevel level;

  /// A single short line, ready to show as-is (e.g. "Calm seas — good time
  /// for a swim.").
  final String message;
}

// Thresholds are deliberately conservative (biased toward caution) since a
// wrong "go for it" is worse than a wrong "be careful": open-water swimming
// guidance generally treats >1.2m wave height and >40km/h wind as conditions
// where casual swimmers should stay out, and >70% rain chance as likely to
// bring a storm/lightning risk rather than just a wet towel.
const _highWaveHeightM = 1.2;
const _moderateWaveHeightM = 0.6;
const _highWindSpeedKmh = 40.0;
const _moderateWindSpeedKmh = 20.0;
const _highRainChancePercent = 70;
const _moderateRainChancePercent = 40;

/// Scores swim suitability from wave height, wind speed and rain chance.
///
/// Pure function, no side effects. Each input is optional and independently
/// missing inputs are simply skipped rather than guessed at; when every
/// input is missing the result is [SwimSuitabilityLevel.unknown] rather
/// than a guessed calm/rough verdict. Otherwise the verdict is the worst
/// level triggered by any single available input.
SwimVerdict scoreSwimSuitability({
  double? waveHeightM,
  double? windSpeedKmh,
  int? rainChancePercent,
}) {
  if (waveHeightM == null && windSpeedKmh == null && rainChancePercent == null) {
    return const SwimVerdict(
      SwimSuitabilityLevel.unknown,
      'Not enough data to judge swim conditions right now.',
    );
  }

  var worst = SwimSuitabilityLevel.good;
  void consider(SwimSuitabilityLevel level) {
    if (level.index > worst.index) worst = level;
  }

  if (waveHeightM != null) {
    if (waveHeightM >= _highWaveHeightM) {
      consider(SwimSuitabilityLevel.poor);
    } else if (waveHeightM >= _moderateWaveHeightM) {
      consider(SwimSuitabilityLevel.caution);
    }
  }

  if (windSpeedKmh != null) {
    if (windSpeedKmh >= _highWindSpeedKmh) {
      consider(SwimSuitabilityLevel.poor);
    } else if (windSpeedKmh >= _moderateWindSpeedKmh) {
      consider(SwimSuitabilityLevel.caution);
    }
  }

  if (rainChancePercent != null) {
    if (rainChancePercent >= _highRainChancePercent) {
      consider(SwimSuitabilityLevel.poor);
    } else if (rainChancePercent >= _moderateRainChancePercent) {
      consider(SwimSuitabilityLevel.caution);
    }
  }

  return SwimVerdict(worst, _messageFor(worst));
}

String _messageFor(SwimSuitabilityLevel level) {
  switch (level) {
    case SwimSuitabilityLevel.good:
      return 'Calm seas — good time for a swim.';
    case SwimSuitabilityLevel.caution:
      return 'A bit choppy — swim with care.';
    case SwimSuitabilityLevel.poor:
      return 'Rough conditions — best to skip swimming today.';
    case SwimSuitabilityLevel.unknown:
      return 'Not enough data to judge swim conditions right now.';
  }
}
