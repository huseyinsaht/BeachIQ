import 'package:beachiq/data/services/reverse_geocode_cache.dart';
import 'package:beachiq/data/services/reverse_geocoding_service.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart'
    as pi;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_location.dart';

/// Stands in for the real platform plugin that `Geocoding`'s factory
/// constructor delegates to, so [GeocodingPlacemarkLookup] can be exercised
/// without a real method channel (which throws outside a running app),
/// mirroring `device_location_service_test.dart`'s
/// `_FakeGeolocatorPlatform` pattern.
class _FakeGeocodingPlatform extends pi.Geocoding {
  _FakeGeocodingPlatform({this.result, this.error})
    : super.implementation(const pi.GeocodingCreationParams());

  List<pi.Placemark>? result;
  Object? error;
  final List<(double, double)> calls = [];

  @override
  Future<List<pi.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    Locale? locale,
  }) async {
    calls.add((latitude, longitude));
    if (error != null) throw error!;
    return result ?? const [];
  }
}

class _FakeGeocodingPlatformFactory extends pi.GeocodingPlatformFactory {
  _FakeGeocodingPlatformFactory(this._platform);

  final pi.Geocoding _platform;

  @override
  pi.Geocoding createGeocoding(pi.GeocodingCreationParams params) => _platform;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ReverseGeocodeCache> cache() async =>
      ReverseGeocodeCache(await SharedPreferences.getInstance());

  group('displayNameFromPlacemark', () {
    test('given a locality and a different administrativeArea, '
        'displayNameFromPlacemark -> "locality, region"', () {
      const placemark = Placemark(
        locality: 'Çeşme',
        administrativeArea: 'İzmir',
      );
      expect(displayNameFromPlacemark(placemark), 'Çeşme, İzmir');
    });

    test('given no locality but a subAdministrativeArea, '
        'displayNameFromPlacemark -> falls back to it as the city', () {
      const placemark = Placemark(
        subAdministrativeArea: 'Çeşme',
        administrativeArea: 'İzmir',
      );
      expect(displayNameFromPlacemark(placemark), 'Çeşme, İzmir');
    });

    test('given the administrativeArea equals the locality, '
        'displayNameFromPlacemark -> the city alone, no duplicate', () {
      const placemark = Placemark(
        locality: 'İzmir',
        administrativeArea: 'İzmir',
      );
      expect(displayNameFromPlacemark(placemark), 'İzmir');
    });

    test('given no city at all but a region, displayNameFromPlacemark -> the '
        'region alone rather than nothing', () {
      const placemark = Placemark(administrativeArea: 'İzmir');
      expect(displayNameFromPlacemark(placemark), 'İzmir');
    });

    test(
      'given every field is null or blank, displayNameFromPlacemark -> null',
      () {
        const placemark = Placemark(locality: '', administrativeArea: null);
        expect(displayNameFromPlacemark(placemark), isNull);
      },
    );
  });

