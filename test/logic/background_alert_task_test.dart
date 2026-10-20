import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/models/weather_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/selected_location_prefs_keys.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/data/services/notification_service.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:beachiq/logic/background_alert_task.dart';
import 'package:beachiq/logic/providers/condition_alert_dispatcher.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/weather_provider.dart';
import 'package:beachiq/logic/swim_suitability.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/builders.dart';

/// A [MarineRepository] whose [getMarineData] result (or thrown error) is
/// scripted per test, and which records whether it was ever called — so a
/// test can assert the background task never fetches when it shouldn't.
class _ScriptedMarineRepository extends MarineRepository {
  _ScriptedMarineRepository(this.data) : super(MarineApiService());

  SeaCondition? data;
  Object? error;
  int callCount = 0;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async {
    callCount++;
    final err = error;
    if (err != null) throw err;
    return data!;
  }
}

/// Same idea as [_ScriptedMarineRepository], for weather.
class _ScriptedWeatherRepository extends WeatherRepository {
  _ScriptedWeatherRepository(this.data) : super(WeatherApiService());

  WeatherCondition? data;
  Object? error;
  int callCount = 0;

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async {
    callCount++;
    final err = error;
    if (err != null) throw err;
    return data!;
  }
}

/// A [LocalNotificationsPlugin] that records every [show] call instead of
/// touching a real platform channel.
class _RecordingPlugin implements LocalNotificationsPlugin {
  final List<({String? title, String? body})> calls = [];

  @override
  Future<bool?> initialize(InitializationSettings settings) async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(int id, String? title, String? body) async {
    calls.add((title: title, body: body));
  }
}

/// A [BackgroundScheduler] that records every call instead of touching a
/// real Workmanager platform channel, and can be scripted to throw (e.g. a
/// simulated plugin/platform-channel failure).
class _RecordingScheduler implements BackgroundScheduler {
  int registerCount = 0;
  int cancelCount = 0;
  Object? error;

  @override
  Future<void> registerPeriodic() async {
    registerCount++;
    final err = error;
    if (err != null) throw err;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    final err = error;
    if (err != null) throw err;
  }
}

/// A "good" (calm) data pair: low wave, low wind, no rain.
final _goodSea = aSeaCondition(waveHeight: 0.2);
final _goodWeather = aWeatherCondition(windSpeed: 10, rainChancePercent: 0);

