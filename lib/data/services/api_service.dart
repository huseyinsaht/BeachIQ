import 'dart:convert';
import 'package:http/http.dart' as http;

class MarineApiService {
  static const String _baseUrl = "https://marine-api.open-meteo.com/v1/marine";

  Future<Map<String, dynamic>> getSeaData(double lat, double lon) async {

    final queryParams = {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': 'wave_height,sea_surface_temperature,wave_period,wave_direction',
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