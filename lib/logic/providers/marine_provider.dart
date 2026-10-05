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

  /// Bumped on every [fetchData] call; a request only writes its result
  /// once it completes (success or error) while it's still the most
  /// recently started one. This is what makes "last tap wins": two
  /// overlapping fetches resolving out of order never let the older
  /// (stale) one overwrite the newer one's data (#213).
  int _requestToken = 0;

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
    final isSameLocation = _lastLat == lat && _lastLon == lon;
    _lastLat = lat;
    _lastLon = lon;
    final token = ++_requestToken;

    // A pick for a DIFFERENT location must never keep showing the old
    // place's values while the new fetch is in flight (#213) — clearing it
    // synchronously here, before the first `await`, means a listening
    // widget's very next rebuild (in the same frame as the tap) already
    // shows no data instead of the previous location's. A same-location
    // refresh (pull-to-refresh) keeps the data visible while it reloads.
    if (!isSameLocation) {
      _currentData = null;
    }
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final data = await _repository.getMarineData(lat, lon);
      if (token != _requestToken) return; // superseded by a newer request
      _currentData = data;
    } catch (e) {
      if (token != _requestToken) return; // superseded by a newer request
      _error = e.toString();
    }

    if (token != _requestToken) return; // superseded by a newer request
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
