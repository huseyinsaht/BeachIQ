import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/place.dart';
import '../../data/services/geocoding_service.dart';

enum PlaceSearchStatus { idle, loading, loaded, empty, error }

/// Drives a place-search-by-name UI: debounces [search] calls against
/// [GeocodingService] and exposes the loading/loaded/empty/error state,
/// following the same request-id/debounce pattern as
/// `NearbyBeachesProvider`.
class PlaceSearchProvider extends ChangeNotifier {
  PlaceSearchProvider(
    this._geocodingService, {
    // Trailing-edge debounce: typing fires several query changes in quick
    // succession, and this keeps that to a single network request once
    // typing settles.
    Duration debounceDuration = const Duration(milliseconds: 400),
  }) : _debounceDuration = debounceDuration;

  final GeocodingService _geocodingService;
  final Duration _debounceDuration;

  Timer? _debounceTimer;
  int _requestId = 0;
  bool _disposed = false;

  List<Place> _results = const [];
  bool _isLoading = false;
  String? _error;
  PlaceSearchStatus _status = PlaceSearchStatus.idle;

  List<Place> get results => _results;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PlaceSearchStatus get status => _status;

  /// The only entry point that triggers a search. Debounced: rapid
  /// keystrokes while typing only fire one underlying request once typing
  /// settles. A blank [query] clears the results immediately, with no
  /// debounce delay and no network call.
  void search(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      _requestId++;
      _resolve(results: const [], error: null, status: PlaceSearchStatus.idle);
      return;
    }
    _debounceTimer = Timer(_debounceDuration, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    _isLoading = true;
    _error = null;
    _status = PlaceSearchStatus.loading;
    _notify();

    try {
      final results = await _geocodingService.search(query);
      if (requestId != _requestId) return;
      _resolve(
        results: results,
        error: null,
        status: results.isEmpty
            ? PlaceSearchStatus.empty
            : PlaceSearchStatus.loaded,
      );
    } catch (e) {
      if (requestId != _requestId) return;
      _resolve(
        results: const [],
        error: 'Could not search for places. Please try again.',
        status: PlaceSearchStatus.error,
      );
    }
  }

  void _resolve({
    required List<Place> results,
    required String? error,
    required PlaceSearchStatus status,
  }) {
    _results = results;
    _isLoading = false;
    _error = error;
    _status = status;
    _notify();
  }

  /// Notifies listeners, unless the provider has already been disposed (a
  /// still-in-flight search from before disposal resolving afterwards must
  /// not touch a disposed [ChangeNotifier]).
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Bumping the request id makes every in-flight `_search`'s staleness
    // check (`requestId != _requestId`) fail, so it discards its result
    // instead of calling `_resolve` (and `_notify`, which is also guarded
    // by `_disposed` as a second line of defense) after disposal.
    _requestId++;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
