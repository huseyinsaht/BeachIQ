import 'package:flutter/material.dart';

import '../../data/models/sea_condition.dart';
import '../../data/models/weather_condition.dart';
import '../../logic/unit_preferences.dart';
import '../screens/detail/pressure_detail_screen.dart';
import '../screens/detail/rain_chance_detail_screen.dart';
import '../screens/detail/uv_index_detail_screen.dart';
import '../screens/detail/water_temperature_detail_screen.dart';
import '../screens/detail/wave_height_detail_screen.dart';
import '../screens/detail/wind_detail_screen.dart';

/// Every Home-screen stat tile that opens its own detail screen (issue
/// #165 builds the shared foundation and [pressure]; issue #178 adds
/// [uvIndex]; issue #167 adds [waveHeight]; issue #166 adds [wind]; issue
/// #179 adds [rainChance]; issue #180 adds [waterTemperature]; current
/// #181 is the only one left.
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
/// instead of by widget type alone. Only [DetailMetric.pressure],
/// [DetailMetric.uvIndex], [DetailMetric.waveHeight], [DetailMetric.wind],
/// [DetailMetric.rainChance] and [DetailMetric.waterTemperature] are wired
/// up so far — every other case falls through to the `default` branch
/// below and throws
/// [UnimplementedError]; each later PR removes its metric from that
/// fallthrough list and adds its own `case` above it, without touching
/// this function's existing cases.
///
/// [hourly] and [currentValue] carry whatever per-hour series and "right
/// now" reading that metric's screen needs (e.g. hourly sea-level pressure
/// for [DetailMetric.pressure], hourly UV index for [DetailMetric.uvIndex]).
/// [DetailMetric.waveHeight] instead needs the marine hourly series — a
/// `SeaCondition`'s `hourly` (wave height/period/direction), not a
/// `WeatherHourly` series — so it reads [seaHourly] and ignores [hourly]
/// (callers that have no [seaHourly] data, e.g. the loop in
/// `detail_routes_test.dart` covering every not-yet-implemented metric,
/// can simply omit it; it defaults to an empty series). [unitSystem] is
/// the display-unit preference, needed by [DetailMetric.waveHeight] for
/// its meters/feet conversion; metrics with no unit of their own (pressure,
/// UV index) ignore it. [now] is the overridable "current time" source
/// threaded through to the screen for widget tests.
Route<void> buildDetailRoute(
  DetailMetric metric, {
  required List<WeatherHourly> hourly,
  List<SeaHourly> seaHourly = const [],
  double? currentValue,
  UnitSystem unitSystem = UnitSystem.metric,
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
    case DetailMetric.waveHeight:
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/detail/wave-height'),
        builder: (_) => WaveHeightDetailScreen(
          hourly: seaHourly,
          currentWaveHeightMeters: currentValue,
          unitSystem: unitSystem,
          now: now,
        ),
      );
    case DetailMetric.wind:
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/detail/wind'),
        builder: (_) => WindDetailScreen(
          hourly: hourly,
          currentWindSpeedKmh: currentValue,
          unitSystem: unitSystem,
          now: now,
        ),
      );
    case DetailMetric.rainChance:
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/detail/rain-chance'),
        builder: (_) => RainChanceDetailScreen(
          hourly: hourly,
          currentRainChancePercent: currentValue,
          now: now,
        ),
      );
    case DetailMetric.waterTemperature:
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/detail/water-temperature'),
        builder: (_) => WaterTemperatureDetailScreen(
          hourly: seaHourly,
          currentWaterTemperatureCelsius: currentValue,
          unitSystem: unitSystem,
          now: now,
        ),
      );
    case DetailMetric.current:
      throw UnimplementedError(
        'No detail screen for $metric yet — see its tracking issue.',
      );
  }
}
