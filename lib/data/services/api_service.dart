import 'dart:convert';
import 'dart:io';
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
    print("======= URI $uri");

    try {
      final response = await http.get(uri);
      print("=======  RESPONSE  $response");
      if (response.statusCode == 200) {
        var result = json.decode(response.body);
        print(" ======= RESULT $result");
        return result;
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network Error: $e");
    }
  }
}