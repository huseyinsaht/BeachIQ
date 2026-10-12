import 'package:beachiq/data/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// A recorded call to [_FakeAndroidPlugin.show].
class _AndroidShowCall {
  const _AndroidShowCall(
    this.id,
    this.title,
    this.body,
    this.notificationDetails,
  );

  final int id;
  final String? title;
  final String? body;
  final AndroidNotificationDetails? notificationDetails;
}

/// Stands in for the platform-specific Android plugin that
/// `FlutterLocalNotificationsPlatform.instance` resolves to on Android, so
/// [RealLocalNotificationsPlugin] can be exercised without a real method
/// channel (which would throw outside a running app).
class _FakeAndroidPlugin extends AndroidFlutterLocalNotificationsPlugin {
  _FakeAndroidPlugin({this.permissionResult = true});

  bool? permissionResult;
  int initializeCallCount = 0;
  AndroidInitializationSettings? lastInitializeSettings;
  int requestPermissionCallCount = 0;
  final List<_AndroidShowCall> showCalls = [];

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCallCount++;
    lastInitializeSettings = settings;
    return true;
  }

  @override
  Future<bool?> requestNotificationsPermission() async {
    requestPermissionCallCount++;
    return permissionResult;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    showCalls.add(_AndroidShowCall(id, title, body, notificationDetails));
  }
}

/// Stands in for the platform-specific iOS plugin, the same way
/// [_FakeAndroidPlugin] does for Android.
class _FakeIOSPlugin extends IOSFlutterLocalNotificationsPlugin {
  _FakeIOSPlugin({this.permissionResult = true});

  bool? permissionResult;
  int requestPermissionsCallCount = 0;
  bool? lastSound;
  bool? lastAlert;
  bool? lastBadge;

  @override
  Future<bool?> initialize({
    required DarwinInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool carPlay = false,
    bool providesAppNotificationSettings = false,
  }) async {
    requestPermissionsCallCount++;
    lastSound = sound;
    lastAlert = alert;
    lastBadge = badge;
    return permissionResult;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    DarwinNotificationDetails? notificationDetails,
    String? payload,
  }) async {}
}

/// A recorded call to [FakeLocalNotificationsPlugin.show].
class ShowCall {
  const ShowCall(this.id, this.title, this.body);

  final int id;
  final String? title;
  final String? body;
}

/// A [LocalNotificationsPlugin] that never touches a real platform channel:
/// [initialize] and [requestPermission] just report whatever this test
/// configured, and every call is recorded for assertions.
class FakeLocalNotificationsPlugin implements LocalNotificationsPlugin {
  FakeLocalNotificationsPlugin({this.permissionGranted = true});

  /// What [requestPermission] resolves to.
  bool permissionGranted;

  int initializeCallCount = 0;
  int requestPermissionCallCount = 0;
  final List<ShowCall> showCalls = [];

  @override
  Future<bool?> initialize(InitializationSettings settings) async {
    initializeCallCount++;
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCallCount++;
    return permissionGranted;
  }

  @override
  Future<void> show(int id, String? title, String? body) async {
    showCalls.add(ShowCall(id, title, body));
  }
}

