import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/models/weather_condition.dart';
import 'package:beachiq/data/repositories/marine_repository.dart';
import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/services/api_service.dart';
import 'package:beachiq/data/services/notification_service.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:beachiq/logic/providers/condition_alert_dispatcher.dart';
import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/weather_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/builders.dart';

/// A [MarineRepository] whose [getMarineData] result can be changed
/// between calls, so a test can simulate a sequence of polls that each
/// return different data for the same provider instance — unlike
/// `test/helpers/pump_app.dart`'s `FakeMarineRepository`, which always
/// resolves to the one value it was built with.
class _ScriptedMarineRepository extends MarineRepository {
  _ScriptedMarineRepository(this.data) : super(MarineApiService());

  SeaCondition data;

  @override
  Future<SeaCondition> getMarineData(double lat, double lon) async => data;
}

/// Same idea as [_ScriptedMarineRepository], for weather.
class _ScriptedWeatherRepository extends WeatherRepository {
  _ScriptedWeatherRepository(this.data) : super(WeatherApiService());

  WeatherCondition data;

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async => data;
}

/// A [LocalNotificationsPlugin] that records every [show] call instead of
/// touching a real platform channel — wrapped in a real [NotificationService]
/// below so the dispatcher gets a genuine `NotificationService` (matching
/// its constructor's declared type) that is nonetheless fully fake.
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

/// Builds a [NotificationService] backed by [_RecordingPlugin] — a fake
/// notification service for dispatcher tests, never touching a real
/// platform channel.
NotificationService _fakeNotificationService(_RecordingPlugin plugin) =>
    NotificationService(plugin: plugin);

/// A "good" (calm) data pair: low wave, low wind, no rain.
final _goodSea = aSeaCondition(waveHeight: 0.2);
final _goodWeather = aWeatherCondition(windSpeed: 10, rainChancePercent: 0);

/// A "poor" (rough) data pair: high waves.
final _poorSea = aSeaCondition(waveHeight: 1.8);
final _poorWeather = aWeatherCondition(windSpeed: 10, rainChancePercent: 0);

