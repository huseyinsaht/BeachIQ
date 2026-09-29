import 'package:beachiq/data/models/weather_condition.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/weather_repository.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherRepository _repository;

  WeatherProvider(this._repository);

  WeatherCondition? _currentData;
  bool _isLoading = false;
  String? _error;

  WeatherCondition? get currentData => _currentData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchData(double lat, double lon) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _repository.getWeatherData(lat, lon);
      _currentData = data;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
