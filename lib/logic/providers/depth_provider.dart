import 'package:flutter/foundation.dart';

import '../../data/models/beach.dart';
import '../../data/models/depth_profile.dart';
import '../../data/services/bathymetry_service.dart';
import '../../data/services/depth_cache.dart';

/// Drives the Home screen's water-depth / shallow-entry tile and its
/// detail screen (issue #217): fetches a [DepthProfile] for whichever
/// beach the rest of Home currently keys its own beach-specific data off
/// of (the nearest fetched beach, or the one explicitly picked from
/// Search — see `home_screen.dart`'s own `nearestBeach`/`_selectedBeach`,
/// the same beach `SeaConditionsRow`'s shore-relation already uses),
/// through [DepthCache] ([BathymetryService]'s own 90-day, grid-keyed
/// cache — this provider adds no caching of its own).
///
/// Mirrors `MarineProvider`'s "last request wins" pattern: [fetchForBeach]
/// clears [profile] synchronously before awaiting a new beach's fetch, so
/// a listener never shows a previous beach's depth next to a new beach's
/// name, and a request token guards against a superseded fetch's result
/// overwriting a newer one.
class DepthProvider extends ChangeNotifier {
  DepthProvider(this._service, this._cache);

  final BathymetryService _service;
  final DepthCache _cache;

  DepthProfile? _profile;
  bool _isLoading = false;
  bool _disposed = false;
  int _requestToken = 0;
  Beach? _lastBeach;

  /// The most recently fetched profile. `null` before the first call to
  /// [fetchForBeach] has resolved (or while one for a *different* beach is
  /// in flight) — callers should treat `null` the same as
  /// [DepthProfile.unavailable] ("show no data"), never wait on it
  /// indefinitely.
  DepthProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  /// Fetches (or reuses the cached result for) [beach]'s nearshore depth
  /// profile. A no-op when [beach] `isSameBeach` as the beach this
  /// provider already fetched (or is fetching) for — callers are expected
  /// to call this on every rebuild once a "current beach" is known
  /// (mirroring how `home_screen.dart` already derives
  /// `nearestBeach`/`_selectedBeach`), so a fetch must only actually run
  /// once per distinct beach, not once per rebuild.
  ///
  /// `null` (no beach to key a transect off of — a bare map tap with no
  /// nearby beach resolved yet) clears [profile] to
  /// [DepthProfile.unavailable] without any network call.
  Future<void> fetchForBeach(Beach? beach) async {
    if (beach == null) {
      if (_lastBeach == null && _profile != null) return;
      _lastBeach = null;
      _requestToken++;
      _isLoading = false;
      _profile = const DepthProfile.unavailable();
      _notify();
      return;
    }
    if (_lastBeach != null && isSameBeach(_lastBeach!, beach)) return;
    _lastBeach = beach;

    final token = ++_requestToken;
    _profile = null;
    _isLoading = true;
    _notify();

    DepthProfile result;
    try {
      result = await _cache.get(
        latitude: beach.latitude,
        longitude: beach.longitude,
        fetch: () => _service.fetchProfile(beach),
      );
    } catch (_) {
      // Belt-and-braces: BathymetryService/DepthCache already resolve
      // every expected failure to DepthProfile.unavailable rather than
      // throwing, but a provider feeding a UI tile must never propagate
      // an exception either.
      result = const DepthProfile.unavailable();
    }

    if (token != _requestToken) return; // superseded by a newer request
    _profile = result;
    _isLoading = false;
    _notify();
  }

  /// Notifies listeners, unless this provider has already been disposed
  /// (e.g. a widget tree torn down while [fetchForBeach]'s request was
  /// still in flight) — calling `notifyListeners()` after `dispose()`
  /// throws.
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
