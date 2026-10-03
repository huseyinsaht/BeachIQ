import 'package:beachiq/data/models/place.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Place.tryFromJson', () {
    test('parses all fields', () {
      final place = Place.tryFromJson({
        'name': 'Çeşme',
        'admin1': 'İzmir',
        'country': 'Turkey',
        'latitude': 38.3220,
        'longitude': 26.3260,
      });

      expect(place, isNotNull);
      expect(place!.name, 'Çeşme');
      expect(place.admin1, 'İzmir');
      expect(place.country, 'Turkey');
      expect(place.latitude, 38.3220);
      expect(place.longitude, 26.3260);
    });

    test('admin1 and country default to null when absent', () {
      final place = Place.tryFromJson({
        'name': 'Çeşme',
        'latitude': 38.3220,
        'longitude': 26.3260,
      });

      expect(place, isNotNull);
      expect(place!.admin1, isNull);
      expect(place.country, isNull);
    });

    test('returns null when name is missing', () {
      final place = Place.tryFromJson({'latitude': 38.3, 'longitude': 26.3});
      expect(place, isNull);
    });

    test('returns null when latitude/longitude are missing or not numeric', () {
      expect(
        Place.tryFromJson({'name': 'Çeşme', 'longitude': 26.3}),
        isNull,
      );
      expect(
        Place.tryFromJson({
          'name': 'Çeşme',
          'latitude': 'not a number',
          'longitude': 26.3,
        }),
        isNull,
      );
    });
  });
}
