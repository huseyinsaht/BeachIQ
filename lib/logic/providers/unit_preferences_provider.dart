import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../unit_preferences.dart';

/// Holds and persists the user's chosen [UnitSystem] (metric/imperial),
/// defaulting to [UnitSystem.metric] when nothing has been saved yet.
///
/// Backed by [SharedPreferences] so the choice survives app restarts. The
/// persisted value is loaded synchronously from the [SharedPreferences]
/// instance passed in at construction (callers obtain it with
/// `await SharedPreferences.getInstance()` first), matching the pattern
/// already used by `BeachCache`.
class UnitPreferencesProvider extends ChangeNotifier {
  UnitPreferencesProvider(this._prefs) {
    _load();
  }

  static const _prefsKey = 'unit_system';

  final SharedPreferences _prefs;
  UnitSystem _unitSystem = UnitSystem.metric;

  UnitSystem get unitSystem => _unitSystem;

  void _load() {
    final stored = _prefs.getString(_prefsKey);
    _unitSystem = stored == UnitSystem.imperial.name
        ? UnitSystem.imperial
        : UnitSystem.metric;
  }

  /// Sets the unit system and persists the choice. A no-op (no write, no
  /// notification) when [unitSystem] already matches the current value.
  Future<void> setUnitSystem(UnitSystem unitSystem) async {
    if (_unitSystem == unitSystem) return;
    _unitSystem = unitSystem;
    await _prefs.setString(_prefsKey, unitSystem.name);
    notifyListeners();
  }

  /// Switches between metric and imperial.
  Future<void> toggle() => setUnitSystem(
    _unitSystem == UnitSystem.metric ? UnitSystem.imperial : UnitSystem.metric,
  );
}
