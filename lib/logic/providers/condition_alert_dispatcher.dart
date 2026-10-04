import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/notification_service.dart';
import '../condition_alert_service.dart';
import '../swim_suitability.dart';
import 'marine_provider.dart';
import 'weather_provider.dart';

/// `SharedPreferences` key for the alerts-enabled toggle. Defaults to `true`
/// (on) when absent — there is no settings screen to flip it yet (#221
/// explicitly defers that UI), but the toggle itself is already persisted so
/// a future settings screen (or a test) just needs to write this key.
const alertsEnabledPrefsKey = 'alerts_enabled';

@visibleForTesting
const conditionAlertPreviousVerdictPrefsKey =
    'condition_alert_previous_verdict_level';

/// Listens to a [WeatherProvider] and a [MarineProvider], computes a
/// [SwimVerdict] via [scoreSwimSuitability] on every update, and fires a
/// local notification through [NotificationService] whenever
/// [ConditionAlertService.shouldAlert] says the verdict just turned
/// favorable.
///
/// This is the delivery half of issue #87's pure trigger-decision logic:
/// not a widget — it is constructed once alongside the providers (see
/// `main.dart`) and left listening for the app's lifetime; nothing in the
/// widget tree needs to reference it directly.
class ConditionAlertDispatcher {
  ConditionAlertDispatcher({
    required WeatherProvider weatherProvider,
    required MarineProvider marineProvider,
    required NotificationService notificationService,
    required SharedPreferences prefs,
    String locationLabel = 'your location',
  }) : _weatherProvider = weatherProvider,
       _marineProvider = marineProvider,
       _notificationService = notificationService,
       _prefs = prefs,
       _locationLabel = locationLabel {
    _alertsEnabled = _prefs.getBool(alertsEnabledPrefsKey) ?? true;
    _previousLevel = _readPersistedLevel();
  }

  final WeatherProvider _weatherProvider;
  final MarineProvider _marineProvider;
  final NotificationService _notificationService;
  final SharedPreferences _prefs;

  String _locationLabel;
  late bool _alertsEnabled;

  /// The coordinates this dispatcher last scored a verdict for, read off
  /// [_weatherProvider]/[_marineProvider] (see their `lastLat`/`lastLon`).
  /// `null` until the first update. Lets [_handleUpdate] detect a location
  /// switch by itself — e.g. from a map tap or a search pick in
  /// `home_screen.dart` calling `fetchData` with new coordinates — without
  /// needing that call site to also call [onLocationChanged] explicitly.
  double? _lastSeenLat;
  double? _lastSeenLon;

  /// The last verdict level seen for the currently selected location, or
  /// `null` when there isn't one yet — either nothing has been observed, or
  /// [onLocationChanged] just reset it. A `null` baseline never triggers an
  /// alert on the next update; it only establishes one, so a cold start (or
  /// switching location) can never by itself look like a "just turned
  /// favorable" transition.
  late SwimSuitabilityLevel? _previousLevel;

  bool _listening = false;

  /// Whether alerts are currently enabled, per the persisted
  /// [alertsEnabledPrefsKey] toggle.
  bool get alertsEnabled => _alertsEnabled;

  /// The verdict level this dispatcher is currently using as its baseline
  /// for the next transition check, for tests.
  @visibleForTesting
  SwimSuitabilityLevel? get previousLevel => _previousLevel;

  /// Starts listening to the providers. Safe to call more than once.
  void start() {
    if (_listening) return;
    _listening = true;
    _weatherProvider.addListener(_handleUpdate);
    _marineProvider.addListener(_handleUpdate);
  }

  /// Stops listening (e.g. test teardown).
  void stop() {
    if (!_listening) return;
    _listening = false;
    _weatherProvider.removeListener(_handleUpdate);
    _marineProvider.removeListener(_handleUpdate);
  }

  /// Persists a new value for the alerts-enabled toggle. There is no
  /// settings-screen UI yet (#221 explicitly defers that); this exists so a
  /// future one — or a test — can flip it.
  Future<void> setAlertsEnabled(bool enabled) async {
    _alertsEnabled = enabled;
    await _prefs.setBool(alertsEnabledPrefsKey, enabled);
  }

  /// Call when the user switches to a different location, so the next
  /// verdict computed from the providers establishes a fresh baseline
  /// instead of being compared against whatever location was previously
  /// selected — otherwise an already-good new location would look like a
  /// "just turned favorable" transition purely from switching places.
  void onLocationChanged(String locationLabel) {
    _locationLabel = locationLabel;
    _previousLevel = null;
    unawaited(_persistLevel(null));
  }

  void _handleUpdate() {
    // Skip mid-fetch notifications: `currentData` hasn't changed yet while
    // a fetch is in flight, so there's nothing new to score.
    if (_weatherProvider.isLoading || _marineProvider.isLoading) return;

    final lat = _weatherProvider.lastLat ?? _marineProvider.lastLat;
    final lon = _weatherProvider.lastLon ?? _marineProvider.lastLon;
    if (lat != null &&
        lon != null &&
        _lastSeenLat != null &&
        _lastSeenLon != null &&
        (lat != _lastSeenLat || lon != _lastSeenLon)) {
      // The providers were fetched for different coordinates than last
      // time this dispatcher scored a verdict: the selected location
      // changed (e.g. a map tap or a search pick), so the old baseline
      // belongs to a different place and must not be compared against.
      _previousLevel = null;
      unawaited(_persistLevel(null));
    }
    _lastSeenLat = lat;
    _lastSeenLon = lon;

    final verdict = scoreSwimSuitability(
      waveHeightM: _marineProvider.currentData?.waveHeight,
      windSpeedKmh: _weatherProvider.currentData?.windSpeed,
      rainChancePercent: _weatherProvider.currentData?.rainChancePercent
          ?.round(),
    );

    final previousLevel = _previousLevel;
    if (previousLevel != null) {
      final service = ConditionAlertService(alertsEnabled: _alertsEnabled);
      final shouldAlert = service.shouldAlert(
        previous: SwimVerdict(previousLevel, ''),
        current: verdict,
      );
      if (shouldAlert) {
        unawaited(
          _notificationService.show(
            title: 'Good swim conditions at $_locationLabel',
            body: verdict.message,
          ),
        );
      }
    }

    _previousLevel = verdict.level;
    unawaited(_persistLevel(verdict.level));
  }

  SwimSuitabilityLevel? _readPersistedLevel() {
    final name = _prefs.getString(conditionAlertPreviousVerdictPrefsKey);
    if (name == null) return null;
    for (final level in SwimSuitabilityLevel.values) {
      if (level.name == name) return level;
    }
    return null;
  }

  Future<void> _persistLevel(SwimSuitabilityLevel? level) {
    if (level == null) {
      return _prefs.remove(conditionAlertPreviousVerdictPrefsKey);
    }
    return _prefs.setString(conditionAlertPreviousVerdictPrefsKey, level.name);
  }
}
