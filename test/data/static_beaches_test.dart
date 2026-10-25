import 'package:beachiq/data/static_beaches.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('staticBeaches', () {
    test('contains between 8 and 10 beaches', () {
      expect(staticBeaches.length, inInclusiveRange(8, 10));
    });

    test('every beach has a non-empty name, city and coordinates', () {
      for (final beach in staticBeaches) {
        expect(beach.name, isNotEmpty);
        expect(beach.city, isNotEmpty);
        expect(beach.latitude, isNot(0));
        expect(beach.longitude, isNot(0));
      }
    });

    test('beach names are unique', () {
      final names = staticBeaches.map((beach) => beach.name).toSet();
      expect(names.length, staticBeaches.length);
    });

    test('every beach sits within mainland Turkey\'s bounding box', () {
      // All entries are hand-typed Turkish beaches; a transposed or
      // mistyped coordinate would still be non-zero (the existing check
      // above) but would place the beach outside the country entirely.
      for (final beach in staticBeaches) {
        expect(
          beach.latitude,
          inInclusiveRange(35.8, 42.1),
          reason:
              '${beach.name} latitude ${beach.latitude} is outside '
              "mainland Turkey's bounding box",
        );
        expect(
          beach.longitude,
          inInclusiveRange(25.6, 44.8),
          reason:
              '${beach.name} longitude ${beach.longitude} is outside '
              "mainland Turkey's bounding box",
        );
      }
    });

    test('no two beaches share the same coordinates', () {
      final coordinates = staticBeaches
          .map((beach) => (beach.latitude, beach.longitude))
          .toSet();
      expect(coordinates.length, staticBeaches.length);
    });
  });
}
