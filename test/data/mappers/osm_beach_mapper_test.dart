import 'package:beachiq/data/mappers/osm_beach_mapper.dart';
import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/models/beach_amenity.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small, hand-written Overpass-shaped fixture covering:
///  * beach "A" (way 1) and beach "B" (way 2), whose geometries share a
///    near-identical endpoint (~3m apart) -> should merge into one Beach.
///  * beach "C" (way 3), a separate beach ~4.5km away, with no `name`,
///    `surface` or `fee` tags -> should fall back to "Unnamed beach" and
///    "unknown" fee/surface.
///  * a shower node ~5.5m from beach A -> attaches to the merged A+B beach.
///  * a toilets node and a lifeguard node ~5-12m from beach C -> attach to C.
///  * a cafe node thousands of meters from every beach -> attaches nowhere.
Map<String, dynamic> _rawResponse() => {
  'elements': [
    {
      'type': 'way',
      'id': 1,
      'tags': {
        'natural': 'beach',
        'name': 'Beach A',
        'surface': 'sand',
        'fee': 'yes',
      },
      'geometry': [
        {'lat': 36.0000, 'lon': 27.0000},
        {'lat': 36.0010, 'lon': 27.0000},
      ],
    },
    {
      'type': 'way',
      'id': 2,
      'tags': {'natural': 'beach'},
      'geometry': [
        {'lat': 36.00103, 'lon': 27.0000},
        {'lat': 36.0020, 'lon': 27.0000},
      ],
    },
    {
      'type': 'way',
      'id': 3,
      'tags': {'natural': 'beach'},
      'geometry': [
        {'lat': 36.0000, 'lon': 27.0500},
        {'lat': 36.0002, 'lon': 27.0500},
      ],
    },
    {
      'type': 'node',
      'id': 101,
      'lat': 36.00005,
      'lon': 27.0000,
      'tags': {'amenity': 'shower'},
    },
    {
      'type': 'node',
      'id': 102,
      'lat': 36.00005,
      'lon': 27.0500,
      'tags': {'amenity': 'toilets'},
    },
    {
      'type': 'node',
      'id': 103,
      'lat': 36.00010,
      'lon': 27.05005,
      'tags': {'emergency': 'lifeguard'},
    },
    {
      'type': 'node',
      'id': 104,
      'lat': 36.0000,
      'lon': 27.1000,
      'tags': {'amenity': 'cafe'},
    },
    {
      'type': 'node',
      'id': 105,
      'lat': 36.00012,
      'lon': 27.05004,
      'tags': {'amenity': 'parking', 'name': 'Beach C Car Park'},
    },
  ],
};

Beach _byApproxLon(List<Beach> beaches, double lon) =>
    beaches.firstWhere((b) => (b.longitude - lon).abs() < 0.01);

