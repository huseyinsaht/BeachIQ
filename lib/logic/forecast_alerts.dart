import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/models/weather_condition.dart';

import 'swim_suitability.dart';

/// What a [ForecastAlert] is about.
enum ForecastAlertType { wind, waves, clouds, rain }

/// How urgent a [ForecastAlert] is.
///
/// [moderate] covers a fast rise or crossing the first (cautionary)
/// threshold; [high] covers crossing the second, more severe threshold —
/// the same two-tier shape [scoreSwimSuitability] uses for
/// [SwimSuitabilityLevel.caution]/[SwimSuitabilityLevel.poor].
enum ForecastAlertSeverity { moderate, high }

/// A single heads-up window produced by [buildForecastAlerts], e.g. "Wind
/// picks up between 10:00 and 11:00." or "Clouds moving in around 14:00,
/// sky will close in by 16:00.".
class ForecastAlert {
  const ForecastAlert({
    required this.type,
    required this.start,
    required this.end,
    required this.severity,
    required this.message,
  });

  /// What kind of alert this is.
  final ForecastAlertType type;

  /// When the underlying trend/crossing starts (the reading right before
  /// the rule first fired in this window).
  final DateTime start;

  /// When the underlying trend/crossing was last observed to still hold in
  /// this window (the last contiguous hour the rule fired for).
  final DateTime end;

  final ForecastAlertSeverity severity;

  /// A single ready-to-show line. Plain English today; a future
  /// localization pass can wrap/replace this without touching the rules
  /// above, since the rule evaluation and the wording are kept separate
  /// here.
  final String message;
}

// --- Rule constants -------------------------------------------------------
//
// Threshold *crossing* values (the "or crossing the X/Y threshold" half of
// the wind/waves/rain rules) are deliberately NOT redefined here: they are
// imported from `swim_suitability.dart` (`moderateWindSpeedKmh`,
// `highWindSpeedKmh`, `moderateWaveHeightM`, `highWaveHeightM`,
// `moderateRainChancePercent`, `highRainChancePercent`) so this file and the
// swim-suitability scoring never disagree about what "windy" or "rough"
// means.
//
// The *rise* thresholds below are new to this rule set (there is no
// equivalent in `swim_suitability.dart`, which only ever looks at a single
// snapshot, never a trend) and so are defined once, here.

/// Wind rise rule: alert when wind speed climbs by at least this much from
/// one hourly reading to the next.
const windRiseThresholdKmh = 10.0;

/// Wave rise rule: alert when wave height climbs by at least this much from
/// one hourly reading to the next.
const waveRiseThresholdM = 0.3;

// --- Public API -------------------------------------------------------------