void main() {
  group('NotificationService', () {
    test(
      'given no plugin is injected, the constructor -> does not throw '
      '(defaults to the real plugin without touching a platform channel)',
      () {
        expect(() => NotificationService(), returnsNormally);
      },
    );

    group('init', () {
      test(
        'given a first call, init -> requests permission exactly once',
        () async {
          final plugin = FakeLocalNotificationsPlugin();
          final service = NotificationService(plugin: plugin);

          await service.init();

          expect(plugin.initializeCallCount, 1);
          expect(plugin.requestPermissionCallCount, 1);
        },
      );

      test(
        'given init already ran, a second init call -> never re-prompts',
        () async {
          final plugin = FakeLocalNotificationsPlugin();
          final service = NotificationService(plugin: plugin);

          await service.init();
          await service.init();

          expect(plugin.initializeCallCount, 1);
          expect(plugin.requestPermissionCallCount, 1);
        },
      );

      test(
        'given the permission is denied, init -> permissionGranted is false',
        () async {
          final plugin = FakeLocalNotificationsPlugin(permissionGranted: false);
          final service = NotificationService(plugin: plugin);

          await service.init();

          expect(service.permissionGranted, isFalse);
        },
      );
    });

    group('show', () {
      test(
        'given permission was granted, show -> forwards title/body to the plugin',
        () async {
          final plugin = FakeLocalNotificationsPlugin(permissionGranted: true);
          final service = NotificationService(plugin: plugin);
          await service.init();

          await service.show(title: 'Good swim conditions', body: 'Calm seas.');

          expect(plugin.showCalls, hasLength(1));
          expect(plugin.showCalls.single.title, 'Good swim conditions');
          expect(plugin.showCalls.single.body, 'Calm seas.');
        },
      );

      test(
        'given permission was denied, show -> never calls the plugin (no crash)',
        () async {
          final plugin = FakeLocalNotificationsPlugin(permissionGranted: false);
          final service = NotificationService(plugin: plugin);
          await service.init();

          await service.show(title: 'Good swim conditions', body: 'Calm seas.');

          expect(plugin.showCalls, isEmpty);
        },
      );

      test(
        'given show is called before init, show -> initializes first and still '
        'respects a denied permission',
        () async {
          final plugin = FakeLocalNotificationsPlugin(permissionGranted: false);
          final service = NotificationService(plugin: plugin);

          await service.show(title: 'Good swim conditions', body: 'Calm seas.');

          expect(plugin.initializeCallCount, 1);
          expect(plugin.requestPermissionCallCount, 1);
          expect(plugin.showCalls, isEmpty);
        },
      );

      test(
        'given repeated calls while conditions stay good, show -> each call still '
        'forwards (de-duplication is ConditionAlertDispatcher\'s job, not this '
        'service\'s)',
        () async {
          final plugin = FakeLocalNotificationsPlugin();
          final service = NotificationService(plugin: plugin);
          await service.init();

          await service.show(title: 'A', body: 'a');
          await service.show(title: 'B', body: 'b');

          expect(plugin.showCalls, hasLength(2));
        },
      );
    });
  });

  group('RealLocalNotificationsPlugin', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    group('initialize', () {
      test('given the Android platform, initialize -> forwards the Android '
          'settings to the resolved platform plugin', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final android = _FakeAndroidPlugin();
        FlutterLocalNotificationsPlatform.instance = android;
        final plugin = RealLocalNotificationsPlugin();

        await plugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );

        expect(android.initializeCallCount, 1);
        expect(
          android.lastInitializeSettings?.defaultIcon,
          '@mipmap/ic_launcher',
        );
      });
    });

    group('requestPermission', () {
      test(
        'given the Android platform and permission granted, requestPermission '
        '-> true, asking the Android plugin',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          final android = _FakeAndroidPlugin(permissionResult: true);
          FlutterLocalNotificationsPlatform.instance = android;
          final plugin = RealLocalNotificationsPlugin();

          final granted = await plugin.requestPermission();

          expect(granted, isTrue);
          expect(android.requestPermissionCallCount, 1);
        },
      );

      test(
        'given the Android platform and permission denied, requestPermission '
        '-> false',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          FlutterLocalNotificationsPlatform.instance = _FakeAndroidPlugin(
            permissionResult: false,
          );
          final plugin = RealLocalNotificationsPlugin();

          final granted = await plugin.requestPermission();

          expect(granted, isFalse);
        },
      );

      test(
        'given the Android plugin reports null, requestPermission -> treated '
        'as denied (false), never a crash',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          FlutterLocalNotificationsPlatform.instance = _FakeAndroidPlugin(
            permissionResult: null,
          );
          final plugin = RealLocalNotificationsPlugin();

          final granted = await plugin.requestPermission();

          expect(granted, isFalse);
        },
      );

      test(
        'given the iOS platform and permission granted, requestPermission -> '
        'true, requesting alert/badge/sound from the iOS plugin',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          final ios = _FakeIOSPlugin(permissionResult: true);
          FlutterLocalNotificationsPlatform.instance = ios;
          final plugin = RealLocalNotificationsPlugin();

          final granted = await plugin.requestPermission();

          expect(granted, isTrue);
          expect(ios.requestPermissionsCallCount, 1);
          expect(ios.lastSound, isTrue);
          expect(ios.lastAlert, isTrue);
          expect(ios.lastBadge, isTrue);
        },
      );

      test('given the iOS platform and permission denied, requestPermission -> '
          'false', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        FlutterLocalNotificationsPlatform.instance = _FakeIOSPlugin(
          permissionResult: false,
        );
        final plugin = RealLocalNotificationsPlugin();

        final granted = await plugin.requestPermission();

        expect(granted, isFalse);
      });

      test('given no platform-specific implementation resolves (e.g. desktop), '
          'requestPermission -> true (treated as granted, never silently '
          'suppressed)', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        // Registering the Android fake under a non-Android/iOS/macOS
        // override means resolvePlatformSpecificImplementation finds no
        // match for either type this plugin checks.
        FlutterLocalNotificationsPlatform.instance = _FakeAndroidPlugin();
        final plugin = RealLocalNotificationsPlugin();

        final granted = await plugin.requestPermission();

        expect(granted, isTrue);
      });
    });

    group('show', () {
      test('given the Android platform, show -> forwards id/title/body and the '
          'condition_alerts channel to the resolved platform plugin', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final android = _FakeAndroidPlugin();
        FlutterLocalNotificationsPlatform.instance = android;
        final plugin = RealLocalNotificationsPlugin();

        await plugin.show(0, 'Good swim conditions', 'Calm seas.');

        expect(android.showCalls, hasLength(1));
        final call = android.showCalls.single;
        expect(call.id, 0);
        expect(call.title, 'Good swim conditions');
        expect(call.body, 'Calm seas.');
        expect(call.notificationDetails?.channelId, 'condition_alerts');
      });
    });
  });
}
