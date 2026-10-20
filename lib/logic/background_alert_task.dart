import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/repositories/marine_repository.dart';
import '../data/repositories/weather_repository.dart';
import '../data/selected_location_prefs_keys.dart';
import '../data/services/api_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/weather_api_service.dart';
import 'condition_alert_service.dart';
import 'providers/condition_alert_dispatcher.dart';
import 'swim_suitability.dart';

/// Workmanager identifiers for the periodic "conditions turned favorable"
/// background check (issue #359 — the background-delivery follow-up to
/// #87's pure trigger decision and #221's foreground delivery, both reused
/// here unchanged).
const backgroundAlertTaskUniqueName = 'beachiq.condition_alert_check';
const backgroundAlertTaskName = 'conditionAlertBackgroundCheck';

/// How often the background check runs. Workmanager's Android backend
/// enforces a 15-minute floor on periodic work regardless of a shorter
/// value, so this is the shortest meaningful setting.
const backgroundAlertCheckFrequency = Duration(minutes: 15);

/// Runs one background "did conditions turn favorable" check: fetches
/// weather + marine data for the persisted selected location
/// ([selectedLocationLatPrefsKey]/[selectedLocationLonPrefsKey], the same
/// keys `home_screen.dart` persists on every pick) and shows a notification
/// on exactly the same caution/poor/unknown -> good transition
/// [ConditionAlertService.shouldAlert] already defines for the foreground
/// [ConditionAlertDispatcher] — no new threshold, no new notification
/// channel.
///
/// Does nothing (no fetch, no notification) when alerts are disabled
/// ([alertsEnabledPrefsKey]) or when no location has ever been picked —
/// intentionally: `home_screen.dart`'s in-memory default (Çeşme) is never
/// itself persisted under [selectedLocationLatPrefsKey], so a user who has
/// never tapped the map or picked a search result gets no background
/// checks either, exactly like the foreground dispatcher only has a
/// baseline once a real pick has happened. Never throws: a fetch or
/// notification failure is caught and swallowed so a flaky background run
/// never crashes the OS task or shows a false notification — the next
/// periodic run simply tries again with the last persisted baseline.
///
/// Known limitation: this runs in a separate background isolate from a
/// live foreground [ConditionAlertDispatcher], so a baseline this writes
/// is not reflected in that dispatcher's own in-memory `_previousLevel`
/// until it re-reads [conditionAlertPreviousVerdictPrefsKey] (it currently
/// only does so once, at construction) — at worst a duplicate or missed
/// foreground alert right after a background one, never a crash or a wrong
/// verdict. Reconciling the two live is foreground listening logic this
/// issue deliberately leaves untouched.
Future<void> runBackgroundAlertCheck({
  required SharedPreferences prefs,
  required WeatherRepository weatherRepository,
  required MarineRepository marineRepository,
  required NotificationService notificationService,
}) async {
  final alertsEnabled = prefs.getBool(alertsEnabledPrefsKey) ?? true;
  if (!alertsEnabled) return;

  final lat = prefs.getDouble(selectedLocationLatPrefsKey);
  final lon = prefs.getDouble(selectedLocationLonPrefsKey);
  if (lat == null || lon == null) return;
  final locationLabel =
      prefs.getString(selectedLocationNamePrefsKey) ?? 'your location';

  double? waveHeightM;
  double? windSpeedKmh;
  int? rainChancePercent;
  try {
    final marine = await marineRepository.getMarineData(lat, lon);
    final weather = await weatherRepository.getWeatherData(lat, lon);
    waveHeightM = marine.waveHeight;
    windSpeedKmh = weather.windSpeed;
    rainChancePercent = weather.rainChancePercent?.round();
  } catch (_) {
    return;
  }

  final verdict = scoreSwimSuitability(
    waveHeightM: waveHeightM,
    windSpeedKmh: windSpeedKmh,
    rainChancePercent: rainChancePercent,
  );

  final previousLevel = _readPersistedLevel(prefs);
  if (previousLevel != null) {
    final service = ConditionAlertService(alertsEnabled: alertsEnabled);
    final shouldAlert = service.shouldAlert(
      previous: SwimVerdict(previousLevel, ''),
      current: verdict,
    );
    if (shouldAlert) {
      try {
        await notificationService.show(
          title: 'Good swim conditions at $locationLabel',
          body: verdict.message,
        );
      } catch (_) {
        // A plugin/permission failure showing the notification must not
        // skip persisting the new baseline below (that would make the
        // next run re-alert on the same already-seen transition) or
        // propagate out of this function — see the "Never throws" note
        // above.
      }
    }
  }

  await _persistLevel(prefs, verdict.level);
}

/// Reads the baseline verdict level persisted under
/// [conditionAlertPreviousVerdictPrefsKey] — the exact key
/// [ConditionAlertDispatcher] reads/writes, so a foreground run and a
/// background run always agree on the last-seen verdict.
SwimSuitabilityLevel? _readPersistedLevel(SharedPreferences prefs) {
  final name = prefs.getString(conditionAlertPreviousVerdictPrefsKey);
  if (name == null) return null;
  for (final level in SwimSuitabilityLevel.values) {
    if (level.name == name) return level;
  }
  return null;
}

Future<void> _persistLevel(
  SharedPreferences prefs,
  SwimSuitabilityLevel level,
) => prefs.setString(conditionAlertPreviousVerdictPrefsKey, level.name);

