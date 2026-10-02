/// A single hourly forecast entry (used to render the scrollable hourly
/// row on the Home screen).
class WeatherHourly {
  final DateTime time;
  final double temperature;
  final int weatherCode;

  // Issue #155: nullable/absent by default so callers can distinguish
  // "no data available" from "value is zero", matching the rest of this
  // model's extended fields.
  final double? windSpeed;
  final double? windGusts;
  final double? cloudCoverPercent;

  // Issue #165: sea-level pressure per hour, for the Pressure detail
  // screen's hourly chart. Nullable/absent by default, matching the other
  // extended hourly fields above.
  final double? pressureHpa;

  WeatherHourly({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    this.windSpeed,
    this.windGusts,
    this.cloudCoverPercent,
    this.pressureHpa,
  });
}

class WeatherCondition {
  final double temperature;
  final double windSpeed;
  final int weatherCode;

  // Extended fields (issue #122). These are nullable/empty by default so
  // callers can distinguish "no data available" from "value is zero".
  final double? pressureHpa;
  final double? uvIndex;
  final double? rainChancePercent;
  final double? highTemperature;
  final double? lowTemperature;
  final List<WeatherHourly> hourly;

  WeatherCondition({
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    this.pressureHpa,
    this.uvIndex,
    this.rainChancePercent,
    this.highTemperature,
    this.lowTemperature,
    this.hourly = const [],
  });

  factory WeatherCondition.fromJson(Map<String, dynamic> json) {
    final hourlyJson = json['hourly'];
    final dailyJson = json['daily'];

    final hourlyList = <WeatherHourly>[];
    double? pressureHpa;
    double? uvIndex;
    double? rainChancePercent;

    if (hourlyJson is Map<String, dynamic>) {
      final times = hourlyJson['time'];
      final temps = hourlyJson['temperature_2m'];
      final codes = hourlyJson['weather_code'];
      final uvIndices = hourlyJson['uv_index'];
      final precipitationProbabilities =
          hourlyJson['precipitation_probability'];
      final pressures = hourlyJson['pressure_msl'];
      final windSpeeds = hourlyJson['wind_speed_10m'];
      final windGustsList = hourlyJson['wind_gusts_10m'];
      final cloudCovers = hourlyJson['cloud_cover'];

      if (times is List) {
        final parsedTimes = <DateTime?>[];
        for (var i = 0; i < times.length; i++) {
          final time = DateTime.tryParse(times[i].toString());
          parsedTimes.add(time);
          if (time == null) continue;
          final temperature = (temps is List && i < temps.length)
              ? _asDouble(temps[i])
              : null;
          final code = (codes is List && i < codes.length)
              ? _asInt(codes[i])
              : null;
          // Skip entries missing temperature or weather code rather than
          // fabricating a 0/"Clear" value, since both are valid real values.
          if (temperature == null || code == null) continue;
          hourlyList.add(
            WeatherHourly(
              time: time,
              temperature: temperature,
              weatherCode: code,
              windSpeed: (windSpeeds is List && i < windSpeeds.length)
                  ? _asDouble(windSpeeds[i])
                  : null,
              windGusts: (windGustsList is List && i < windGustsList.length)
                  ? _asDouble(windGustsList[i])
                  : null,
              cloudCoverPercent: (cloudCovers is List && i < cloudCovers.length)
                  ? _asDouble(cloudCovers[i])
                  : null,
              pressureHpa: (pressures is List && i < pressures.length)
                  ? _asDouble(pressures[i])
                  : null,
            ),
          );
        }

        // UV index and precipitation probability are only exposed by
        // Open-Meteo as hourly fields, so the "current" values for them
        // (and pressure, which we also request hourly to keep the request
        // shape simple) are read from the hourly entry whose timestamp is
        // the latest one at or before the current time. Open-Meteo's
        // `current.time` has minute resolution while `hourly.time` is on
        // the hour, so an exact string match would almost always miss;
        // comparing parsed DateTimes handles that.
        final currentTime = DateTime.tryParse(json['time']?.toString() ?? '');
        var currentIndex = 0;
        if (currentTime != null) {
          var bestIndex = -1;
          for (var i = 0; i < parsedTimes.length; i++) {
            final t = parsedTimes[i];
            if (t == null || t.isAfter(currentTime)) continue;
            if (bestIndex == -1 || t.isAfter(parsedTimes[bestIndex]!)) {
              bestIndex = i;
            }
          }
          if (bestIndex != -1) currentIndex = bestIndex;
        }

        if (uvIndices is List && currentIndex < uvIndices.length) {
          uvIndex = _asDouble(uvIndices[currentIndex]);
        }
        if (precipitationProbabilities is List &&
            currentIndex < precipitationProbabilities.length) {
          rainChancePercent = _asDouble(
            precipitationProbabilities[currentIndex],
          );
        }
        if (pressures is List && currentIndex < pressures.length) {
          pressureHpa = _asDouble(pressures[currentIndex]);
        }
      }
    }

    double? highTemperature;
    double? lowTemperature;
    if (dailyJson is Map<String, dynamic>) {
      final highs = dailyJson['temperature_2m_max'];
      final lows = dailyJson['temperature_2m_min'];
      if (highs is List && highs.isNotEmpty) {
        highTemperature = _asDouble(highs.first);
      }
      if (lows is List && lows.isNotEmpty) {
        lowTemperature = _asDouble(lows.first);
      }
    }

    return WeatherCondition(
      temperature: (json['temperature_2m'] ?? 0).toDouble(),
      windSpeed: (json['wind_speed_10m'] ?? 0).toDouble(),
      weatherCode: (json['weather_code'] ?? 0).toInt(),
      pressureHpa: pressureHpa,
      uvIndex: uvIndex,
      rainChancePercent: rainChancePercent,
      highTemperature: highTemperature,
      lowTemperature: lowTemperature,
      hourly: hourlyList,
    );
  }
}

/// Safely reads a numeric JSON value as a [double], returning null for a
/// missing/null entry or a value of an unexpected type (e.g. a String)
/// instead of throwing.
double? _asDouble(dynamic value) => value is num ? value.toDouble() : null;

/// Safely reads a numeric JSON value as an [int], returning null for a
/// missing/null entry or a value of an unexpected type instead of throwing.
int? _asInt(dynamic value) => value is num ? value.toInt() : null;
