import '../data/models/sea_condition.dart';
import '../data/models/weather_condition.dart';
import 'swim_suitability.dart';

/// One day's combined outlook (issue #273: the 7-14 day forecast), pairing
/// a [DailyWeatherForecast] entry with the matching [SeaDailyForecast]
/// entry (by calendar date) and the swim score those two would produce.
class DailyOutlookEntry {
  const DailyOutlookEntry({
    required this.date,
    required this.verdict,
    this.highTemperature,
    this.lowTemperature,
    this.waveHeightMax,
    this.windSpeedMaxKmh,
    this.rainChanceMaxPercent,
  });

  final DateTime date;
  final SwimVerdict verdict;
  final double? highTemperature;
  final double? lowTemperature;
  final double? waveHeightMax;
  final double? windSpeedMaxKmh;
  final double? rainChanceMaxPercent;
}

/// Combines [weatherDaily] and [seaDaily] into one ordered list of daily
/// outlooks, scoring each day with [scoreSwimSuitability] from the same
/// thresholds the smart suggestion pill uses — "one source of truth",
/// matching issue #257's note on reusing pure logic rather than
/// duplicating thresholds.
///
/// Pure function, no side effects. [weatherDaily] drives the resulting
/// dates and temperature/wind/rain fields; [seaDaily] is matched by
/// calendar date (year/month/day) to fill in that day's wave height, and a
/// day with no matching sea entry simply has a null wave height (the swim
/// score still considers wind/rain). Entries are not re-sorted: callers
/// pass already-ordered Open-Meteo data (today first).
List<DailyOutlookEntry> buildDailyOutlook({
  required List<DailyWeatherForecast> weatherDaily,
  required List<SeaDailyForecast> seaDaily,
}) {
  final seaByDate = <DateTime, double?>{};
  for (final entry in seaDaily) {
    seaByDate[_dateKey(entry.date)] = entry.waveHeightMax;
  }

  return weatherDaily.map((day) {
    final waveHeightMax = seaByDate[_dateKey(day.date)];
    return DailyOutlookEntry(
      date: day.date,
      verdict: scoreSwimSuitability(
        waveHeightM: waveHeightMax,
        windSpeedKmh: day.windSpeedMaxKmh,
        rainChancePercent: day.rainChanceMaxPercent?.round(),
      ),
      highTemperature: day.highTemperature,
      lowTemperature: day.lowTemperature,
      waveHeightMax: waveHeightMax,
      windSpeedMaxKmh: day.windSpeedMaxKmh,
      rainChanceMaxPercent: day.rainChanceMaxPercent,
    );
  }).toList();
}

DateTime _dateKey(DateTime date) => DateTime(date.year, date.month, date.day);
