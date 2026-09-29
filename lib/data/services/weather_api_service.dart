import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherApiService {
  static const String _baseUrl = "https://api.open-meteo.com/v1/forecast";

  Future<Map<String, dynamic>> getWeatherData(double lat, double lon) async {

    final queryParams = {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': 'temperature_2m,wind_speed_10m,weather_code',
      'timezone': 'auto'
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
