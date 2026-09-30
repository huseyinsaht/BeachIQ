import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/mappers/osm_beach_mapper.dart';
import '../../data/models/beach.dart';
import '../../data/models/sea_condition.dart';
import '../../data/services/beach_cache.dart';
import '../../data/services/marine_batch_service.dart';
import '../../data/services/overpass_query_builder.dart';
import '../../data/services/overpass_service.dart';

enum NearbyBeachesStatus { idle, loading, loaded, empty, error }

/// Ties the nearby-beaches feature together for a single picked map
/// location: resolves the OSM beaches around it (via [BeachCache], which
/// only calls [OverpassService] on a cache miss or stale entry) and then
/// enriches them with marine data in one [MarineBatchService] call.
class NearbyBeachesProvider extends ChangeNotifier {
  NearbyBeachesProvider(
    this._overpassService,
    this._beachCache,
    this._marineBatchService, {
    // Trailing-edge debounce: a map pick often fires several times in quick
    // succession (drag-then-settle), and this keeps that to a single
    // Overpass request.
    Duration debounceDuration = const Duration(milliseconds: 400),
  }) : _debounceDuration = debounceDuration;

  final OverpassService _overpassService;
  final BeachCache _beachCache;
  final MarineBatchService _marineBatchService;
  final Duration _debounceDuration;

  Timer? _debounceTimer;
  int _requestId = 0;

  List<Beach> _beaches = const [];
  Map<Beach, SeaCondition?> _seaConditions = const {};
  bool _isLoading = false;
  String? _error;
  NearbyBeachesStatus _status = NearbyBeachesStatus.idle;

  List<Beach> get beaches => _beaches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  NearbyBeachesStatus get status => _status;
  bool get isEmpty => _status == NearbyBeachesStatus.empty;

  /// The merged marine data for [beach], if any was fetched for it.
  SeaCondition? seaConditionFor(Beach beach) => _seaConditions[beach];

  /// The only entry point that triggers a fetch. Debounced: rapid repeated
  /// picks (e.g. while a map settles) only fire one underlying request.
  void pickLocation(LatLng point) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () => _fetchFor(point));
  }

  Future<void> _fetchFor(LatLng point) async {
    final requestId = ++_requestId;

    _isLoading = true;
    _error = null;
    _status = NearbyBeachesStatus.loading;
    notifyListeners();

    final result = await _beachCache.get(
      latitude: point.latitude,
      longitude: point.longitude,
      fetch: () => _fetchFromOverpass(point),
    );

    if (requestId != _requestId) return;

    if (result.isStale) {
      unawaited(
        _beachCache
            .refresh(
              latitude: point.latitude,
              longitude: point.longitude,
              fetch: () => _fetchFromOverpass(point),
            )
            .catchError((_) => const <Beach>[]),
      );
    }

    if (result.beaches.isEmpty && result.isFallback) {
      _resolve(
        beaches: const [],
        seaConditions: const {},
        error: 'Could not load nearby beaches. Please try again.',
        status: NearbyBeachesStatus.error,
      );
      return;
    }

    if (result.beaches.isEmpty) {
      _resolve(
        beaches: const [],
        seaConditions: const {},
        error: null,
        status: NearbyBeachesStatus.empty,
      );
      return;
    }

    final seaConditions = await _fetchSeaConditions(result.beaches);
    if (requestId != _requestId) return;

    _resolve(
      beaches: result.beaches,
      seaConditions: seaConditions,
      error: null,
      status: NearbyBeachesStatus.loaded,
    );
  }

  void _resolve({
    required List<Beach> beaches,
    required Map<Beach, SeaCondition?> seaConditions,
    required String? error,
    required NearbyBeachesStatus status,
  }) {
    _beaches = beaches;
    _seaConditions = seaConditions;
    _isLoading = false;
    _error = error;
    _status = status;
    notifyListeners();
  }

  Future<List<Beach>> _fetchFromOverpass(LatLng point) async {
    final query = buildNearbyBeachesQuery(point.latitude, point.longitude);
    final response = await _overpassService.query(query);
    return mapOverpassToBeaches(response);
  }

  Future<Map<Beach, SeaCondition?>> _fetchSeaConditions(List<Beach> beaches) async {
    try {
      final coordinates = [for (final beach in beaches) LatLng(beach.latitude, beach.longitude)];
      final batch = await _marineBatchService.fetchBatch(coordinates);
      return {
        for (final beach in beaches) beach: batch['${beach.latitude},${beach.longitude}'],
      };
    } catch (_) {
      // Marine data is an enhancement on top of the beach list: a failed
      // batch call still leaves a usable, loaded list of beaches.
      return const {};
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
