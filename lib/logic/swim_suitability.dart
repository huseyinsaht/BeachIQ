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
//
// Public (not `_`-prefixed) so other pure logic — e.g.
// `lib/logic/forecast_alerts.dart`'s wind/wave/rain alert rules — can import
// and reuse these exact numbers instead of redefining them.
const highWaveHeightM = 1.2;
const moderateWaveHeightM = 0.6;
const highWindSpeedKmh = 40.0;
const moderateWindSpeedKmh = 20.0;
const highRainChancePercent = 70;
const moderateRainChancePercent = 40;

/// Air temperature (°C) below which an overcast sky downgrades the verdict
/// to [SwimSuitabilityLevel.caution]: grey and cool is not a pleasant swim,
/// while a warm overcast day is fine.
const overcastCoolAirTemperatureC = 22.0;

/// Scores swim suitability from wave height, wind speed, rain chance and the
/// current weather.
///
/// Pure function, no side effects. Each input is optional and independently
/// missing inputs are simply skipped rather than guessed at; when every
/// input is missing the result is [SwimSuitabilityLevel.unknown] rather
/// than a guessed calm/rough verdict. Otherwise the verdict is the worst
/// level triggered by any single available input, and its message names the
/// factor that set that level (the first one, when several tie).
///
/// "Good" additionally requires wave height: without it the sea state is
/// unknown, so calm wind and dry weather alone must not claim "calm seas".
/// A caution/poor verdict from wind, rain or weather still stands, but the
/// best a wave-less reading can return is [SwimSuitabilityLevel.unknown].
///
/// [weatherCode] is Open-Meteo's WMO code for the current conditions:
/// thunderstorms and snow/freezing rain are poor, rain/drizzle/showers and
/// fog are caution, and an overcast sky (code 3) is caution when
/// [airTemperatureC] is known and below [overcastCoolAirTemperatureC].
SwimVerdict scoreSwimSuitability({
  double? waveHeightM,
  double? windSpeedKmh,
  int? rainChancePercent,
  int? weatherCode,
  double? airTemperatureC,
}) {
  if (waveHeightM == null &&
      windSpeedKmh == null &&
      rainChancePercent == null &&
      weatherCode == null) {
    return SwimVerdict(
      SwimSuitabilityLevel.unknown,
      _messageFor(SwimSuitabilityLevel.unknown),
    );
  }

  var worst = SwimSuitabilityLevel.good;
  String? worstMessage;
  void consider(SwimSuitabilityLevel level, [String? message]) {
    if (level.index > worst.index) {
      worst = level;
      worstMessage = message;
    }
  }

  if (waveHeightM != null) {
    if (waveHeightM >= highWaveHeightM) {
      consider(SwimSuitabilityLevel.poor);
    } else if (waveHeightM >= moderateWaveHeightM) {
      consider(SwimSuitabilityLevel.caution);
    }
  }

  if (windSpeedKmh != null) {
    if (windSpeedKmh >= highWindSpeedKmh) {
      consider(SwimSuitabilityLevel.poor);
    } else if (windSpeedKmh >= moderateWindSpeedKmh) {
      consider(SwimSuitabilityLevel.caution);
    }
  }

  if (rainChancePercent != null) {
    if (rainChancePercent >= highRainChancePercent) {
      consider(SwimSuitabilityLevel.poor);
    } else if (rainChancePercent >= moderateRainChancePercent) {
      consider(SwimSuitabilityLevel.caution);
    }
  }

  if (weatherCode != null) {
    if (_thunderstormCodes.contains(weatherCode)) {
      consider(
        SwimSuitabilityLevel.poor,
        'Thunderstorms — stay out of the water.',
      );
    } else if (_snowOrFreezingCodes.contains(weatherCode)) {
      consider(SwimSuitabilityLevel.poor, 'Snow or freezing rain — stay out.');
    } else if (_rainCodes.contains(weatherCode)) {
      consider(
        SwimSuitabilityLevel.caution,
        'Rain right now — swim with care.',
      );
    } else if (_fogCodes.contains(weatherCode)) {
      consider(SwimSuitabilityLevel.caution, 'Foggy — swim with care.');
    } else if (weatherCode == 3 &&
        airTemperatureC != null &&
        airTemperatureC < overcastCoolAirTemperatureC) {
      consider(
        SwimSuitabilityLevel.caution,
        'Overcast and cool — less pleasant.',
      );
    }
  }

  if (waveHeightM == null && worst == SwimSuitabilityLevel.good) {
    return const SwimVerdict(
      SwimSuitabilityLevel.unknown,
      'No sea data — check local flags.',
    );
  }

  return SwimVerdict(worst, worstMessage ?? _messageFor(worst));
}

// WMO weather interpretation codes (Open-Meteo `weather_code`).
const _thunderstormCodes = {95, 96, 99};
const _snowOrFreezingCodes = {56, 57, 66, 67, 71, 73, 75, 77, 85, 86};
const _rainCodes = {51, 53, 55, 61, 63, 65, 80, 81, 82};
const _fogCodes = {45, 48};

String _messageFor(SwimSuitabilityLevel level) {
  switch (level) {
    case SwimSuitabilityLevel.good:
      return 'Calm seas — good time for a swim.';
    case SwimSuitabilityLevel.caution:
      return 'A bit choppy — swim with care.';
    case SwimSuitabilityLevel.poor:
      return 'Rough conditions — skip swimming.';
    case SwimSuitabilityLevel.unknown:
      return 'Not enough data to judge conditions.';
  }
}
