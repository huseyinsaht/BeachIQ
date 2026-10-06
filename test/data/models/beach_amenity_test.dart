import 'package:beachiq/data/models/beach_amenity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('BeachAmenity', () {
    group('name', () {
      test('given no name is passed, name -> is null', () {
        const amenity = BeachAmenity(
          kind: AmenityKind.toilets,
          position: LatLng(38.3, 26.3),
        );

        expect(amenity.name, isNull);
      });

      test('given a name is passed, name -> carries it unchanged', () {
        const amenity = BeachAmenity(
          kind: AmenityKind.cafe,
          position: LatLng(38.3, 26.3),
          name: 'Beach Cafe',
        );

        expect(amenity.name, 'Beach Cafe');
      });
    });

    group('kind and position', () {
      test('given a kind and a position, BeachAmenity -> carries both '
          'unchanged', () {
        const position = LatLng(36.8, 27.6);
        const amenity = BeachAmenity(
          kind: AmenityKind.lifeguard,
          position: position,
        );

        expect(amenity.kind, AmenityKind.lifeguard);
        expect(amenity.position, position);
      });

      test('AmenityKind -> has exactly the kinds the Overpass mapper and '
          'legend rely on', () {
        expect(AmenityKind.values, [
          AmenityKind.toilets,
          AmenityKind.shower,
          AmenityKind.changingRoom,
          AmenityKind.parking,
          AmenityKind.cafe,
          AmenityKind.beachResort,
          AmenityKind.lifeguard,
        ]);
      });
    });
  });
}
