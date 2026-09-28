import 'package:beachiq/data/models/beach.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