  group('ReverseGeocodingService.resolveName', () {
    test('given the lookup returns a usable placemark (happy path), '
        'resolveName -> the formatted display name', () async {
      final lookup = FakePlacemarkLookup(
        result: const [
          Placemark(locality: 'Çeşme', administrativeArea: 'İzmir'),
        ],
      );
      final service = ReverseGeocodingService(lookup, await cache());

      final result = await service.resolveName(38.3220, 26.3260);

      expect(result, 'Çeşme, İzmir');
      expect(lookup.calls, [(38.3220, 26.3260)]);
    });

    test('given the same grid cell was already resolved (cache hit), '
        'resolveName -> reuses the cached name without calling the lookup '
        'again', () async {
      final lookup = FakePlacemarkLookup(
        result: const [
          Placemark(locality: 'Çeşme', administrativeArea: 'İzmir'),
        ],
      );
      final service = ReverseGeocodingService(lookup, await cache());

      final first = await service.resolveName(38.3220, 26.3260);
      final second = await service.resolveName(38.3221, 26.3261);

      expect(first, 'Çeşme, İzmir');
      expect(second, 'Çeşme, İzmir');
      expect(lookup.calls, hasLength(1));
    });

    test('given the lookup throws (e.g. a PlatformException rate limit), '
        'resolveName -> null, never propagating the exception', () async {
      final lookup = FakePlacemarkLookup(error: Exception('IO_ERROR'));
      final service = ReverseGeocodingService(lookup, await cache());

      final result = await service.resolveName(38.3220, 26.3260);

      expect(result, isNull);
    });

    test('given the lookup returns an empty list (no result), resolveName -> '
        'null', () async {
      final lookup = FakePlacemarkLookup(result: const []);
      final service = ReverseGeocodingService(lookup, await cache());

      final result = await service.resolveName(38.3220, 26.3260);

      expect(result, isNull);
    });

    test('given the lookup returns a placemark with no usable name, '
        'resolveName -> null rather than a fabricated name', () async {
      final lookup = FakePlacemarkLookup(result: const [Placemark()]);
      final service = ReverseGeocodingService(lookup, await cache());

      final result = await service.resolveName(38.3220, 26.3260);

      expect(result, isNull);
    });

    test('given a failed lookup, resolveName -> is retried (not cached) on '
        'the next call for the same cell', () async {
      final lookup = FakePlacemarkLookup(error: Exception('boom'));
      final service = ReverseGeocodingService(lookup, await cache());

      final first = await service.resolveName(38.3220, 26.3260);
      expect(first, isNull);

      lookup.error = null;
      lookup.result = const [
        Placemark(locality: 'Çeşme', administrativeArea: 'İzmir'),
      ];
      final second = await service.resolveName(38.3220, 26.3260);

      expect(second, 'Çeşme, İzmir');
      expect(lookup.calls, hasLength(2));
    });
  });

  group('GeocodingPlacemarkLookup', () {
    test('given the real plugin resolves placemarks, lookup -> forwards the '
        'coordinates and returns them unchanged', () async {
      final platform = _FakeGeocodingPlatform(
        result: const [
          Placemark(locality: 'Çeşme', administrativeArea: 'İzmir'),
        ],
      );
      pi.GeocodingPlatformFactory.instance = _FakeGeocodingPlatformFactory(
        platform,
      );
      final lookup = GeocodingPlacemarkLookup();

      final result = await lookup.lookup(38.3220, 26.3260);

      expect(result, [
        const Placemark(locality: 'Çeşme', administrativeArea: 'İzmir'),
      ]);
      expect(platform.calls, [(38.3220, 26.3260)]);
    });

    test('given the real plugin throws, lookup -> propagates the exception '
        '(the caller, ReverseGeocodingService, is the one that swallows '
        'it)', () async {
      final platform = _FakeGeocodingPlatform(error: Exception('IO_ERROR'));
      pi.GeocodingPlatformFactory.instance = _FakeGeocodingPlatformFactory(
        platform,
      );
      final lookup = GeocodingPlacemarkLookup();

      await expectLater(
        () => lookup.lookup(38.3220, 26.3260),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('buildReverseGeocodingService', () {
    test('given isWeb is true, build -> returns null without constructing the '
        'geocoding plugin (it has no web implementation and would crash the '
        'app before its first frame, per the 2026-10-07 blank-screenshot '
        'regression)', () async {
      final result = buildReverseGeocodingService(
        isWeb: true,
        prefs: await SharedPreferences.getInstance(),
      );

      expect(result, isNull);
    });

    test('given isWeb is false, build -> returns a usable '
        'ReverseGeocodingService backed by the geocoding plugin', () async {
      final platform = _FakeGeocodingPlatform(
        result: const [
          Placemark(locality: 'Çeşme', administrativeArea: 'İzmir'),
        ],
      );
      pi.GeocodingPlatformFactory.instance = _FakeGeocodingPlatformFactory(
        platform,
      );

      final result = buildReverseGeocodingService(
        isWeb: false,
        prefs: await SharedPreferences.getInstance(),
      );

      expect(result, isNotNull);
      expect(await result!.resolveName(38.3220, 26.3260), 'Çeşme, İzmir');
    });
  });
}
