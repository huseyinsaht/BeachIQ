/// A single hourly forecast entry (used to render the scrollable hourly
/// row on the Home screen).
class WeatherHourly {
  final DateTime time;
  final double temperature;
  final int weatherCode;

  WeatherHourly({
    required this.time,
    required this.temperature,
    required this.weatherCode,
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

      if (times is List) {
        for (var i = 0; i < times.length; i++) {
          final time = DateTime.tryParse(times[i].toString());
          if (time == null) continue;
          final temperature = (temps is List && i < temps.length)
              ? (temps[i] as num?)?.toDouble()
              : null;
          final code = (codes is List && i < codes.length)
              ? (codes[i] as num?)?.toInt()
              : null;
          hourlyList.add(
            WeatherHourly(
              time: time,
              temperature: temperature ?? 0,
              weatherCode: code ?? 0,
            ),
          );
        }

        // UV index and precipitation probability are only exposed by
        // Open-Meteo as hourly fields, so the "current" values for them
        // (and pressure, which we also request hourly to keep the request
        // shape simple) are read from the hourly entry whose timestamp
        // matches the current time, falling back to the first entry.
        final currentTime = json['time']?.toString();
        var currentIndex = 0;
        if (currentTime != null) {
          final matchedIndex = times.indexWhere(
            (t) => t.toString() == currentTime,
          );
          if (matchedIndex != -1) currentIndex = matchedIndex;
        }

        if (uvIndices is List && currentIndex < uvIndices.length) {
          uvIndex = (uvIndices[currentIndex] as num?)?.toDouble();
        }
        if (precipitationProbabilities is List &&
            currentIndex < precipitationProbabilities.length) {
          rainChancePercent =
              (precipitationProbabilities[currentIndex] as num?)?.toDouble();
        }
        if (pressures is List && currentIndex < pressures.length) {
          pressureHpa = (pressures[currentIndex] as num?)?.toDouble();
        }
      }
    }

    double? highTemperature;
    double? lowTemperature;
    if (dailyJson is Map<String, dynamic>) {
      final highs = dailyJson['temperature_2m_max'];
      final lows = dailyJson['temperature_2m_min'];
      if (highs is List && highs.isNotEmpty) {
        highTemperature = (highs.first as num?)?.toDouble();
      }
      if (lows is List && lows.isNotEmpty) {
        lowTemperature = (lows.first as num?)?.toDouble();
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
