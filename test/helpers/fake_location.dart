import 'package:beachiq/data/services/device_location_service.dart';
import 'package:beachiq/data/services/reverse_geocoding_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// A fully scripted [DeviceLocationSource] for issue #254's tests — never
/// touches real GPS hardware or shows a real platform permission dialog
/// (constructing/calling the real `Geolocator` outside a running app
/// throws a `MissingPluginException`), mirroring `fake_http_client.dart`'s
/// "configure the result, then act" shape.
class FakeDeviceLocationSource implements DeviceLocationSource {
  FakeDeviceLocationSource({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.permissionAfterRequest,
    this.position = const LatLng(36.8969, 30.7133),
    this.positionError,
  });

  /// Whether [isLocationServiceEnabled] reports the device's location
  /// services as switched on.
  bool serviceEnabled;

  /// What [checkPermission] returns before any [requestPermission] call.
  LocationPermission permission;

  /// What [requestPermission] returns when called — only reached when
  /// [permission] starts out [LocationPermission.denied], mirroring
  /// [DeviceLocationService]'s real "only prompt once, in response to the
  /// initial denial" flow. Defaults to echoing [permission] unchanged when
  /// left null.
  LocationPermission? permissionAfterRequest;

  /// The position [getCurrentPosition] resolves to, unless [positionError]
  /// is set.
  LatLng position;

  /// When set, [getCurrentPosition] throws this instead of resolving —
  /// simulates a platform failure (e.g. a timeout) after permission/service
  /// checks already passed.
  Object? positionError;

  /// How many times [requestPermission] was actually called — lets a test
  /// assert the permission prompt only fires when expected (never
  /// speculatively).
  int requestPermissionCallCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCallCount++;
    return permissionAfterRequest ?? permission;
  }

  @override
  Future<LatLng> getCurrentPosition() async {
    if (positionError != null) throw positionError!;
    return position;
  }
}

/// A fully scripted [PlacemarkLookup] for issue #254's tests — never
/// touches a real platform geocoder channel.
class FakePlacemarkLookup implements PlacemarkLookup {
  FakePlacemarkLookup({this.result = const [], this.error});

  /// The placemarks [lookup] resolves to, unless [error] is set.
  List<Placemark> result;

  /// When set, [lookup] throws this instead of resolving — simulates a
  /// `PlatformException` (rate limit, no Google Play Services, etc.).
  Object? error;

  /// Every (`latitude`, `longitude`) [lookup] was actually called with —
  /// lets a test assert a cache hit skipped the real lookup entirely.
  final List<(double, double)> calls = [];

  @override
  Future<List<Placemark>> lookup(double latitude, double longitude) async {
    calls.add((latitude, longitude));
    if (error != null) throw error!;
    return result;
  }
}