void main() {
  late _ScriptedMarineRepository marineRepository;
  late _ScriptedWeatherRepository weatherRepository;
  late _RecordingPlugin notificationPlugin;

  NotificationService notificationService() =>
      NotificationService(plugin: notificationPlugin);

  setUp(() {
    marineRepository = _ScriptedMarineRepository(_goodSea);
    weatherRepository = _ScriptedWeatherRepository(_goodWeather);
    notificationPlugin = _RecordingPlugin();
  });

  group('runBackgroundAlertCheck', () {
    Future<void> runCheck(SharedPreferences prefs) => runBackgroundAlertCheck(
      prefs: prefs,
      weatherRepository: weatherRepository,
      marineRepository: marineRepository,
      notificationService: notificationService(),
    );

    test('given alerts enabled and a persisted verdict transition to good, '
        'runBackgroundAlertCheck -> shows exactly one notification', () async {
      SharedPreferences.setMockInitialValues({
        selectedLocationLatPrefsKey: 38.32,
        selectedLocationLonPrefsKey: 26.32,
        conditionAlertPreviousVerdictPrefsKey: SwimSuitabilityLevel.poor.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await runCheck(prefs);

      expect(notificationPlugin.calls, hasLength(1));
      expect(
        notificationPlugin.calls.single.title,
        contains('Good swim conditions'),
      );
      expect(marineRepository.callCount, 1);
      expect(weatherRepository.callCount, 1);
      // The new baseline is persisted under the same key
      // ConditionAlertDispatcher uses, so a later foreground/background
      // run never disagrees about the last-seen verdict.
      expect(
        prefs.getString(conditionAlertPreviousVerdictPrefsKey),
        SwimSuitabilityLevel.good.name,
      );
    });

    test('given the verdict was already good, runBackgroundAlertCheck -> '
        'fetches but shows no notification', () async {
      SharedPreferences.setMockInitialValues({
        selectedLocationLatPrefsKey: 38.32,
        selectedLocationLonPrefsKey: 26.32,
        conditionAlertPreviousVerdictPrefsKey: SwimSuitabilityLevel.good.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await runCheck(prefs);

      expect(notificationPlugin.calls, isEmpty);
    });

    test('given alerts disabled, runBackgroundAlertCheck -> does nothing '
        '(no fetch, no notification)', () async {
      SharedPreferences.setMockInitialValues({
        alertsEnabledPrefsKey: false,
        selectedLocationLatPrefsKey: 38.32,
        selectedLocationLonPrefsKey: 26.32,
        conditionAlertPreviousVerdictPrefsKey: SwimSuitabilityLevel.poor.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await runCheck(prefs);

      expect(marineRepository.callCount, 0);
      expect(weatherRepository.callCount, 0);
      expect(notificationPlugin.calls, isEmpty);
    });

    test('given no persisted selected location, runBackgroundAlertCheck -> '
        'does nothing (no fetch, no notification)', () async {
      SharedPreferences.setMockInitialValues({
        conditionAlertPreviousVerdictPrefsKey: SwimSuitabilityLevel.poor.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await runCheck(prefs);

      expect(marineRepository.callCount, 0);
      expect(weatherRepository.callCount, 0);
      expect(notificationPlugin.calls, isEmpty);
    });

    test(
      'given a fetch failure, runBackgroundAlertCheck -> does not throw, '
      'does not show a notification, and keeps the previous baseline',
      () async {
        SharedPreferences.setMockInitialValues({
          selectedLocationLatPrefsKey: 38.32,
          selectedLocationLonPrefsKey: 26.32,
          conditionAlertPreviousVerdictPrefsKey: SwimSuitabilityLevel.poor.name,
        });
        final prefs = await SharedPreferences.getInstance();
        marineRepository.error = Exception('network error');

        await expectLater(runCheck(prefs), completes);

        expect(notificationPlugin.calls, isEmpty);
        expect(
          prefs.getString(conditionAlertPreviousVerdictPrefsKey),
          SwimSuitabilityLevel.poor.name,
        );
      },
    );

    test('given a weather fetch failure (marine succeeds), '
        'runBackgroundAlertCheck -> does not throw and does not show a '
        'notification', () async {
      SharedPreferences.setMockInitialValues({
        selectedLocationLatPrefsKey: 38.32,
        selectedLocationLonPrefsKey: 26.32,
        conditionAlertPreviousVerdictPrefsKey: SwimSuitabilityLevel.poor.name,
      });
      final prefs = await SharedPreferences.getInstance();
      weatherRepository.error = Exception('network error');

      await expectLater(runCheck(prefs), completes);

      expect(notificationPlugin.calls, isEmpty);
      expect(
        prefs.getString(conditionAlertPreviousVerdictPrefsKey),
        SwimSuitabilityLevel.poor.name,
      );
    });

    test('given no persisted baseline (first-ever run), '
        'runBackgroundAlertCheck -> shows no notification but persists a '
        'baseline for the next run', () async {
      SharedPreferences.setMockInitialValues({
        selectedLocationLatPrefsKey: 38.32,
        selectedLocationLonPrefsKey: 26.32,
      });
      final prefs = await SharedPreferences.getInstance();

      await runCheck(prefs);

      expect(notificationPlugin.calls, isEmpty);
      expect(
        prefs.getString(conditionAlertPreviousVerdictPrefsKey),
        SwimSuitabilityLevel.good.name,
      );
    });

    test('given a malformed/unknown persisted level string, '
        'runBackgroundAlertCheck -> treats it as no baseline (no notification) '
        'and overwrites it with a valid one', () async {
      SharedPreferences.setMockInitialValues({
        selectedLocationLatPrefsKey: 38.32,
        selectedLocationLonPrefsKey: 26.32,
        conditionAlertPreviousVerdictPrefsKey: 'not_a_real_level',
      });
      final prefs = await SharedPreferences.getInstance();

      await runCheck(prefs);

      expect(notificationPlugin.calls, isEmpty);
      expect(
        prefs.getString(conditionAlertPreviousVerdictPrefsKey),
        SwimSuitabilityLevel.good.name,
      );
    });

    test(
      'given a null waveHeight and a null rainChancePercent from the '
      'repositories (only windSpeed available), runBackgroundAlertCheck -> '
      'still scores a verdict from windSpeed alone and persists it',
      () async {
        SharedPreferences.setMockInitialValues({
          selectedLocationLatPrefsKey: 38.32,
          selectedLocationLonPrefsKey: 26.32,
          conditionAlertPreviousVerdictPrefsKey: SwimSuitabilityLevel.poor.name,
        });
        final prefs = await SharedPreferences.getInstance();
        // SeaCondition.waveHeight and WeatherCondition.rainChancePercent are
        // both nullable (unlike windSpeed, which the model declares
        // non-nullable); nulling them out exercises
        // scoreSwimSuitability's "independently missing inputs are simply
        // skipped" behavior from this call site, with windSpeed as the only
        // available signal.
        marineRepository.data = aSeaCondition(waveHeight: null);
        weatherRepository.data = aWeatherCondition(
          windSpeed: 10,
          rainChancePercent: null,
        );

        await expectLater(runCheck(prefs), completes);

        expect(notificationPlugin.calls, hasLength(1));
        expect(
          prefs.getString(conditionAlertPreviousVerdictPrefsKey),
          SwimSuitabilityLevel.good.name,
        );
      },
    );
  });

  group('SchedulingConditionAlertDispatcher', () {
    late MarineProvider marineProvider;
    late WeatherProvider weatherProvider;

    setUp(() {
      marineProvider = MarineProvider(marineRepository);
      weatherProvider = WeatherProvider(weatherRepository);
    });

    test('given alerts enabled, constructing it -> registers the periodic '
        'background check', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final scheduler = _RecordingScheduler();

      SchedulingConditionAlertDispatcher(
        weatherProvider: weatherProvider,
        marineProvider: marineProvider,
        notificationService: notificationService(),
        prefs: prefs,
        scheduler: scheduler,
      );
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.registerCount, 1);
      expect(scheduler.cancelCount, 0);
    });

    test('given alerts disabled, constructing it -> does not register the '
        'periodic background check', () async {
      SharedPreferences.setMockInitialValues({alertsEnabledPrefsKey: false});
      final prefs = await SharedPreferences.getInstance();
      final scheduler = _RecordingScheduler();

      SchedulingConditionAlertDispatcher(
        weatherProvider: weatherProvider,
        marineProvider: marineProvider,
        notificationService: notificationService(),
        prefs: prefs,
        scheduler: scheduler,
      );
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.registerCount, 0);
    });

    test('given setAlertsEnabled(false), the dispatcher -> cancels the '
        'periodic background check', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final scheduler = _RecordingScheduler();
      final dispatcher = SchedulingConditionAlertDispatcher(
        weatherProvider: weatherProvider,
        marineProvider: marineProvider,
        notificationService: notificationService(),
        prefs: prefs,
        scheduler: scheduler,
      );
      await Future<void>.delayed(Duration.zero);

      await dispatcher.setAlertsEnabled(false);

      expect(scheduler.cancelCount, 1);
    });

    test('given setAlertsEnabled(true) after being off, the dispatcher -> '
        're-registers the periodic background check', () async {
      SharedPreferences.setMockInitialValues({alertsEnabledPrefsKey: false});
      final prefs = await SharedPreferences.getInstance();
      final scheduler = _RecordingScheduler();
      final dispatcher = SchedulingConditionAlertDispatcher(
        weatherProvider: weatherProvider,
        marineProvider: marineProvider,
        notificationService: notificationService(),
        prefs: prefs,
        scheduler: scheduler,
      );
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.registerCount, 0);

      await dispatcher.setAlertsEnabled(true);

      expect(scheduler.registerCount, 1);
    });

    test('given the scheduler throws on construction (a simulated '
        'Workmanager plugin/platform-channel failure), constructing it -> '
        'does not throw', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final scheduler = _RecordingScheduler()..error = Exception('boom');

      SchedulingConditionAlertDispatcher(
        weatherProvider: weatherProvider,
        marineProvider: marineProvider,
        notificationService: notificationService(),
        prefs: prefs,
        scheduler: scheduler,
      );

      // The failure happens inside the fire-and-forget `unawaited()` call
      // in the constructor; flushing one microtask round-trip lets it run
      // to completion without this test itself ever seeing the error.
      await expectLater(Future<void>.delayed(Duration.zero), completes);
    });

    test('given the scheduler throws on setAlertsEnabled, the dispatcher -> '
        'does not throw and still returns from setAlertsEnabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final scheduler = _RecordingScheduler();
      final dispatcher = SchedulingConditionAlertDispatcher(
        weatherProvider: weatherProvider,
        marineProvider: marineProvider,
        notificationService: notificationService(),
        prefs: prefs,
        scheduler: scheduler,
      );
      await Future<void>.delayed(Duration.zero);
      scheduler.error = Exception('boom');

      await expectLater(dispatcher.setAlertsEnabled(false), completes);

      // The toggle itself is still persisted even though the scheduler
      // call failed.
      expect(prefs.getBool(alertsEnabledPrefsKey), false);
    });
  });

  group('buildBackgroundScheduler', () {
    test(
      'given isAndroid: true -> returns a WorkmanagerBackgroundScheduler',
      () {
        expect(
          buildBackgroundScheduler(isAndroid: true),
          isA<WorkmanagerBackgroundScheduler>(),
        );
      },
    );

    test('given isAndroid: false -> returns a NoopBackgroundScheduler', () {
      expect(
        buildBackgroundScheduler(isAndroid: false),
        isA<NoopBackgroundScheduler>(),
      );
    });
  });

  group('NoopBackgroundScheduler', () {
    test('registerPeriodic and cancel -> both complete without touching a '
        'real platform channel', () async {
      const scheduler = NoopBackgroundScheduler();

      await expectLater(scheduler.registerPeriodic(), completes);
      await expectLater(scheduler.cancel(), completes);
    });
  });
}
