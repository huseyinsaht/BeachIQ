/// A single hourly marine forecast entry (wave + ocean current series).
///
/// Modeled on `WeatherHourly`: every field but [time] is nullable so a
/// caller can distinguish "no data for this hour" from "value is zero"
/// (issue #154), matching [SeaCondition] itself.
class SeaHourly {
  final DateTime time;
  final double? waveHeight;
  final double? waveDirection;
  final double? wavePeriod;
  final double? seaSurfaceTemperature;

  /// Ocean current speed in km/h, straight from Open-Meteo. See
  /// [SeaCondition.currentVelocity] for why no unit conversion is needed
  /// and [SeaCondition.currentDirection] for the direction convention —
  /// both apply here too.
  final double? currentVelocity;
  final double? currentDirection;

  SeaHourly({
    required this.time,
    this.waveHeight,
    this.waveDirection,
    this.wavePeriod,
    this.seaSurfaceTemperature,
    this.currentVelocity,
    this.currentDirection,
  });
}

class SeaCondition {
  final double? waveHeight;
  final double? waveDirection;
  final double? wavePeriod;
  final double? seaSurfaceTemperature;

  /// Ocean current speed in km/h, exactly as Open-Meteo's Marine API
  /// returns `ocean_current_velocity` — no unit conversion needed here.
  ///
  /// Resolving issue #191: Open-Meteo's marine API computes this variable
  /// through the same derived-"wind speed" pipeline as `wind_speed_10m`
  /// (see `VariableHourly.swift`'s `.ocean_current_velocity -> .windSpeed`
  /// mapping in github.com/open-meteo/open-meteo), and that pipeline's
  /// output unit is controlled by the API's `wind_speed_unit` query
  /// parameter (declared on the marine endpoint's own OpenAPI spec,
  /// `openapi/marine.yml`), which **defaults to `kmh`** — see
  /// `SiUnit.swift`'s `convertAndRound`, which converts any
  /// `.metrePerSecond`-tagged value (the raw current speed from the model)
  /// to km/h whenever no `wind_speed_unit` is given. [MarineApiService]
  /// never sets `wind_speed_unit`, so every response it receives already
  /// carries `ocean_current_velocity` in km/h. PR #190's original
  /// `_msToKmh` (x3.6) conversion was therefore double-converting —
  /// inflating every value — and has been removed.
  ///
  /// Null — never `0` — when Open-Meteo has no current data for this
  /// point, which is common very close to shore since the current model's
  /// grid is coarse (several km).
  final double? currentVelocity;

  /// Degrees clockwise from true north giving the direction the current is
  /// flowing TOWARD. Open-Meteo's ocean current data is sourced from the
  /// Copernicus Marine Service, which documents current direction in the
  /// oceanographic "flowing toward" convention — the opposite of
  /// [waveDirection]/wind direction's meteorological "coming from"
  /// convention. See
  /// https://help.marine.copernicus.eu/en/articles/5046685. Null — never
  /// `0` — when unavailable, same as [currentVelocity].
  final double? currentDirection;

  /// The hourly forecast series for the request window. Empty when the API
  /// response has no `hourly` section (issue #154).
  final List<SeaHourly> hourly;

  SeaCondition({
    this.waveHeight,
    this.waveDirection,
    this.wavePeriod,
    this.seaSurfaceTemperature,
    this.currentVelocity,
    this.currentDirection,
    this.hourly = const [],
  });

  factory SeaCondition.fromJson(Map<String, dynamic> json) {
    final hourlyJson = json['hourly'];
    final hourlyList = <SeaHourly>[];

    if (hourlyJson is Map<String, dynamic>) {
      final times = hourlyJson['time'];
      final heights = hourlyJson['wave_height'];
      final directions = hourlyJson['wave_direction'];
      final periods = hourlyJson['wave_period'];
      final temperatures = hourlyJson['sea_surface_temperature'];
      final currentVelocities = hourlyJson['ocean_current_velocity'];
      final currentDirections = hourlyJson['ocean_current_direction'];

      if (times is List) {
        for (var i = 0; i < times.length; i++) {
          final time = DateTime.tryParse(times[i].toString());
          // Skip entries with no parseable time rather than fabricating
          // one, since every other field here is already nullable.
          if (time == null) continue;
          hourlyList.add(
            SeaHourly(
              time: time,
              waveHeight: _listValue(heights, i),
              waveDirection: _listValue(directions, i),
              wavePeriod: _listValue(periods, i),
              seaSurfaceTemperature: _listValue(temperatures, i),
              currentVelocity: _listValue(currentVelocities, i),
              currentDirection: _listValue(currentDirections, i),
            ),
          );
        }
      }
    }

    return SeaCondition(
      waveHeight: _asDouble(json['wave_height']),
      waveDirection: _asDouble(json['wave_direction']),
      wavePeriod: _asDouble(json['wave_period']),
      seaSurfaceTemperature: _asDouble(json['sea_surface_temperature']),
      currentVelocity: _asDouble(json['ocean_current_velocity']),
      currentDirection: _asDouble(json['ocean_current_direction']),
      hourly: hourlyList,
    );
  }
}

/// Safely reads a numeric JSON value as a [double], returning null for a
/// missing/null entry or a value of an unexpected type (e.g. a String)
/// instead of throwing or defaulting to `0`.
double? _asDouble(dynamic value) => value is num ? value.toDouble() : null;

/// Reads index [i] of a JSON list as a [double], or null when the list
/// isn't long enough or isn't a list at all.
double? _listValue(dynamic list, int i) =>
    (list is List && i < list.length) ? _asDouble(list[i]) : null;
