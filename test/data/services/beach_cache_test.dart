import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/services/beach_cache.dart';
import 'package:beachiq/data/static_beaches.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _testBeach = Beach(
  name: 'Test Plajı',
  city: 'Test City',
  latitude: 36.90,
  longitude: 30.65,
);

/// A beach with every [Beach] field set to a non-default value, so a
/// round-trip through [BeachCache] that silently dropped a field would be
/// caught by [_expectSameBeaches].
final _fullyPopulatedBeach = Beach(
  name: 'Full Plajı',
  city: 'Full City',
  latitude: 36.90,
  longitude: 30.65,
  surface: 'sand',
  hasLifeguard: true,
  fee: BeachFee.paid,
  hasShower: true,
  hasToilets: true,
  hasChangingRoom: true,
  hasParking: true,
  hasCafe: true,
  hasBeachResort: true,
  geometry: [LatLng(36.90, 30.65), LatLng(36.91, 30.66)],
);

void _expectSameBeaches(List<Beach> actual, List<Beach> expected) {
  expect(actual.length, expected.length);
  for (var i = 0; i < actual.length; i++) {
    final a = actual[i];
    final e = expected[i];
    expect(a.name, e.name);
    expect(a.city, e.city);
    expect(a.latitude, e.latitude);
    expect(a.longitude, e.longitude);
    expect(a.surface, e.surface);
    expect(a.hasLifeguard, e.hasLifeguard);
    expect(a.fee, e.fee);
    expect(a.hasShower, e.hasShower);
    expect(a.hasToilets, e.hasToilets);
    expect(a.hasChangingRoom, e.hasChangingRoom);
    expect(a.hasParking, e.hasParking);
    expect(a.hasCafe, e.hasCafe);
    expect(a.hasBeachResort, e.hasBeachResort);
    expect(a.geometry, e.geometry);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('BeachCache.get', () {
    test('write then read within TTL returns the cached value without hitting fetch', () async {
      final now = DateTime(2026, 1, 1);
      final cache = BeachCache(await prefs(), now: () => now);

      await cache.put(36.90, 30.65, [_testBeach]);

      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fail('fetch should not be called when a fresh entry is cached');
        },
      );

      _expectSameBeaches(result.beaches, [_testBeach]);
      expect(result.isStale, isFalse);
      expect(result.isFallback, isFalse);
    });

    test('read after TTL expiry reports the entry as stale but still returns last known data', () async {
      var now = DateTime(2026, 1, 1);
      final cache = BeachCache(await prefs(), now: () => now);

      await cache.put(36.90, 30.65, [_testBeach]);

      // Advance the clock past the 7-day TTL.
      now = now.add(const Duration(days: 8));

      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fail('fetch should not be called; staleness is only reported, not auto-refreshed');
        },
      );

      _expectSameBeaches(result.beaches, [_testBeach]);
      expect(result.isStale, isTrue);
      expect(result.isFallback, isFalse);
    });

    test('nothing cached and fetch failing falls back to staticBeaches within a reasonable radius', () async {
      final cache = BeachCache(await prefs(), now: DateTime.now);

      // Close to Konyaaltı Plajı (36.8720, 30.6480) in staticBeaches.
      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async => throw Exception('offline'),
      );

      expect(result.isFallback, isTrue);
      expect(result.beaches, isNotEmpty);
      expect(result.beaches.every((b) => staticBeaches.contains(b)), isTrue);
      expect(result.beaches.any((b) => b.name == 'Konyaaltı Plajı'), isTrue);
    });

    test('caches a successful fetch so a later read within TTL does not fetch again', () async {
      final cache = BeachCache(await prefs(), now: DateTime.now);
      var fetchCount = 0;

      final first = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fetchCount++;
          return [_testBeach];
        },
      );
      final second = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fetchCount++;
          return [_testBeach];
        },
      );

      expect(fetchCount, 1);
      _expectSameBeaches(first.beaches, [_testBeach]);
      _expectSameBeaches(second.beaches, [_testBeach]);
    });
  });

  group('BeachCache.gridKeyFor', () {
    test('two picks within the same 0.25 degree grid cell resolve to the same cache key', () async {
      final cache = BeachCache(await prefs());

      final keyA = cache.gridKeyFor(36.70, 30.50);
      final keyB = cache.gridKeyFor(36.80, 30.60);

      expect(keyA, keyB);
    });

    test('picks in different grid cells resolve to different cache keys', () async {
      final cache = BeachCache(await prefs());

      final keyA = cache.gridKeyFor(36.70, 30.50);
      final keyB = cache.gridKeyFor(38.28, 26.37);

      expect(keyA, isNot(keyB));
    });
  });

  group('BeachCache persistence', () {
    test('a cached entry survives a fresh BeachCache instance backed by the same store', () async {
      final sharedPrefs = await prefs();
      final firstInstance = BeachCache(sharedPrefs);
      await firstInstance.put(36.90, 30.65, [_testBeach]);

      // Simulate an app restart: a brand new BeachCache wrapping the same
      // persistent SharedPreferences instance should still see the entry.
      final secondInstance = BeachCache(sharedPrefs);
      final result = await secondInstance.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fail('fetch should not be called; the entry should have persisted');
        },
      );

      _expectSameBeaches(result.beaches, [_testBeach]);
    });
  });

  group('BeachCache.refresh', () {
    test('overwrites the cache entry with freshly fetched data', () async {
      var now = DateTime(2026, 1, 1);
      final cache = BeachCache(await prefs(), now: () => now);
      await cache.put(36.90, 30.65, [_testBeach]);

      final refreshedBeach = Beach(
        name: 'Refreshed Plajı',
        city: 'Test City',
        latitude: 36.90,
        longitude: 30.65,
      );
      final refreshed = await cache.refresh(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async => [refreshedBeach],
      );

      _expectSameBeaches(refreshed, [refreshedBeach]);

      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async => fail('should not be called; the refreshed entry is fresh'),
      );
      _expectSameBeaches(result.beaches, [refreshedBeach]);
      expect(result.isStale, isFalse);
    });
  });

  group('BeachCache JSON round-trip', () {
    test('every Beach field survives a cache write then read, not just '
        'name/city/lat/lon', () async {
      final cache = BeachCache(await prefs());

      await cache.put(36.90, 30.65, [_fullyPopulatedBeach]);
      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async => fail('fetch should not be called'),
      );

      _expectSameBeaches(result.beaches, [_fullyPopulatedBeach]);
    });

    test('a beach with null surface/hasLifeguard/geometry round-trips as '
        'null, not a default', () async {
      final cache = BeachCache(await prefs());
      final beach = Beach(
        name: 'No Extra Data Plajı',
        city: 'Test City',
        latitude: 36.90,
        longitude: 30.65,
      );

      await cache.put(36.90, 30.65, [beach]);
      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async => fail('fetch should not be called'),
      );

      expect(result.beaches.single.surface, isNull);
      expect(result.beaches.single.hasLifeguard, isNull);
      expect(result.beaches.single.geometry, isNull);
      expect(result.beaches.single.fee, BeachFee.unknown);
    });
  });
}
