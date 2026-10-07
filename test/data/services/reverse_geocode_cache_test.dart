import 'package:beachiq/data/services/reverse_geocode_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('ReverseGeocodeCache.get', () {
    test(
      'given nothing cached, get -> runs fetch once and caches the result',
      () async {
        final cache = ReverseGeocodeCache(await prefs());
        var fetchCount = 0;

        final first = await cache.get(
          latitude: 38.3220,
          longitude: 26.3260,
          fetch: () async {
            fetchCount++;
            return 'Çeşme, İzmir';
          },
        );
        final second = await cache.get(
          latitude: 38.3220,
          longitude: 26.3260,
          fetch: () async {
            fetchCount++;
            return 'Çeşme, İzmir';
          },
        );

        expect(fetchCount, 1);
        expect(first, 'Çeşme, İzmir');
        expect(second, 'Çeşme, İzmir');
      },
    );

    test('given a cache hit within the TTL, get -> returns the cached name '
        'without calling fetch', () async {
      final now = DateTime(2026, 1, 1);
      final cache = ReverseGeocodeCache(await prefs(), now: () => now);
      await cache.put(38.3220, 26.3260, 'Çeşme, İzmir');

      final result = await cache.get(
        latitude: 38.3220,
        longitude: 26.3260,
        fetch: () async => fail('fetch should not be called on a hit'),
      );

      expect(result, 'Çeşme, İzmir');
    });

    test('given an entry older than the TTL, get -> treats it as a miss and '
        're-fetches', () async {
      final cache = ReverseGeocodeCache(
        await prefs(),
        now: () => DateTime(2026, 1, 1),
        ttl: const Duration(days: 30),
      );
      await cache.put(38.3220, 26.3260, 'Stale Name');

      final laterCache = ReverseGeocodeCache(
        await prefs(),
        now: () => DateTime(2026, 2, 5), // 35 days later
        ttl: const Duration(days: 30),
      );
      var fetchCount = 0;
      final result = await laterCache.get(
        latitude: 38.3220,
        longitude: 26.3260,
        fetch: () async {
          fetchCount++;
          return 'Fresh Name';
        },
      );

      expect(fetchCount, 1);
      expect(result, 'Fresh Name');
    });

    test('given two coordinates rounding to the same grid cell, get -> shares '
        'one cache entry (no repeated fetch)', () async {
      final cache = ReverseGeocodeCache(await prefs());
      var fetchCount = 0;
      Future<String?> fetch() async {
        fetchCount++;
        return 'Çeşme, İzmir';
      }

      await cache.get(latitude: 38.3220, longitude: 26.3260, fetch: fetch);
      await cache.get(latitude: 38.3223, longitude: 26.3262, fetch: fetch);

      expect(fetchCount, 1);
    });

    test('given fetch resolves to null (a failed lookup), get -> returns null '
        'and never caches it, so the next call retries instead of repeating '
        'the failure forever', () async {
      final cache = ReverseGeocodeCache(await prefs());
      var fetchCount = 0;

      final first = await cache.get(
        latitude: 38.3220,
        longitude: 26.3260,
        fetch: () async {
          fetchCount++;
          return null;
        },
      );
      final second = await cache.get(
        latitude: 38.3220,
        longitude: 26.3260,
        fetch: () async {
          fetchCount++;
          return 'Çeşme, İzmir';
        },
      );

      expect(first, isNull);
      expect(second, 'Çeşme, İzmir');
      expect(fetchCount, 2);
    });

    test('given a corrupt stored entry, get -> treats it as a miss and '
        're-fetches instead of throwing', () async {
      final prefsInstance = await prefs();
      final cache = ReverseGeocodeCache(prefsInstance);
      final key = cache.gridKeyFor(38.3220, 26.3260);
      await prefsInstance.setString(key, 'not valid json');

      final result = await cache.get(
        latitude: 38.3220,
        longitude: 26.3260,
        fetch: () async => 'Çeşme, İzmir',
      );

      expect(result, 'Çeşme, İzmir');
    });
  });
}