void main() {
  group('mapOverpassToBeaches', () {
    test('returns an empty list when there are no elements', () {
      expect(mapOverpassToBeaches({'elements': []}), isEmpty);
    });

    test('merges two adjoining beach ways into a single Beach', () {
      final beaches = mapOverpassToBeaches(_rawResponse());

      // Beach A (way 1) + Beach B (way 2) merge; Beach C (way 3) stays
      // separate -> 2 beaches total, not 3.
      expect(beaches, hasLength(2));

      final mergedA = _byApproxLon(beaches, 27.0000);
      expect(mergedA.name, 'Beach A');
      expect(mergedA.surface, 'sand');
      expect(mergedA.fee, BeachFee.paid);
      // The merged geometry carries points from both ways.
      expect(mergedA.geometry, isNotNull);
      expect(mergedA.geometry!.length, 4);
    });

    test(
      'falls back to "Unnamed beach" and unknown fee/surface when tags are missing',
      () {
        final beaches = mapOverpassToBeaches(_rawResponse());
        final beachC = _byApproxLon(beaches, 27.0500);

        expect(beachC.name, 'Unnamed beach');
        expect(beachC.surface, isNull);
        expect(beachC.fee, BeachFee.unknown);
      },
    );

    test('attaches amenities to the nearest beach within 150m', () {
      final beaches = mapOverpassToBeaches(_rawResponse());
      final mergedA = _byApproxLon(beaches, 27.0000);
      final beachC = _byApproxLon(beaches, 27.0500);

      expect(mergedA.hasShower, isTrue);
      expect(mergedA.hasToilets, isFalse);
      expect(mergedA.hasLifeguard, isNull);

      expect(beachC.hasToilets, isTrue);
      expect(beachC.hasLifeguard, isTrue);
      expect(beachC.hasShower, isFalse);
    });

    test(
      'does not attach an amenity that is farther than 150m from every beach',
      () {
        final beaches = mapOverpassToBeaches(_rawResponse());

        expect(beaches.every((b) => !b.hasCafe), isTrue);
      },
    );

    test(
      'fills amenities with the real position and kind of every attached amenity',
      () {
        final beaches = mapOverpassToBeaches(_rawResponse());
        final mergedA = _byApproxLon(beaches, 27.0000);
        final beachC = _byApproxLon(beaches, 27.0500);

        expect(mergedA.amenities, hasLength(1));
        expect(mergedA.amenities.single.kind, AmenityKind.shower);
        expect(
          mergedA.amenities.single.position.latitude,
          closeTo(36.00005, 1e-6),
        );
        expect(
          mergedA.amenities.single.position.longitude,
          closeTo(27.0000, 1e-6),
        );
        expect(mergedA.amenities.single.name, isNull);

        expect(beachC.amenities, hasLength(3));
        expect(
          beachC.amenities.map((a) => a.kind),
          containsAll([
            AmenityKind.toilets,
            AmenityKind.lifeguard,
            AmenityKind.parking,
          ]),
        );
      },
    );

    test('fills the amenity name from the OSM name tag when present', () {
      final beaches = mapOverpassToBeaches(_rawResponse());
      final beachC = _byApproxLon(beaches, 27.0500);

      final parking = beachC.amenities.firstWhere(
        (a) => a.kind == AmenityKind.parking,
      );
      expect(parking.name, 'Beach C Car Park');
    });

    test(
      'a boolean has... flag is true if and only if a matching amenity exists',
      () {
        final beaches = mapOverpassToBeaches(_rawResponse());

        for (final beach in beaches) {
          expect(
            beach.hasShower,
            beach.amenities.any((a) => a.kind == AmenityKind.shower),
          );
          expect(
            beach.hasToilets,
            beach.amenities.any((a) => a.kind == AmenityKind.toilets),
          );
          expect(
            beach.hasParking,
            beach.amenities.any((a) => a.kind == AmenityKind.parking),
          );
        }
      },
    );

    test('prefers the English OSM name (name:en) over the local name', () {
      final beaches = mapOverpassToBeaches({
        'elements': [
          {
            'type': 'way',
            'id': 1,
            'tags': {
              'natural': 'beach',
              'name': 'Ilıca Plajı',
              'name:en': 'Ilica Beach',
            },
            'geometry': [
              {'lat': 10.0, 'lon': 20.0},
              {'lat': 10.001, 'lon': 20.0},
            ],
          },
          {
            'type': 'node',
            'id': 2,
            'lat': 10.00001,
            'lon': 20.0,
            'tags': {
              'amenity': 'cafe',
              'name': 'Plaj Kafe',
              'name:en': 'Beach Cafe',
            },
          },
        ],
      });

      expect(beaches.single.name, 'Ilica Beach');
      expect(beaches.single.amenities.single.name, 'Beach Cafe');
    });

    test('falls back to the local name when there is no name:en', () {
      final beaches = mapOverpassToBeaches({
        'elements': [
          {
            'type': 'way',
            'id': 1,
            'tags': {'natural': 'beach', 'name': 'Local Name Beach'},
            'geometry': [
              {'lat': 10.0, 'lon': 20.0},
              {'lat': 10.001, 'lon': 20.0},
            ],
          },
        ],
      });

      expect(beaches.single.name, 'Local Name Beach');
    });

    test('a beach with no attached amenities has an empty amenities list', () {
      final beaches = mapOverpassToBeaches({
        'elements': [
          {
            'type': 'way',
            'id': 1,
            'tags': {'natural': 'beach', 'name': 'Lonely Beach'},
            'geometry': [
              {'lat': 10.0, 'lon': 20.0},
              {'lat': 10.001, 'lon': 20.0},
            ],
          },
        ],
      });

      expect(beaches.single.amenities, isEmpty);
    });

    test('attaches a changing_room amenity and sets hasChangingRoom', () {
      final beaches = mapOverpassToBeaches({
        'elements': [
          {
            'type': 'way',
            'id': 1,
            'tags': {'natural': 'beach', 'name': 'Changing Room Beach'},
            'geometry': [
              {'lat': 10.0, 'lon': 20.0},
              {'lat': 10.001, 'lon': 20.0},
            ],
          },
          {
            'type': 'node',
            'id': 201,
            'lat': 10.0001,
            'lon': 20.0,
            'tags': {'amenity': 'changing_room'},
          },
        ],
      });

      final beach = beaches.single;
      expect(beach.hasChangingRoom, isTrue);
      expect(beach.amenities.single.kind, AmenityKind.changingRoom);
    });

    test(
      'ignores elements without natural=beach or a recognized amenity tag',
      () {
        final beaches = mapOverpassToBeaches({
          'elements': [
            {
              'type': 'node',
              'id': 999,
              'lat': 36.0,
              'lon': 27.0,
              'tags': {'shop': 'supermarket'},
            },
          ],
        });

        expect(beaches, isEmpty);
      },
    );

    // The next four tests pin the exact boundary of the two distance
    // thresholds (`_adjoiningBeachThresholdMeters` = 30m,
    // `_amenityAttachRadiusMeters` = 150m), per docs/testing.md's "values at
    // a threshold boundary" mandatory edge case. The coordinates are
    // `latlong2`'s own `Distance().offset(origin, metres, 90)` due east of
    // (36.0, 27.0), so the measured distance the mapper computes is exactly
    // 30/31/150/151 meters, not an approximation.
    test(
      'merges two beach nodes exactly at the adjoining threshold (30m apart)',
      () {
        final beaches = mapOverpassToBeaches({
          'elements': [
            {
              'type': 'node',
              'id': 1,
              'lat': 36.0,
              'lon': 27.0,
              'tags': {'natural': 'beach', 'name': 'Beach A'},
            },
            {
              'type': 'node',
              'id': 2,
              'lat': 35.999999999538566,
              'lon': 27.000332728182823,
              'tags': {'natural': 'beach', 'name': 'Beach B'},
            },
          ],
        });

        expect(beaches, hasLength(1));
      },
    );

    test(
      'does not merge two beach nodes just over the adjoining threshold (31m apart)',
      () {
        final beaches = mapOverpassToBeaches({
          'elements': [
            {
              'type': 'node',
              'id': 1,
              'lat': 36.0,
              'lon': 27.0,
              'tags': {'natural': 'beach', 'name': 'Beach A'},
            },
            {
              'type': 'node',
              'id': 2,
              'lat': 35.99999999950729,
              'lon': 27.00034381912225,
              'tags': {'natural': 'beach', 'name': 'Beach B'},
            },
          ],
        });

        expect(beaches, hasLength(2));
      },
    );

    test('attaches an amenity exactly at the attach radius (150m away)', () {
      final beaches = mapOverpassToBeaches({
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': 36.0,
            'lon': 27.0,
            'tags': {'natural': 'beach', 'name': 'Beach A'},
          },
          {
            'type': 'node',
            'id': 101,
            'lat': 35.99999998846403,
            'lon': 27.00166364091396,
            'tags': {'amenity': 'shower'},
          },
        ],
      });

      expect(beaches.single.hasShower, isTrue);
    });

    test(
      'does not attach an amenity just over the attach radius (151m away)',
      () {
        final beaches = mapOverpassToBeaches({
          'elements': [
            {
              'type': 'node',
              'id': 1,
              'lat': 36.0,
              'lon': 27.0,
              'tags': {'natural': 'beach', 'name': 'Beach A'},
            },
            {
              'type': 'node',
              'id': 101,
              'lat': 35.999999988309696,
              'lon': 27.001674731853385,
              'tags': {'amenity': 'shower'},
            },
          ],
        });

        expect(beaches.single.hasShower, isFalse);
      },
    );
  });
}
