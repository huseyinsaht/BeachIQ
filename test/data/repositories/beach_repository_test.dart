import 'package:beachiq/data/repositories/beach_repository.dart';
import 'package:beachiq/data/static_beaches.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeachRepository.getBeaches', () {
    test('returns the static beach list', () async {
      final repository = BeachRepository();

      final beaches = await repository.getBeaches();

      expect(beaches, staticBeaches);
    });

    test('returns the same number of beaches as the static list', () async {
      final repository = BeachRepository();

      final beaches = await repository.getBeaches();

      expect(beaches.length, staticBeaches.length);
    });
  });
}