void main() {
  late _ScriptedMarineRepository marineRepository;
  late _ScriptedWeatherRepository weatherRepository;
  late MarineProvider marineProvider;
  late WeatherProvider weatherProvider;
  late _RecordingPlugin notificationPlugin;
  late SharedPreferences prefs;

  /// Builds a dispatcher wired to the (already-constructed) providers
  /// above and starts it listening, with alerts enabled unless [enabled]
  /// says otherwise.
  Future<ConditionAlertDispatcher> buildDispatcher({
    bool enabled = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (!enabled) alertsEnabledPrefsKey: false,
    });
    prefs = await SharedPreferences.getInstance();
    final dispatcher = ConditionAlertDispatcher(
      weatherProvider: weatherProvider,
      marineProvider: marineProvider,
      notificationService: _fakeNotificationService(notificationPlugin),
      prefs: prefs,
    );
    dispatcher.start();
    return dispatcher;
  }

  /// Polls both providers at [lat]/[lon] (default a fixed, irrelevant
  /// coordinate), after pointing the scripted repositories at new data —
  /// simulating one foreground data refresh.
  Future<void> poll(
    SeaCondition sea,
    WeatherCondition weather, {
    double lat = 0,
    double lon = 0,
  }) async {
    marineRepository.data = sea;
    weatherRepository.data = weather;
    await Future.wait([
      marineProvider.fetchData(lat, lon),
      weatherProvider.fetchData(lat, lon),
    ]);
    // ConditionAlertDispatcher fires-and-forgets NotificationService.show
    // (itself async: it may lazily initialize first) from its listener
    // callback rather than awaiting it inline, since ChangeNotifier
    // listeners can't be awaited by notifyListeners. A zero-length delay
    // flushes every pending microtask (including chained awaits) before
    // this helper returns, so assertions right after `poll()` see the
    // result of that fire-and-forget call.
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    marineRepository = _ScriptedMarineRepository(_goodSea);
    weatherRepository = _ScriptedWeatherRepository(_goodWeather);
    marineProvider = MarineProvider(marineRepository);
    weatherProvider = WeatherProvider(weatherRepository);
    notificationPlugin = _RecordingPlugin();
  });

  group('ConditionAlertDispatcher', () {
    group('transition to good', () {
      test('given the verdict transitions from poor to good, polling -> shows '
          'exactly one notification', () async {
        await buildDispatcher();

        await poll(_poorSea, _poorWeather);
        expect(notificationPlugin.calls, isEmpty);

        await poll(_goodSea, _goodWeather);

        expect(notificationPlugin.calls, hasLength(1));
      });

      test(
        'given the verdict stays good across repeated polls, polling -> never '
        'fires a duplicate notification',
        () async {
          await buildDispatcher();

          await poll(_poorSea, _poorWeather);
          await poll(_goodSea, _goodWeather);
          expect(notificationPlugin.calls, hasLength(1));

          await poll(_goodSea, _goodWeather);
          await poll(_goodSea, _goodWeather);

          expect(notificationPlugin.calls, hasLength(1));
        },
      );

      test(
        'given the verdict never changes away from good, the very first poll '
        '-> does not fire (nothing to transition from yet)',
        () async {
          await buildDispatcher();

          await poll(_goodSea, _goodWeather);

          expect(notificationPlugin.calls, isEmpty);
        },
      );
    });

    group('alerts disabled', () {
      test('given alerts_enabled is false, a poor-to-good transition -> never '
          'fires regardless of the verdict transition', () async {
        await buildDispatcher(enabled: false);

        await poll(_poorSea, _poorWeather);
        await poll(_goodSea, _goodWeather);

        expect(notificationPlugin.calls, isEmpty);
      });
    });

    group('location switch', () {
      test(
        'given the selected location changes, onLocationChanged -> resets the '
        'baseline so the new location\'s first poll never fires purely from '
        'switching, even when it is already good',
        () async {
          final dispatcher = await buildDispatcher();

          // Establish a "poor" baseline for location A, then switch to B.
          await poll(_poorSea, _poorWeather);
          dispatcher.onLocationChanged('Location B');

          // B's first poll happens to be good — must not fire, since there
          // is no real "previous" for B yet.
          await poll(_goodSea, _goodWeather);
          expect(notificationPlugin.calls, isEmpty);

          // A genuine transition on B does fire.
          await poll(_poorSea, _poorWeather);
          await poll(_goodSea, _goodWeather);
          expect(notificationPlugin.calls, hasLength(1));
        },
      );
    });

    group('automatic location change detection', () {
      test('given the providers are polled at new coordinates, without '
          'onLocationChanged ever being called -> resets the baseline so the '
          'new location\'s first poll never fires purely from switching, even '
          'when it is already good', () async {
        await buildDispatcher();

        // Establish a "poor" baseline for location A (lat/lon 38.3/26.3).
        await poll(_poorSea, _poorWeather, lat: 38.3, lon: 26.3);

        // Switch to location B (different coordinates) via the same path
        // home_screen.dart uses (fetchData with new coordinates) — no
        // explicit onLocationChanged call. B's first poll happens to be
        // good: must not fire, since there is no real "previous" for B.
        await poll(_goodSea, _goodWeather, lat: 40.0, lon: 29.0);
        expect(notificationPlugin.calls, isEmpty);

        // A genuine transition on B does fire.
        await poll(_poorSea, _poorWeather, lat: 40.0, lon: 29.0);
        await poll(_goodSea, _goodWeather, lat: 40.0, lon: 29.0);
        expect(notificationPlugin.calls, hasLength(1));
      });

      test('given repeated polls stay at the same coordinates -> never resets '
          'the baseline purely from polling (duplicate suppression keeps '
          'working)', () async {
        await buildDispatcher();

        await poll(_poorSea, _poorWeather, lat: 38.3, lon: 26.3);
        await poll(_goodSea, _goodWeather, lat: 38.3, lon: 26.3);
        expect(notificationPlugin.calls, hasLength(1));

        await poll(_goodSea, _goodWeather, lat: 38.3, lon: 26.3);
        expect(notificationPlugin.calls, hasLength(1));
      });
    });

    group('stop', () {
      test(
        'given stop() was called, a subsequent poor-to-good transition -> '
        'never fires (the dispatcher detached from both providers)',
        () async {
          final dispatcher = await buildDispatcher();

          // Establish a "poor" baseline before detaching.
          await poll(_poorSea, _poorWeather);

          dispatcher.stop();

          // Without stop(), this poor-to-good transition would fire (see
          // the 'transition to good' group above).
          await poll(_goodSea, _goodWeather);

          expect(notificationPlugin.calls, isEmpty);
        },
      );

      test(
        'given stop() was called twice, the second call -> is a no-op '
        '(does not throw)',
        () async {
          final dispatcher = await buildDispatcher();

          dispatcher.stop();

          expect(dispatcher.stop, returnsNormally);
        },
      );
    });

    group('persistence', () {
      test(
        'given a dispatcher already saw a good verdict, a freshly constructed '
        'dispatcher on the same prefs -> treats good as the baseline (no fire '
        'on good-to-good)',
        () async {
          await buildDispatcher();
          await poll(_poorSea, _poorWeather);
          await poll(_goodSea, _goodWeather);
          expect(notificationPlugin.calls, hasLength(1));

          // Simulate an app restart: a brand-new dispatcher reads the same
          // persisted prefs.
          final restarted = ConditionAlertDispatcher(
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            notificationService: _fakeNotificationService(notificationPlugin),
            prefs: prefs,
          );
          restarted.start();

          await poll(_goodSea, _goodWeather);

          expect(notificationPlugin.calls, hasLength(1));
        },
      );

      test('given setAlertsEnabled(false) was called, a freshly constructed '
          'dispatcher on the same prefs -> reads alertsEnabled back as false '
          '(issue #267)', () async {
        final dispatcher = await buildDispatcher();
        expect(dispatcher.alertsEnabled, isTrue);

        await dispatcher.setAlertsEnabled(false);
        expect(dispatcher.alertsEnabled, isFalse);

        // Simulate an app restart: a brand-new dispatcher reads the same
        // persisted prefs key (`alertsEnabledPrefsKey`) rather than
        // defaulting back to enabled.
        final restarted = ConditionAlertDispatcher(
          weatherProvider: weatherProvider,
          marineProvider: marineProvider,
          notificationService: _fakeNotificationService(notificationPlugin),
          prefs: prefs,
        );

        expect(restarted.alertsEnabled, isFalse);
      });
    });
  });
}