/// Builds human-readable forecast heads-ups from hourly weather and sea
/// data: wind picking up, waves rising, clouds moving in, or rain chance
/// climbing.
///
/// Pure function: no I/O, no global clock — [now] defaults to
/// `DateTime.now()` but passing it explicitly (as every test here does)
/// makes the result fully deterministic.
///
/// Only hours strictly after [now] can start/extend an alert window; a
/// transition that already happened before [now] is not reported. An hour
/// with a `null` value for the field a rule cares about is skipped for that
/// rule rather than treated as `0`/`false` — see each private `_evaluate*`
/// function below.
///
/// Adjacent hours that trigger the same rule are merged into a single
/// window (e.g. a rise spanning hours 10, 11 and 12 is one alert, not
/// three) rather than emitted one per hour.
///
/// Resolution note: this only ever looks at the hourly series ([weather]
/// and [sea] are both hourly-resolution). Open-Meteo also offers a
/// `minutely_15` forecast for some variables, which could give tighter
/// alert windows (e.g. "between 10:15 and 10:45") in a future revision —
/// not implemented here, hourly is the baseline.
List<ForecastAlert> buildForecastAlerts({
  required List<WeatherHourly> weather,
  required List<SeaHourly> sea,
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();

  final alerts = <ForecastAlert>[
    ..._collectAlerts<WeatherHourly>(
      hourly: weather,
      timeOf: (h) => h.time,
      type: ForecastAlertType.wind,
      now: effectiveNow,
      evaluate: (prev, curr) => _evaluateWind(prev.windSpeed, curr.windSpeed),
    ),
    ..._collectAlerts<WeatherHourly>(
      hourly: weather,
      timeOf: (h) => h.time,
      type: ForecastAlertType.clouds,
      now: effectiveNow,
      evaluate: (prev, curr) =>
          _evaluateClouds(prev.weatherCode, curr.weatherCode),
    ),
    ..._collectAlerts<WeatherHourly>(
      hourly: weather,
      timeOf: (h) => h.time,
      type: ForecastAlertType.rain,
      now: effectiveNow,
      evaluate: (prev, curr) =>
          _evaluateRain(prev.rainChancePercent, curr.rainChancePercent),
    ),
    ..._collectAlerts<SeaHourly>(
      hourly: sea,
      timeOf: (h) => h.time,
      type: ForecastAlertType.waves,
      now: effectiveNow,
      evaluate: (prev, curr) =>
          _evaluateWaves(prev.waveHeight, curr.waveHeight),
    ),
  ];

  alerts.sort((a, b) => a.start.compareTo(b.start));
  return alerts;
}

// --- Rule evaluation --------------------------------------------------------
//
// Why a trigger fired, so the message can be worded precisely. Kept
// separate from [ForecastAlertSeverity] since e.g. both a rise and a
// moderate-threshold crossing are [ForecastAlertSeverity.moderate] but read
// differently.
enum _Reason {
  windRise,
  windCrossModerate,
  windCrossHigh,
  waveRise,
  waveCrossModerate,
  waveCrossHigh,
  cloudsClosingIn,
  rainCrossModerate,
  rainCrossHigh,
}

typedef _Trigger = ({ForecastAlertSeverity severity, _Reason reason});

/// Wind rule: a rise of >= [windRiseThresholdKmh] from the previous hour to
/// this one, OR crossing [moderateWindSpeedKmh]/[highWindSpeedKmh] (reused
/// from `swim_suitability.dart`). A `null` reading on either side means
/// "no data to compare", not "0 km/h", so it is skipped.
_Trigger? _evaluateWind(double? prev, double? curr) {
  if (prev == null || curr == null) return null;

  if (prev < highWindSpeedKmh && curr >= highWindSpeedKmh) {
    return (
      severity: ForecastAlertSeverity.high,
      reason: _Reason.windCrossHigh,
    );
  }
  if (prev < moderateWindSpeedKmh && curr >= moderateWindSpeedKmh) {
    return (
      severity: ForecastAlertSeverity.moderate,
      reason: _Reason.windCrossModerate,
    );
  }
  if (curr - prev >= windRiseThresholdKmh) {
    return (severity: ForecastAlertSeverity.moderate, reason: _Reason.windRise);
  }
  return null;
}

/// Waves rule: a rise of >= [waveRiseThresholdM] from the previous hour to
/// this one, OR crossing [moderateWaveHeightM]/[highWaveHeightM] (reused
/// from `swim_suitability.dart`). A `null` reading on either side is
/// skipped, never treated as 0m.
_Trigger? _evaluateWaves(double? prev, double? curr) {
  if (prev == null || curr == null) return null;

  if (prev < highWaveHeightM && curr >= highWaveHeightM) {
    return (
      severity: ForecastAlertSeverity.high,
      reason: _Reason.waveCrossHigh,
    );
  }
  if (prev < moderateWaveHeightM && curr >= moderateWaveHeightM) {
    return (
      severity: ForecastAlertSeverity.moderate,
      reason: _Reason.waveCrossModerate,
    );
  }
  if (curr - prev >= waveRiseThresholdM) {
    return (severity: ForecastAlertSeverity.moderate, reason: _Reason.waveRise);
  }
  return null;
}

/// Rain rule: crossing [moderateRainChancePercent]/[highRainChancePercent]
/// (reused from `swim_suitability.dart`). Unlike wind/waves there is no
/// "rise" variant — a climbing-but-still-low rain chance (e.g. 5% -> 15%)
/// isn't actionable the way a sudden gust or swell is. A `null` reading on
/// either side is skipped, never treated as 0%.
_Trigger? _evaluateRain(double? prev, double? curr) {
  if (prev == null || curr == null) return null;

  if (prev < highRainChancePercent && curr >= highRainChancePercent) {
    return (
      severity: ForecastAlertSeverity.high,
      reason: _Reason.rainCrossHigh,
    );
  }
  if (prev < moderateRainChancePercent && curr >= moderateRainChancePercent) {
    return (
      severity: ForecastAlertSeverity.moderate,
      reason: _Reason.rainCrossModerate,
    );
  }
  return null;
}

/// The two cloud buckets the [_evaluateClouds] rule cares about. Mirrors
/// `home_screen.dart`'s `_iconForWeatherCode` grouping of Open-Meteo's WMO
/// weather codes (see also `weather_code.dart`'s `weatherCodeDescription`),
/// narrowed down to just "clear-ish" vs. "overcast or worse" since that is
/// the only transition this rule reports on.
enum _CloudBucket { clearOrPartlyCloudy, overcastOrWorse, other }

_CloudBucket _cloudBucket(int weatherCode) {
  if (weatherCode == 0 || weatherCode == 1 || weatherCode == 2) {
    return _CloudBucket.clearOrPartlyCloudy;
  }
  final isOvercast = weatherCode == 3;
  final isRain =
      (weatherCode >= 51 && weatherCode <= 67) ||
      (weatherCode >= 80 && weatherCode <= 82);
  final isThunderstorm =
      weatherCode == 95 || weatherCode == 96 || weatherCode == 99;
  if (isOvercast || isRain || isThunderstorm) {
    return _CloudBucket.overcastOrWorse;
  }
  return _CloudBucket.other;
}

/// Clouds rule: the weather code moves from clear/partly-cloudy into
/// overcast/rain/thunderstorm between the previous hour and this one.
/// `weatherCode` is never null on [WeatherHourly], so there is no null case
/// to skip here.
_Trigger? _evaluateClouds(int prev, int curr) {
  final prevBucket = _cloudBucket(prev);
  final currBucket = _cloudBucket(curr);
  if (prevBucket == _CloudBucket.clearOrPartlyCloudy &&
      currBucket == _CloudBucket.overcastOrWorse) {
    return (
      severity: ForecastAlertSeverity.moderate,
      reason: _Reason.cloudsClosingIn,
    );
  }
  return null;
}

// --- Windowing: merge adjacent triggered hours into one alert --------------

/// Walks [hourly] pairwise (previous hour, current hour), evaluates [evaluate]
/// for each pair whose current hour is after [now], and merges contiguous
/// triggered hours into one [ForecastAlert] per run instead of one per hour.
List<ForecastAlert> _collectAlerts<T>({
  required List<T> hourly,
  required DateTime Function(T) timeOf,
  required ForecastAlertType type,
  required DateTime now,
  required _Trigger? Function(T previous, T current) evaluate,
}) {
  final triggeredAt = <int, _Trigger>{};
  for (var i = 1; i < hourly.length; i++) {
    if (!timeOf(hourly[i]).isAfter(now)) continue;
    final trigger = evaluate(hourly[i - 1], hourly[i]);
    if (trigger != null) triggeredAt[i] = trigger;
  }

  final alerts = <ForecastAlert>[];
  int? runStart;
  int runEnd = -1;
  for (var i = 1; i < hourly.length; i++) {
    if (triggeredAt.containsKey(i)) {
      runStart ??= i;
      runEnd = i;
      continue;
    }
    if (runStart != null) {
      alerts.add(
        _buildAlert(type, hourly, timeOf, triggeredAt, runStart, runEnd),
      );
      runStart = null;
    }
  }
  if (runStart != null) {
    alerts.add(
      _buildAlert(type, hourly, timeOf, triggeredAt, runStart, runEnd),
    );
  }
  return alerts;
}

/// Builds the merged [ForecastAlert] for one contiguous run of triggered
/// hour indices `[runStart, runEnd]`. [start] is the reading right before
/// the rule first fired (the pre-trigger baseline); [end] is the last hour
/// the rule was still firing for. When more than one hour in the run has
/// the maximum severity, the latest one's wording is used (it best reflects
/// where the trend currently stands).
ForecastAlert _buildAlert<T>(
  ForecastAlertType type,
  List<T> hourly,
  DateTime Function(T) timeOf,
  Map<int, _Trigger> triggeredAt,
  int runStart,
  int runEnd,
) {
  final start = timeOf(hourly[runStart - 1]);
  final end = timeOf(hourly[runEnd]);

  var best = triggeredAt[runStart]!;
  for (var i = runStart + 1; i <= runEnd; i++) {
    final candidate = triggeredAt[i]!;
    if (candidate.severity.index >= best.severity.index) best = candidate;
  }

  return ForecastAlert(
    type: type,
    start: start,
    end: end,
    severity: best.severity,
    message: _messageFor(best.reason, start, end),
  );
}

String _messageFor(_Reason reason, DateTime start, DateTime end) {
  final startLabel = _formatHour(start);
  final endLabel = _formatHour(end);
  switch (reason) {
    case _Reason.windRise:
      return 'Wind picks up between $startLabel and $endLabel.';
    case _Reason.windCrossModerate:
      return 'Wind crosses ${moderateWindSpeedKmh.round()} km/h between '
          '$startLabel and $endLabel — getting breezy.';
    case _Reason.windCrossHigh:
      return 'Wind crosses ${highWindSpeedKmh.round()} km/h between '
          '$startLabel and $endLabel — strong wind expected.';
    case _Reason.waveRise:
      return 'Waves may rise between $startLabel and $endLabel.';
    case _Reason.waveCrossModerate:
      return 'Waves cross ${moderateWaveHeightM}m between $startLabel and '
          '$endLabel — getting choppy.';
    case _Reason.waveCrossHigh:
      return 'Waves cross ${highWaveHeightM}m between $startLabel and '
          '$endLabel — rough seas expected.';
    case _Reason.cloudsClosingIn:
      return 'Clouds moving in around $startLabel, sky will close in by '
          '$endLabel.';
    case _Reason.rainCrossModerate:
      return 'Rain chance crosses $moderateRainChancePercent% between '
          '$startLabel and $endLabel.';
    case _Reason.rainCrossHigh:
      return 'Rain chance crosses $highRainChancePercent% between '
          '$startLabel and $endLabel — bring a cover.';
  }
}

String _formatHour(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