/// The Workmanager entry point. Registered once via [Workmanager.initialize]
/// (see [WorkmanagerBackgroundScheduler.registerPeriodic]) and invoked by
/// the OS in a background isolate, where none of `main()`'s long-lived
/// instances exist — so this builds its own [SharedPreferences] and
/// repositories rather than reusing the app's.
@pragma('vm:entry-point')
void backgroundAlertCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    await runBackgroundAlertCheck(
      prefs: prefs,
      weatherRepository: WeatherRepository(WeatherApiService()),
      marineRepository: MarineRepository(MarineApiService()),
      notificationService: NotificationService(),
    );
    return true;
  });
}

/// Thin injectable wrapper around the real OS scheduler, so
/// [SchedulingConditionAlertDispatcher] (and its tests) never depend on a
/// real platform channel. See [WorkmanagerBackgroundScheduler] for the
/// production implementation and [NoopBackgroundScheduler] for the
/// unsupported-platform fallback.
abstract class BackgroundScheduler {
  /// Registers the periodic background check. Safe to call repeatedly
  /// (e.g. on every app start) — the OS keeps the existing schedule rather
  /// than stacking duplicates.
  Future<void> registerPeriodic();

  /// Cancels the periodic background check.
  Future<void> cancel();
}

/// Production [BackgroundScheduler], delegating to a real [Workmanager].
class WorkmanagerBackgroundScheduler implements BackgroundScheduler {
  WorkmanagerBackgroundScheduler([Workmanager? workmanager])
    : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;
  bool _initialized = false;

  @override
  Future<void> registerPeriodic() async {
    if (!_initialized) {
      await _workmanager.initialize(backgroundAlertCallbackDispatcher);
      _initialized = true;
    }
    await _workmanager.registerPeriodicTask(
      backgroundAlertTaskUniqueName,
      backgroundAlertTaskName,
      frequency: backgroundAlertCheckFrequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  Future<void> cancel() =>
      _workmanager.cancelByUniqueName(backgroundAlertTaskUniqueName);
}

/// No-op [BackgroundScheduler] for a platform [buildBackgroundScheduler]
/// doesn't wire the real OS scheduler on.
class NoopBackgroundScheduler implements BackgroundScheduler {
  const NoopBackgroundScheduler();

  @override
  Future<void> registerPeriodic() async {}

  @override
  Future<void> cancel() async {}
}

/// Builds the production [BackgroundScheduler] — a real
/// [WorkmanagerBackgroundScheduler] on Android, a [NoopBackgroundScheduler]
/// everywhere else.
///
/// Android is this issue's minimum bar; iOS's BGTaskScheduler-based
/// periodic support is real in the `workmanager` package but unverified
/// here (no iOS device/simulator in this environment), and web/desktop have
/// no meaningful "while the app isn't open" background execution model for
/// this plugin to hook into. [isAndroid] is a parameter (rather than a
/// direct [Platform.isAndroid] read) so this can be exercised for every
/// platform in a plain unit test, matching
/// `reverse_geocoding_service.dart`'s `buildReverseGeocodingService`
/// pattern for its own platform split.
BackgroundScheduler buildBackgroundScheduler({bool? isAndroid}) {
  final onAndroid = isAndroid ?? (!kIsWeb && Platform.isAndroid);
  return onAndroid
      ? WorkmanagerBackgroundScheduler()
      : const NoopBackgroundScheduler();
}

/// Wraps [ConditionAlertDispatcher] so flipping the alerts-enabled toggle —
/// today, the map card overflow menu's "Alerts" switch on `home_screen.dart`
/// is the only call site of [setAlertsEnabled] — also registers/cancels the
/// periodic background check via [scheduler], without forking or
/// re-wiring the base dispatcher's foreground listening logic (which stays
/// exactly as [ConditionAlertDispatcher] already implements it).
///
/// Also registers (or leaves unregistered) on construction, matching the
/// already-persisted toggle, so a background check starts covering the app
/// from the very next launch once alerts are on.
class SchedulingConditionAlertDispatcher extends ConditionAlertDispatcher {
  SchedulingConditionAlertDispatcher({
    required super.weatherProvider,
    required super.marineProvider,
    required super.notificationService,
    required super.prefs,
    required this.scheduler,
    super.locationLabel = 'your location',
  }) {
    unawaited(_syncSchedule(alertsEnabled));
  }

  final BackgroundScheduler scheduler;

  @override
  Future<void> setAlertsEnabled(bool enabled) async {
    await super.setAlertsEnabled(enabled);
    await _syncSchedule(enabled);
  }

  /// Registers or cancels [scheduler]'s periodic check. Swallows any error
  /// the scheduler throws (a `Workmanager` plugin/platform-channel failure)
  /// rather than letting it escape the constructor as an uncaught async
  /// error, or [setAlertsEnabled] as a failure the UI has to handle — the
  /// toggle itself has already been persisted by [super.setAlertsEnabled]
  /// regardless, matching `main.dart`'s existing rule that a notification
  /// plugin failure must never stop the app (or, here, the toggle) from
  /// working.
  Future<void> _syncSchedule(bool enabled) async {
    try {
      await (enabled ? scheduler.registerPeriodic() : scheduler.cancel());
    } catch (_) {}
  }
}
