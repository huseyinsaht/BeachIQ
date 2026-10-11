import 'package:beachiq/data/services/device_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/fake_location.dart';

/// Stands in for the real platform plugin `Geolocator`'s static methods
/// delegate to, so [GeolocatorDeviceLocationSource] can be exercised
/// without a real method channel (which throws outside a running app).
class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  _FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.position,
  });

  bool serviceEnabled;
  LocationPermission permission;
  Position? position;

  int getCurrentPositionCallCount = 0;
  LocationSettings? lastLocationSettings;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    getCurrentPositionCallCount++;
    lastLocationSettings = locationSettings;
    return position!;
  }
}

void main() {
  group('DeviceLocationService.getCurrentLocation', () {
    test('given location services are enabled and permission already granted, '
        'getCurrentLocation -> succeeds with the device position without '
        'ever requesting permission', () async {
      final source = FakeDeviceLocationSource(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        position: const LatLng(36.8969, 30.7133),
      );
      final service = DeviceLocationService(source);

      final result = await service.getCurrentLocation();

      expect(result.isSuccess, isTrue);
      expect(result.position, const LatLng(36.8969, 30.7133));
      expect(result.failure, isNull);
      expect(source.requestPermissionCallCount, 0);
    });

    test('given permission starts denied but is granted once requested, '
        'getCurrentLocation -> requests permission exactly once and still '
        'succeeds', () async {
      final source = FakeDeviceLocationSource(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.whileInUse,
        position: const LatLng(38.0, 27.0),
      );
      final service = DeviceLocationService(source);

      final result = await service.getCurrentLocation();

      expect(result.isSuccess, isTrue);
      expect(result.position, const LatLng(38.0, 27.0));
      expect(source.requestPermissionCallCount, 1);
    });

    test(
      'given location services are disabled, getCurrentLocation -> fails '
      'with serviceDisabled and never requests permission or a position',
      () async {
        final source = FakeDeviceLocationSource(serviceEnabled: false);
        final service = DeviceLocationService(source);

        final result = await service.getCurrentLocation();

        expect(result.isSuccess, isFalse);
        expect(result.position, isNull);
        expect(result.failure, DeviceLocationFailure.serviceDisabled);
        expect(source.requestPermissionCallCount, 0);
      },
    );

    test('given permission is denied even after being requested, '
        'getCurrentLocation -> fails with permissionDenied', () async {
      final source = FakeDeviceLocationSource(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.denied,
      );
      final service = DeviceLocationService(source);

      final result = await service.getCurrentLocation();

      expect(result.isSuccess, isFalse);
      expect(result.failure, DeviceLocationFailure.permissionDenied);
      expect(source.requestPermissionCallCount, 1);
    });

    test('given permission is permanently denied (no request is even '
        'attempted by geolocator in that case), getCurrentLocation -> fails '
        'with permissionDenied', () async {
      final source = FakeDeviceLocationSource(
        permission: LocationPermission.deniedForever,
      );
      final service = DeviceLocationService(source);

      final result = await service.getCurrentLocation();

      expect(result.isSuccess, isFalse);
      expect(result.failure, DeviceLocationFailure.permissionDenied);
      // deniedForever is not the `denied` value that triggers a
      // request — the real plugin would just keep refusing.
      expect(source.requestPermissionCallCount, 0);
    });

    test('given permission is unableToDetermine (the platform could not '
        'tell), getCurrentLocation -> fails with permissionDenied and never '
        'requests permission', () async {
      final source = FakeDeviceLocationSource(
        permission: LocationPermission.unableToDetermine,
      );
      final service = DeviceLocationService(source);

      final result = await service.getCurrentLocation();

      expect(result.isSuccess, isFalse);
      expect(result.failure, DeviceLocationFailure.permissionDenied);
      // unableToDetermine is not the `denied` value that triggers a
      // request, same as deniedForever.
      expect(source.requestPermissionCallCount, 0);
    });

    test('given permission is granted but obtaining a fix throws, '
        'getCurrentLocation -> fails with unavailable, never propagating the '
        'exception', () async {
      final source = FakeDeviceLocationSource(
        positionError: Exception('timeout'),
      );
      final service = DeviceLocationService(source);

      final result = await service.getCurrentLocation();

      expect(result.isSuccess, isFalse);
      expect(result.failure, DeviceLocationFailure.unavailable);
    });
  });

  group('GeolocatorDeviceLocationSource', () {
    test('given the real plugin reports enabled, isLocationServiceEnabled -> '
        'forwards the value', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        serviceEnabled: true,
      );
      final source = GeolocatorDeviceLocationSource();

      expect(await source.isLocationServiceEnabled(), isTrue);
    });

    test('given the real plugin reports a permission, checkPermission -> '
        'forwards it', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.denied,
      );
      final source = GeolocatorDeviceLocationSource();

      expect(await source.checkPermission(), LocationPermission.denied);
    });

    test('given the user grants permission when prompted, requestPermission -> '
        'forwards the granted value', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.whileInUse,
      );
      final source = GeolocatorDeviceLocationSource();

      expect(await source.requestPermission(), LocationPermission.whileInUse);
    });

    test('given the plugin resolves a position, getCurrentPosition -> maps it '
        'to a LatLng and requests low accuracy (issue #254: city-level is '
        'enough)', () async {
      final platform = _FakeGeolocatorPlatform(
        position: Position(
          latitude: 36.8969,
          longitude: 30.7133,
          timestamp: DateTime(2026),
          accuracy: 1,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      GeolocatorPlatform.instance = platform;
      final source = GeolocatorDeviceLocationSource();

      final point = await source.getCurrentPosition();

      expect(point, const LatLng(36.8969, 30.7133));
      expect(platform.getCurrentPositionCallCount, 1);
      expect(platform.lastLocationSettings?.accuracy, LocationAccuracy.low);
    });
  });
}
