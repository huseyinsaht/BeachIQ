import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/services/api_service.dart';

class MarineRepository {
  final MarineApiService apiService;
  MarineRepository(this.apiService);

  Future<SeaCondition> getMarineData(double lat, double lon) async {
    final data = await apiService.getSeaData(lat, lon);
    final currentData = data['current'];
    if (currentData is! Map<String, dynamic>) {
      throw Exception("Marine data response is missing the 'current' field");
    }
    // Merge the sibling 'hourly'/'daily' sections alongside the current
    // fields (unchanged in shape) so SeaCondition.fromJson can derive the
    // hourly and daily forecast series, mirroring
    // WeatherRepository.getWeatherData.
    final merged = <String, dynamic>{
      ...currentData,
      'hourly': data['hourly'],
      'daily': data['daily'],
    };
    return SeaCondition.fromJson(merged);
  }
}
