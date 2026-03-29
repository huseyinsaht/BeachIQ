import 'package:beachiq/data/models/sea_condition.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/marine_repository.dart';

class MarineProvider extends ChangeNotifier {
  final MarineRepository _repository;

  MarineProvider(this._repository);

  SeaCondition? _currentData;
  bool _isLoading = false;
  String? _error;

  SeaCondition? get currentData => _currentData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchData(double lat, double lon) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _repository.getMarineData(lat,lon);
      _currentData = data;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
