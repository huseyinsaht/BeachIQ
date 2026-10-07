import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// The minimal `geolocator` surface [DeviceLocationService] depends on,
/// factored out of the real static `Geolocator` methods so tests can
/// substitute a fake that never touches real GPS hardware or a platform
/// permission dialog (calling `Geolocator`'s real static methods outside a
/// running app throws a `MissingPluginException`), mirroring
/// `notification_service.dart`'s `LocalNotificationsPlugin` pattern.
abstract class DeviceLocationSource {
  /// Whether the device's location services (GPS/network location) are
  /// switched on at all, independent of this app's own permission.
  Future<bool> isLocationServiceEnabled();

  /// The app's current location permission, without prompting.
  Future<LocationPermission> checkPermission();

  /// Prompts the user for location permission. Only ever called from
  /// [DeviceLocationService.getCurrentLocation], itself only ever called
  /// from an explicit "Use my location" tap — never on app start.
  Future<LocationPermission> requestPermission();

  /// The device's current position. Callers are expected to have already
  /// confirmed the service is enabled and permission granted.
  Future<LatLng> getCurrentPosition();
}

/// Production [DeviceLocationSource], delegating to the real `Geolocator`
/// static methods. Issue #254: city-level accuracy is enough, so
/// [getCurrentPosition] always asks for [LocationAccuracy.low] — paired
/// with Android's manifest declaring only `ACCESS_COARSE_LOCATION`.
class GeolocatorDeviceLocationSource implements DeviceLocationSource {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<LatLng> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
    return LatLng(position.latitude, position.longitude);
  }
}

/// Why [DeviceLocationService.getCurrentLocation] did not return a
/// position — never surfaced as a raw exception, so a caller (the Home
/// screen's "Use my location" action) can show a short, specific message
/// instead of a generic error.
enum DeviceLocationFailure {
  /// The device's location services (GPS/network location) are off
  /// entirely — nothing this app's own permission can fix.
  serviceDisabled,

  /// The user denied (or permanently denied) this app's location
  /// permission, including just now when asked.
  permissionDenied,

  /// Location services and permission are fine, but a position still
  /// couldn't be obtained (timeout, platform error, etc.).
  unavailable,
}

/// The outcome of [DeviceLocationService.getCurrentLocation]: either a real
/// device [position], or a [failure] reason — never both, and never a
/// fabricated position standing in for a failure.
class DeviceLocationResult {
  const DeviceLocationResult.success(LatLng point)
    : position = point,
      failure = null;

  const DeviceLocationResult.failure(DeviceLocationFailure reason)
    : position = null,
      failure = reason;

  final LatLng? position;
  final DeviceLocationFailure? failure;

  bool get isSuccess => position != null;
}

/// Issue #254's opt-in device-location lookup: wraps [DeviceLocationSource]
/// (the real `geolocator` plugin in production) with the permission/
/// service-enabled dance the "Use my location" action needs, so its caller
/// only has to deal with [DeviceLocationResult].
///
/// [getCurrentLocation] is the *only* entry point, and it is only ever
/// expected to be called from an explicit user action — it never runs on
/// app start, and never invents a position when it can't get a real one:
/// any failure (service off, permission denied, or any other platform
/// error) resolves to a [DeviceLocationResult.failure], never a thrown
/// exception and never a guessed [DeviceLocationResult.position].
class DeviceLocationService {
  DeviceLocationService(this._source);

  final DeviceLocationSource _source;

  Future<DeviceLocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await _source.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const DeviceLocationResult.failure(
          DeviceLocationFailure.serviceDisabled,
        );
      }

      var permission = await _source.checkPermission();
      // Only ever prompts here, in direct response to the caller's own
      // explicit request — never speculatively.
      if (permission == LocationPermission.denied) {
        permission = await _source.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return const DeviceLocationResult.failure(
          DeviceLocationFailure.permissionDenied,
        );
      }

      final point = await _source.getCurrentPosition();
      return DeviceLocationResult.success(point);
    } catch (_) {
      // Any unexpected platform failure (e.g. a timeout obtaining a fix)
      // falls back to "unavailable" rather than propagating — this
      // service's whole point is to hand its caller a result it can
      // always safely react to.
      return const DeviceLocationResult.failure(
        DeviceLocationFailure.unavailable,
      );
    }
  }
}
