import 'package:flutter/material.dart';

/// One resolved icon treatment: a main glyph/color, plus an optional small
/// accent glyph/color drawn over its bottom-right corner (used only for
/// the thunderstorm group's "violet cloud + yellow bolt" look).
class WeatherIconStyle {
  const WeatherIconStyle({
    required this.icon,
    required this.color,
    this.accentIcon,
    this.accentColor,
  });

  final IconData icon;
  final Color color;
  final IconData? accentIcon;
  final Color? accentColor;
}

/// Colors a monochrome hourly-row icon (as produced by `home_screen.dart`'s
/// `_iconForWeatherCode`) by its WMO weather-code group, with a day/night
/// variant for the two "clear" groups. Pure function, no side effects.
///
/// Each of the 7 `IconData` values `_iconForWeatherCode` can produce maps
/// 1:1 to one WMO group (clear, partly cloudy, overcast, fog,
/// drizzle/rain, snow, thunderstorm) — see `weather_code.dart`. An
/// unrecognized [baseIcon] (not one of those 7) falls back to plain white,
/// matching this widget's previous behavior.
WeatherIconStyle styleForWeatherIcon(IconData baseIcon, {required bool isDay}) {
  if (baseIcon == Icons.wb_sunny) {
    return isDay
        ? const WeatherIconStyle(icon: Icons.wb_sunny, color: Color(0xFFFFC94D))
        : const WeatherIconStyle(
            icon: Icons.nightlight_round,
            color: Color(0xFFE0E0E0),
          );
  }
  if (baseIcon == Icons.wb_cloudy) {
    return isDay
        ? const WeatherIconStyle(icon: Icons.wb_cloudy, color: Color(0xFF90A4AE))
        : const WeatherIconStyle(icon: Icons.nights_stay, color: Color(0xFFCFD8DC));
  }
  if (baseIcon == Icons.cloud) {
    return const WeatherIconStyle(icon: Icons.cloud, color: Color(0xFF78909C));
  }
  if (baseIcon == Icons.foggy) {
    return const WeatherIconStyle(icon: Icons.foggy, color: Color(0xFFCFD8DC));
  }
  if (baseIcon == Icons.grain) {
    return const WeatherIconStyle(icon: Icons.grain, color: Color(0xFF4FC3F7));
  }
  if (baseIcon == Icons.ac_unit) {
    return const WeatherIconStyle(icon: Icons.ac_unit, color: Color(0xFFB3E5FC));
  }
  if (baseIcon == Icons.thunderstorm) {
    return const WeatherIconStyle(
      icon: Icons.cloud,
      color: Color(0xFF9575CD),
      accentIcon: Icons.bolt,
      accentColor: Color(0xFFFDD835),
    );
  }
  return WeatherIconStyle(icon: baseIcon, color: Colors.white);
}

/// A single entry (time label, weather icon, bold temperature) for the home
/// screen's horizontally scrollable hourly forecast row.
///
/// The icon is colored by WMO weather-code group via [styleForWeatherIcon]
/// (sun yellow, cloud/fog blue-grey, rain blue, snow light blue,
/// thunderstorm violet + a yellow bolt accent), with a moon variant for a
/// clear/partly-cloudy hour. The day/night choice is this *entry's own*
/// hour via [time] (e.g. `entry.time` from `WeatherHourly`) — a row
/// spanning many hours must show a moon for a night entry and a sun for a
/// day one side by side, not whatever the device clock says "now". A null
/// [time] (no existing call site passes one) falls back to the real clock,
/// so this stays additive. This is a 6-20 bucket, not sunrise/sunset.
///
/// Pure presentational widget — no network, provider, or repository
/// dependency.
class HourlyForecastItem extends StatelessWidget {
  const HourlyForecastItem({
    super.key,
    required this.timeLabel,
    required this.icon,
    required this.temperature,
    this.time,
  });

  /// e.g. "Now", "3PM".
  final String timeLabel;
  final IconData icon;
  final String temperature;

  /// This entry's own forecast time, used only to decide its day/night
  /// icon variant (see class doc). Defaults to the real clock when null.
  final DateTime? time;

  static const _textSecondary = Color(0xFF8B93A6);

  bool get _isDay {
    final hour = (time ?? DateTime.now()).hour;
    return hour >= 6 && hour < 20;
  }

  @override
  Widget build(BuildContext context) {
    final style = styleForWeatherIcon(icon, isDay: _isDay);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeLabel,
          style: const TextStyle(color: _textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(style.icon, size: 24, color: style.color),
              if (style.accentIcon != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Icon(
                    style.accentIcon,
                    size: 12,
                    color: style.accentColor,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          temperature,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
