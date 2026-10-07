import 'package:beachiq/data/services/reverse_geocode_cache.dart';
import 'package:beachiq/data/services/reverse_geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_location.dart';

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
}
