import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The minimal `flutter_local_notifications` surface [NotificationService]
/// depends on, factored out of the real `FlutterLocalNotificationsPlugin`
/// so tests can substitute a fake that never touches a real platform
/// channel (constructing the real plugin, or calling any of its methods,
/// throws a `MissingPluginException` outside a running app).
abstract class LocalNotificationsPlugin {
  /// Initializes the plugin. Returns whatever the underlying platform
  /// implementation reports (unused by [NotificationService] beyond
  /// awaiting it).
  Future<bool?> initialize(InitializationSettings settings);

  /// Requests the platform's runtime notification permission (Android 13+'s
  /// `POST_NOTIFICATIONS`, iOS's `UNUserNotificationCenter` authorization).
  /// Returns whether it was granted; a platform with no such runtime
  /// permission (desktop, web, older Android) should return `true`.
  Future<bool> requestPermission();

  /// Shows a single notification with [title]/[body].
  Future<void> show(int id, String? title, String? body);
}

/// Production [LocalNotificationsPlugin], delegating to a real
/// `FlutterLocalNotificationsPlugin`.
class RealLocalNotificationsPlugin implements LocalNotificationsPlugin {
  RealLocalNotificationsPlugin([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<bool?> initialize(InitializationSettings settings) =>
      _plugin.initialize(settings: settings);

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    // No platform-specific implementation resolved (e.g. desktop/web, or a
    // platform this plugin doesn't gate behind a runtime permission at
    // all): treat as granted rather than silently suppressing every alert.
    return true;
  }

  @override
  Future<void> show(int id, String? title, String? body) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'condition_alerts',
        'Condition alerts',
        channelDescription:
            'Alerts you when swim conditions turn favorable at your '
            'selected location.',
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

/// Initializes `flutter_local_notifications`, requests the Android
/// 13+/iOS notification permission exactly once, and exposes a minimal
/// [show] for a foreground "conditions turned favorable" alert (issue
/// #221 — the delivery half of #87's pure trigger-decision logic).
///
/// The [LocalNotificationsPlugin] is injectable (see [RealLocalNotificationsPlugin])
/// so tests never touch a real platform channel.
class NotificationService {
  NotificationService({LocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? RealLocalNotificationsPlugin();

  final LocalNotificationsPlugin _plugin;

  bool _initialized = false;
  bool _permissionGranted = false;

  /// Whether the notification permission has been granted. Only meaningful
  /// after [init] has completed.
  bool get permissionGranted => _permissionGranted;

  /// Initializes the plugin and requests the notification permission.
  /// Safe to call more than once — the real work (and the permission
  /// prompt) only happens on the first call, so repeated calls (e.g. from
  /// [show]'s own guard below) never re-prompt the user.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _permissionGranted = await _plugin.requestPermission();
  }

  /// Shows a single foreground notification with [title]/[body]. A no-op
  /// (no crash, nothing shown) when the permission was denied — [init] is
  /// called first if it hasn't run yet.
  Future<void> show({required String title, required String body}) async {
    if (!_initialized) await init();
    if (!_permissionGranted) return;
    await _plugin.show(0, title, body);
  }
}
