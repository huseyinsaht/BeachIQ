import 'package:beachiq/data/models/beach.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Beach', () {
    test('stores name, city, latitude and longitude', () {
      final beach = Beach(
        name: 'Alaçatı',
        city: 'İzmir',
        latitude: 38.28,
        longitude: 26.37,
      );

      expect(beach.name, 'Alaçatı');
      expect(beach.city, 'İzmir');
      expect(beach.latitude, 38.28);
      expect(beach.longitude, 26.37);
    });

    test('defaults the OSM-derived fields when not provided', () {
      final beach = Beach(
        name: 'Alaçatı',
        city: 'İzmir',
        latitude: 38.28,
        longitude: 26.37,
      );

      expect(beach.surface, isNull);
      expect(beach.hasLifeguard, isNull);
      expect(beach.fee, BeachFee.unknown);
      expect(beach.hasShower, isFalse);
      expect(beach.hasToilets, isFalse);
      expect(beach.hasChangingRoom, isFalse);
      expect(beach.hasParking, isFalse);
      expect(beach.hasCafe, isFalse);
      expect(beach.hasBeachResort, isFalse);
      expect(beach.geometry, isNull);
    });

    test('stores the OSM-derived fields when provided', () {
      final geometry = [
        const LatLng(38.28, 26.37),
        const LatLng(38.281, 26.371),
      ];

      final beach = Beach(
        name: 'Alaçatı',
        city: 'İzmir',
        latitude: 38.28,
        longitude: 26.37,
        surface: 'sand',
        hasLifeguard: true,
        fee: BeachFee.paid,
        hasShower: true,
        hasToilets: true,
        hasChangingRoom: true,
        hasParking: true,
        hasCafe: true,
        hasBeachResort: true,
        geometry: geometry,
      );

      expect(beach.surface, 'sand');
      expect(beach.hasLifeguard, isTrue);
      expect(beach.fee, BeachFee.paid);
      expect(beach.hasShower, isTrue);
      expect(beach.hasToilets, isTrue);
      expect(beach.hasChangingRoom, isTrue);
      expect(beach.hasParking, isTrue);
      expect(beach.hasCafe, isTrue);
      expect(beach.hasBeachResort, isTrue);
      expect(beach.geometry, geometry);
    });

    test('BeachFee has free, paid and unknown values', () {
      expect(BeachFee.values, [BeachFee.free, BeachFee.paid, BeachFee.unknown]);
    });
  });

  group('isSameBeach (#214)', () {
    Beach beach({
      String name = 'Fixture Beach',
      double lat = 38.3,
      double lon = 26.3,
    }) {
      return Beach(name: name, city: 'Cesme', latitude: lat, longitude: lon);
    }

    test('given the same name and coordinates on different instances -> '
        'true', () {
      final a = beach();
      final b = beach();

      expect(isSameBeach(a, b), isTrue);
      expect(identical(a, b), isFalse);
    });

    test('an instance is the same beach as itself', () {
      final a = beach();

      expect(isSameBeach(a, a), isTrue);
    });

    test('given a different name -> false', () {
      expect(isSameBeach(beach(), beach(name: 'Other Beach')), isFalse);
    });

    test('given a different latitude -> false', () {
      expect(isSameBeach(beach(), beach(lat: 38.4)), isFalse);
    });

    test('given a different longitude -> false', () {
      expect(isSameBeach(beach(), beach(lon: 26.4)), isFalse);
    });

    test('given null -> false', () {
      expect(isSameBeach(beach(), null), isFalse);
    });
  });
}
