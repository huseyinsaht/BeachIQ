import 'package:beachiq/data/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

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
          final plugin = FakeLocalNotificationsPlugin(
            permissionGranted: false,
          );
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
          final plugin = FakeLocalNotificationsPlugin(
            permissionGranted: false,
          );
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
          final plugin = FakeLocalNotificationsPlugin(
            permissionGranted: false,
          );
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
}
