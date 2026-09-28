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
  });
}
