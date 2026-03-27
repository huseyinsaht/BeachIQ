
import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/services/api_service.dart';

class MarineRepository{

  final MarineApiService apiService;
  MarineRepository(this.apiService);

  Future<SeaCondition> getMarineData(double lat, double lon) async {
    final data = await apiService.getSeaData(lat, lon);
    final currentData = data['current'];
    return SeaCondition.fromJson(currentData);
  }

}