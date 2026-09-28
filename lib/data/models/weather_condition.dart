class WeatherCondition {
  final double temperature;
  final double windSpeed;
  final int weatherCode;

  WeatherCondition({
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
  });

  factory WeatherCondition.fromJson(Map<String, dynamic> json) {
    return WeatherCondition(
      temperature: (json['temperature_2m'] ?? 0).toDouble(),
      windSpeed: (json['wind_speed_10m'] ?? 0).toDouble(),
      weatherCode: (json['weather_code'] ?? 0).toInt(),
    );
  }
}
