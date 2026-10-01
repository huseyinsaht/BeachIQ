import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/beach.dart';

/// Persists the set of beaches the user has marked as a favorite.
///
/// Beaches have no stable id of their own (the static placeholder list and
/// OSM-derived beaches alike), so favorites are keyed by [keyFor] — a
/// `name|city` string, which is stable enough for a single beach list and
/// avoids depending on [Beach] gaining an id field just for this.
///
/// Backed by [SharedPreferences], matching the pattern already used by
/// `BeachCache`/`UnitPreferencesProvider`: the caller obtains the instance
/// with `await SharedPreferences.getInstance()` and passes it in.
class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider(this._prefs) {
    _load();
  }

  static const _prefsKey = 'favorite_beaches';

  final SharedPreferences _prefs;
  Set<String> _favoriteKeys = const {};
  bool _disposed = false;

  /// A stable key for [beach], used both to persist favorites and to look
  /// one up.
  static String keyFor(Beach beach) => '${beach.name}|${beach.city}';

  void _load() {
    _favoriteKeys = _prefs.getStringList(_prefsKey)?.toSet() ?? const {};
  }

  bool isFavorite(Beach beach) => _favoriteKeys.contains(keyFor(beach));

  /// The subset of [beaches] the user has marked as a favorite, in the
  /// same order [beaches] was given in.
  List<Beach> favoritesAmong(List<Beach> beaches) =>
      beaches.where(isFavorite).toList();

  /// Adds [beach] to the favorites if it isn't already one, or removes it
  /// if it is, then persists the change.
  Future<void> toggleFavorite(Beach beach) async {
    final key = keyFor(beach);
    final updated = {..._favoriteKeys};
    if (!updated.remove(key)) {
      updated.add(key);
    }
    _favoriteKeys = updated;
    await _prefs.setStringList(_prefsKey, _favoriteKeys.toList());
    _notify();
  }

  /// Notifies listeners, unless this provider has already been disposed
  /// (e.g. a widget tree torn down while [toggleFavorite]'s persistence
  /// write was still in flight) — calling `notifyListeners()` after
  /// `dispose()` throws.
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
