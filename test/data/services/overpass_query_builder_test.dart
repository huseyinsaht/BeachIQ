import 'package:beachiq/data/services/overpass_query_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildNearbyBeachesQuery', () {
    test('produces the exact expected query for a fixed point', () {
      final query = buildNearbyBeachesQuery(38.3, 26.3);

      expect(
        query,
        '[out:json][timeout:25];\n'
        'nwr[natural=beach](around:20000,38.300000,26.300000)->.b;\n'
        '.b out geom;\n'
        '(\n'
        '  nwr(around.b:150)[amenity~"^(shower|toilets|changing_room|parking|cafe)\$"];\n'
        '  nwr(around.b:150)[emergency=lifeguard];\n'
        '  nwr(around.b:150)[leisure=beach_resort];\n'
        ');\n'
        'out center tags;\n',
      );
    });

    test('reflects a custom radiusMeters in the beach search radius', () {
      final query = buildNearbyBeachesQuery(38.3, 26.3, radiusMeters: 5000);

      expect(query, contains('nwr[natural=beach](around:5000,38.300000,26.300000)->.b;'));
    });

    test('does not select amenities with a bare, unvalued tag filter', () {
      final query = buildNearbyBeachesQuery(38.3, 26.3);

      expect(query, isNot(contains('[amenity];')));
      expect(query, isNot(matches(RegExp(r'\[amenity\]\s*;'))));
    });
  });
}
