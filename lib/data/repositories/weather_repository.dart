
import 'package:beachiq/data/models/weather_condition.dart';
import 'package:beachiq/data/services/weather_api_service.dart';

class WeatherRepository{

  final WeatherApiService apiService;
  WeatherRepository(this.apiService);

  Future<WeatherCondition> getWeatherData(double lat, double lon) async {
    final data = await apiService.getWeatherData(lat, lon);
    final currentData = data['current'];
    if (currentData is! Map<String, dynamic>) {
      throw Exception("Weather data response is missing the 'current' field");
    }
    // Merge the sibling 'hourly'/'daily' sections alongside the current
    // fields (unchanged in shape) so WeatherCondition.fromJson can derive
    // the extended forecast fields.
    final merged = <String, dynamic>{
      ...currentData,
      'hourly': data['hourly'],
      'daily': data['daily'],
    };
    return WeatherCondition.fromJson(merged);
  }

}
