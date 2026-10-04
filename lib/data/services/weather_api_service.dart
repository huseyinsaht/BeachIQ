import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherApiService {
  static const String _baseUrl = "https://api.open-meteo.com/v1/forecast";

  Future<Map<String, dynamic>> getWeatherData(double lat, double lon) async {
    final queryParams = {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': 'temperature_2m,wind_speed_10m,weather_code',
      'hourly':
          'temperature_2m,weather_code,uv_index,precipitation_probability,pressure_msl,wind_speed_10m,wind_gusts_10m,cloud_cover',
      'daily': 'temperature_2m_max,temperature_2m_min',
      'timezone': 'auto',
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network Error: $e");
    }
  }
}
