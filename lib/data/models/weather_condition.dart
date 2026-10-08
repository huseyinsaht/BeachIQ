/// One day's sunrise/sunset pair, from Open-Meteo's `daily.sunrise` /
/// `daily.sunset` arrays (local time — the request uses `timezone=auto`).
/// A day whose response is missing either value is dropped entirely rather
/// than paired with a fabricated partner — see [WeatherCondition.fromJson].
class DaylightWindow {
  const DaylightWindow({required this.sunrise, required this.sunset});

  final DateTime sunrise;
  final DateTime sunset;
}

/// One day's forecast summary, from Open-Meteo's `daily` arrays (issue
/// #273: the 7-14 day outlook). Only [date] is required — the rest are
/// independently nullable, matching [WeatherHourly], so a day missing one
/// field (e.g. no wind data yet) still renders with whatever it has rather
/// than being dropped entirely.
class DailyWeatherForecast {
  const DailyWeatherForecast({
    required this.date,
    this.highTemperature,
    this.lowTemperature,
    this.windSpeedMaxKmh,
    this.rainChanceMaxPercent,
  });

  /// Local calendar date for this entry (midnight, from `daily.time`).
  final DateTime date;
  final double? highTemperature;
  final double? lowTemperature;
  final double? windSpeedMaxKmh;
  final double? rainChanceMaxPercent;
}

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

  // Issue #168: Open-Meteo's `precipitation_probability` was already being
  // fetched and parsed for [WeatherCondition.rainChancePercent] (the
  // "current" value) but discarded per-hour; exposing it here lets
  // `lib/logic/forecast_alerts.dart`'s rain rule reuse the real forecast
  // instead of guessing.
  final double? rainChancePercent;

  // Issue #165: sea-level pressure per hour, for the Pressure detail
  // screen's hourly chart. Nullable/absent by default, matching the other
  // extended hourly fields above.
  final double? pressureHpa;

  // Issue #178: UV index per hour, for the UV index detail screen's hourly
  // chart. Open-Meteo's `uv_index` hourly array was already being fetched
  // and parsed for [WeatherCondition.uvIndex] (the "current" value) but
  // discarded per-hour; this exposes the same array per entry, the same
  // way #165 added [pressureHpa] above.
  final double? uvIndex;

  WeatherHourly({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    this.windSpeed,
    this.windGusts,
    this.cloudCoverPercent,
    this.rainChancePercent,
    this.pressureHpa,
    this.uvIndex,
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

  // Issue #229: one entry per forecast day with a parseable sunrise AND
  // sunset, in the order Open-Meteo's `daily` arrays return them (today
  // first). Empty when the response has no `daily.sunrise`/`daily.sunset`
  // (older fixture, or the API omitted them) — callers (e.g.
  // `buildForecastAlerts`) treat an empty list as "no daylight data" and
  // fall back to their unfiltered behaviour rather than failing closed.
  final List<DaylightWindow> daylightWindows;

  /// One entry per forecast day with a parseable `daily.time`, in Open-
  /// Meteo's returned order (today first) — issue #273's 7-14 day
  /// outlook. Empty when the response has no `daily.time` (older fixture,
  /// or the API omitted it); callers treat an empty list as "no outlook
  /// data", same pattern as [daylightWindows].
  final List<DailyWeatherForecast> dailyForecast;

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
    this.daylightWindows = const [],
    this.dailyForecast = const [],
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
              rainChancePercent:
                  (precipitationProbabilities is List &&
                      i < precipitationProbabilities.length)
                  ? _asDouble(precipitationProbabilities[i])
                  : null,
              pressureHpa: (pressures is List && i < pressures.length)
                  ? _asDouble(pressures[i])
                  : null,
              uvIndex: (uvIndices is List && i < uvIndices.length)
                  ? _asDouble(uvIndices[i])
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
    final daylightWindows = <DaylightWindow>[];
    final dailyForecast = <DailyWeatherForecast>[];
    if (dailyJson is Map<String, dynamic>) {
      final highs = dailyJson['temperature_2m_max'];
      final lows = dailyJson['temperature_2m_min'];
      if (highs is List && highs.isNotEmpty) {
        highTemperature = _asDouble(highs.first);
      }
      if (lows is List && lows.isNotEmpty) {
        lowTemperature = _asDouble(lows.first);
      }

      final sunrises = dailyJson['sunrise'];
      final sunsets = dailyJson['sunset'];
      if (sunrises is List && sunsets is List) {
        final days = sunrises.length < sunsets.length
            ? sunrises.length
            : sunsets.length;
        for (var i = 0; i < days; i++) {
          final sunrise = DateTime.tryParse(sunrises[i].toString());
          final sunset = DateTime.tryParse(sunsets[i].toString());
          // Skip the day entirely rather than inventing a missing half of
          // the pair — matches the "no invented values" rule the hourly
          // fields above already follow.
          if (sunrise == null || sunset == null) continue;
          daylightWindows.add(DaylightWindow(sunrise: sunrise, sunset: sunset));
        }
      }

      final dailyTimes = dailyJson['time'];
      final dailyHighs = dailyJson['temperature_2m_max'];
      final dailyLows = dailyJson['temperature_2m_min'];
      final dailyWindMax = dailyJson['wind_speed_10m_max'];
      final dailyRainMax = dailyJson['precipitation_probability_max'];
      if (dailyTimes is List) {
        for (var i = 0; i < dailyTimes.length; i++) {
          final date = DateTime.tryParse(dailyTimes[i].toString());
          // A day with no parseable date is skipped rather than guessed,
          // matching every other "no invented values" case in this file.
          if (date == null) continue;
          dailyForecast.add(
            DailyWeatherForecast(
              date: date,
              highTemperature: _listValue(dailyHighs, i),
              lowTemperature: _listValue(dailyLows, i),
              windSpeedMaxKmh: _listValue(dailyWindMax, i),
              rainChanceMaxPercent: _listValue(dailyRainMax, i),
            ),
          );
        }
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
      daylightWindows: daylightWindows,
      dailyForecast: dailyForecast,
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

/// Reads index [i] of a JSON list as a [double], or null when the list
/// isn't long enough or isn't a list at all.
double? _listValue(dynamic list, int i) =>
    (list is List && i < list.length) ? _asDouble(list[i]) : null;
