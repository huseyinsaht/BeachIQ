/// Turns an hourly rain-chance series into plain-language "likely rain"
/// windows for the rain chance detail screen (issue #179), in the same
/// small-pure-function-module style as `lib/logic/pressure_trend.dart`.
library;

import '../data/models/weather_condition.dart';
import 'swim_suitability.dart';

/// A single contiguous stretch of hours whose rain chance was at or above
/// the threshold [rainChanceWindows] was called with.
class RainWindow {
  const RainWindow({required this.start, required this.end});

  /// The first qualifying hour's own timestamp.
  final DateTime start;

  /// One hour after the last qualifying hour's timestamp (i.e. the end of
  /// that hour), so a single qualifying hour at 14:00 reads as "between
  /// 14:00 and 15:00" rather than a zero-length window.
  final DateTime end;
}

/// Groups [hourly] into contiguous [RainWindow]s wherever
/// `WeatherHourly.rainChancePercent` is at or above [thresholdPercent]
/// (defaults to `moderateRainChancePercent`, reused from
/// `swim_suitability.dart` so this never drifts from the swim pill's own
/// cutoff).
///
/// Pure function: no side effects, same input always returns the same
/// windows. A `null` hour breaks a window's continuity (it is never
/// treated as 0 %) but does not itself start one; it is simply skipped.
/// Hours are assumed to already be in chronological order, matching every
/// other hourly series in this app.
List<RainWindow> rainChanceWindows(
  List<WeatherHourly> hourly, {
  num thresholdPercent = moderateRainChancePercent,
}) {
  final windows = <RainWindow>[];
  DateTime? windowStart;
  DateTime? windowEnd;

  void flush() {
    final start = windowStart;
    final end = windowEnd;
    if (start != null && end != null) {
      windows.add(
        RainWindow(start: start, end: end.add(const Duration(hours: 1))),
      );
    }
    windowStart = null;
    windowEnd = null;
  }

  for (final entry in hourly) {
    final percent = entry.rainChancePercent;
    if (percent != null && percent >= thresholdPercent) {
      windowStart ??= entry.time;
      windowEnd = entry.time;
    } else {
      flush();
    }
  }
  flush();

  return windows;
}

String _twoDigit(int value) => value.toString().padLeft(2, '0');

String _formatTime(DateTime time) =>
    '${_twoDigit(time.hour)}:${_twoDigit(time.minute)}';

/// A ready-to-show, plain-language summary of [windows], e.g. "Rain likely
/// between 14:00 and 17:00." for one window, "Rain likely between 09:00
/// and 11:00, and between 15:00 and 17:00." for several, or "No rain
/// expected today." when [windows] is empty.
String rainChanceSummary(List<RainWindow> windows) {
  if (windows.isEmpty) return 'No rain expected today.';

  final ranges = [
    for (final window in windows)
      'between ${_formatTime(window.start)} and ${_formatTime(window.end)}',
  ];
  return 'Rain likely ${ranges.join(', and ')}.';
}
