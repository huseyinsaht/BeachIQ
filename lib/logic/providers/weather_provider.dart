import 'package:beachiq/data/models/weather_condition.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/weather_repository.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherRepository _repository;

  WeatherProvider(this._repository);

  WeatherCondition? _currentData;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  WeatherCondition? get currentData => _currentData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchData(double lat, double lon) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final data = await _repository.getWeatherData(lat, lon);
      _currentData = data;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    _notify();
  }

  /// Notifies listeners, unless this provider has already been disposed
  /// (e.g. a widget tree torn down while [fetchData]'s request was still
  /// in flight) — calling `notifyListeners()` after `dispose()` throws.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
