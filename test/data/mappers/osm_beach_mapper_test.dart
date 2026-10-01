import 'package:beachiq/data/mappers/osm_beach_mapper.dart';
import 'package:beachiq/data/models/beach.dart';
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
      'tags': {'natural': 'beach', 'name': 'Beach A', 'surface': 'sand', 'fee': 'yes'},
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

    test('falls back to "Unnamed beach" and unknown fee/surface when tags are missing', () {
      final beaches = mapOverpassToBeaches(_rawResponse());
      final beachC = _byApproxLon(beaches, 27.0500);

      expect(beachC.name, 'Unnamed beach');
      expect(beachC.surface, isNull);
      expect(beachC.fee, BeachFee.unknown);
    });

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

    test('does not attach an amenity that is farther than 150m from every beach', () {
      final beaches = mapOverpassToBeaches(_rawResponse());

      expect(beaches.every((b) => !b.hasCafe), isTrue);
    });

    test('ignores elements without natural=beach or a recognized amenity tag', () {
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
    });
  });
}
