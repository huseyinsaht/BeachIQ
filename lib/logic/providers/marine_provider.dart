import 'package:beachiq/data/models/sea_condition.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/marine_repository.dart';

class MarineProvider extends ChangeNotifier {
  final MarineRepository _repository;

  MarineProvider(this._repository);

  SeaCondition? _currentData;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;
  double? _lastLat;
  double? _lastLon;

  SeaCondition? get currentData => _currentData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// The coordinates of the most recent [fetchData] call, or `null` before
  /// the first one. Lets a listener (e.g. `ConditionAlertDispatcher`) detect
  /// that the selected location changed without this provider needing to
  /// know about location selection itself.
  double? get lastLat => _lastLat;
  double? get lastLon => _lastLon;

  Future<void> fetchData(double lat, double lon) async {
    _lastLat = lat;
    _lastLon = lon;
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final data = await _repository.getMarineData(lat, lon);
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
