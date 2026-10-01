/// The user's chosen display unit system: metric (meters, °C, km/h) or
/// imperial (feet, °F, mph).
enum UnitSystem { metric, imperial }

/// Converts a length in meters to feet (1 m = 3.28084 ft).
double metersToFeet(double meters) => meters * 3.28084;

/// Converts a temperature in degrees Celsius to degrees Fahrenheit
/// (°F = °C × 9/5 + 32).
double celsiusToFahrenheit(double celsius) => celsius * 9 / 5 + 32;

/// Converts a speed in km/h to mph (1 km/h = 0.621371 mph).
double kmhToMph(double kmh) => kmh * 0.621371;

/// Formats a wave height given in meters for display under [unitSystem],
/// e.g. `"1.2 m"` or `"3.9 ft"`.
String formatWaveHeight(double meters, UnitSystem unitSystem) {
  if (unitSystem == UnitSystem.imperial) {
    return '${metersToFeet(meters).toStringAsFixed(1)} ft';
  }
  return '${meters.toStringAsFixed(1)} m';
}

/// Formats a temperature given in degrees Celsius for display under
/// [unitSystem], e.g. `"23°C"` or `"73°F"`.
String formatTemperature(double celsius, UnitSystem unitSystem) {
  if (unitSystem == UnitSystem.imperial) {
    return '${celsiusToFahrenheit(celsius).round()}°F';
  }
  return '${celsius.round()}°C';
}

/// Formats a wind speed given in km/h for display under [unitSystem],
/// e.g. `"12 km/h"` or `"7 mph"`.
String formatWindSpeed(double kmh, UnitSystem unitSystem) {
  if (unitSystem == UnitSystem.imperial) {
    return '${kmhToMph(kmh).round()} mph';
  }
  return '${kmh.round()} km/h';
}
