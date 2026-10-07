import 'package:beachiq/data/services/device_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/fake_location.dart';

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
}
