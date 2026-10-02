import 'package:flutter/material.dart';

import '../../data/models/weather_condition.dart';
import '../screens/detail/pressure_detail_screen.dart';
import '../screens/detail/uv_index_detail_screen.dart';

/// Every Home-screen stat tile that opens its own detail screen (issue
/// #165 builds the shared foundation and [pressure]; issue #178 adds
/// [uvIndex]; the rest follow in their own issues/PRs: rain chance #179,
/// wind #166, wave height #167, water temperature #180, current #181).
enum DetailMetric {
  pressure,
  uvIndex,
  rainChance,
  wind,
  waveHeight,
  waterTemperature,
  current,
}

/// Builds the [Route] for a tapped Home stat tile's [DetailMetric].
///
/// One `MaterialPageRoute` per metric, each given a [RouteSettings.name]
/// (`/detail/<metric>`) so tests/navigation observers can find it by name
/// instead of by widget type alone. Only [DetailMetric.pressure] and
/// [DetailMetric.uvIndex] are wired up so far — every other case falls
/// through to the `default` branch below and throws [UnimplementedError];
/// each later PR removes its metric from that fallthrough list and adds
/// its own `case` above it, without touching this function's existing
/// cases.
///
/// [hourly] and [currentValue] carry whatever per-hour series and "right
/// now" reading that metric's screen needs (e.g. hourly sea-level pressure
/// for [DetailMetric.pressure], hourly UV index for [DetailMetric.uvIndex]);
/// [now] is the overridable "current time" source threaded through to the
/// screen for widget tests.
Route<void> buildDetailRoute(
  DetailMetric metric, {
  required List<WeatherHourly> hourly,
  double? currentValue,
  DateTime Function()? now,
}) {
  switch (metric) {
    case DetailMetric.pressure:
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/detail/pressure'),
        builder: (_) => PressureDetailScreen(
          hourly: hourly,
          currentPressureHpa: currentValue,
          now: now,
        ),
      );
    case DetailMetric.uvIndex:
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/detail/uv-index'),
        builder: (_) => UvIndexDetailScreen(
          hourly: hourly,
          currentUvIndex: currentValue,
          now: now,
        ),
      );
    case DetailMetric.rainChance:
    case DetailMetric.wind:
    case DetailMetric.waveHeight:
    case DetailMetric.waterTemperature:
    case DetailMetric.current:
      throw UnimplementedError(
        'No detail screen for $metric yet — see its tracking issue.',
      );
  }
}
