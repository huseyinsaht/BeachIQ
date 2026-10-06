import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/data/services/depth_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0, depthMeters: 0.3),
    DepthSample(distanceMeters: 100, depthMeters: 1.0),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('DepthCache.get', () {
    test('given nothing cached, get -> runs fetch and caches an available '
        'result', () async {
      final cache = DepthCache(await prefs());
      var fetchCount = 0;

      final first = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fetchCount++;
          return _profile;
        },
      );
      final second = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fetchCount++;
          return _profile;
        },
      );

      expect(fetchCount, 1);
      expect(first.samples.length, _profile.samples.length);
      expect(second.samples.length, _profile.samples.length);
    });

    test('given a cache hit within the 90-day TTL, get -> returns the cached '
        'profile without calling fetch', () async {
      final now = DateTime(2026, 1, 1);
      final cache = DepthCache(await prefs(), now: () => now);
      await cache.put(36.90, 30.65, _profile);

      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fail('fetch should not be called when a fresh entry is cached');
        },
      );

      expect(result.available, isTrue);
      expect(
        result.samples.map((s) => s.depthMeters).toList(),
        _profile.samples.map((s) => s.depthMeters).toList(),
      );
    });

    test('given a cache entry older than 90 days, get -> treats it as a miss '
        'and runs fetch again', () async {
      var now = DateTime(2026, 1, 1);
      final cache = DepthCache(await prefs(), now: () => now);
      await cache.put(36.90, 30.65, _profile);

      now = now.add(const Duration(days: 91));
      var fetchCalled = false;
      const refreshed = DepthProfile(
        available: true,
        samples: [DepthSample(distanceMeters: 0, depthMeters: 0.5)],
      );

      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fetchCalled = true;
          return refreshed;
        },
      );

      expect(fetchCalled, isTrue);
      expect(result.samples.single.depthMeters, 0.5);
    });

    test('given a cache entry exactly at the 90-day TTL boundary, get -> is '
        'still considered fresh', () async {
      var now = DateTime(2026, 1, 1);
      final cache = DepthCache(await prefs(), now: () => now);
      await cache.put(36.90, 30.65, _profile);

      now = now.add(const Duration(days: 90));

      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async =>
            fail('fetch should not be called exactly at the TTL boundary'),
      );

      expect(result.available, isTrue);
    });

    test(
      'given fetch returns an unavailable result, get -> does not cache it '
      '(a later call retries fetch instead of replaying the failure)',
      () async {
        final cache = DepthCache(await prefs());
        var fetchCount = 0;

        await cache.get(
          latitude: 36.90,
          longitude: 30.65,
          fetch: () async {
            fetchCount++;
            return const DepthProfile.unavailable();
          },
        );
        await cache.get(
          latitude: 36.90,
          longitude: 30.65,
          fetch: () async {
            fetchCount++;
            return const DepthProfile.unavailable();
          },
        );

        expect(fetchCount, 2);
      },
    );
  });

  group('DepthCache.gridKeyFor (rounding)', () {
    test('given two positions within the same grid cell, gridKeyFor -> '
        'resolves to the same cache key', () async {
      final cache = DepthCache(await prefs());

      final keyA = cache.gridKeyFor(36.9001, 30.6501);
      final keyB = cache.gridKeyFor(36.9004, 30.6503);

      expect(keyA, keyB);
    });

    test('given positions in different grid cells, gridKeyFor -> resolves to '
        'different cache keys', () async {
      final cache = DepthCache(await prefs());

      final keyA = cache.gridKeyFor(36.90, 30.65);
      final keyB = cache.gridKeyFor(38.28, 26.37);

      expect(keyA, isNot(keyB));
    });

    test('given a rounded position, a cache written for one coordinate -> is '
        'read back for a nearby coordinate in the same grid cell', () async {
      final cache = DepthCache(await prefs());
      await cache.put(36.9001, 30.6501, _profile);

      final result = await cache.get(
        latitude: 36.9004,
        longitude: 30.6503,
        fetch: () async => fail('fetch should not be called; same cell'),
      );

      expect(result.available, isTrue);
    });
  });

  group('DepthCache persistence and corrupt entries', () {
    test('given a fresh DepthCache instance over the same SharedPreferences, '
        'get -> still sees an entry written by an earlier instance', () async {
      final sharedPrefs = await prefs();
      final firstInstance = DepthCache(sharedPrefs);
      await firstInstance.put(36.90, 30.65, _profile);

      final secondInstance = DepthCache(sharedPrefs);
      final result = await secondInstance.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async => fail('fetch should not be called'),
      );

      expect(result.available, isTrue);
    });

    test('given a corrupt cache entry, get -> treats it as a miss instead of '
        'throwing', () async {
      final sharedPrefs = await prefs();
      final cache = DepthCache(sharedPrefs);
      final key = cache.gridKeyFor(36.90, 30.65);
      await sharedPrefs.setString(key, 'not valid json {');

      var fetchCalled = false;
      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async {
          fetchCalled = true;
          return _profile;
        },
      );

      expect(fetchCalled, isTrue);
      expect(result.available, isTrue);
    });

    test('given a profile with a null depth sample, the cache round-trip -> '
        'preserves the null rather than turning it into 0', () async {
      final cache = DepthCache(await prefs());
      const withNull = DepthProfile(
        available: true,
        samples: [
          DepthSample(distanceMeters: 0, depthMeters: null),
          DepthSample(distanceMeters: 100, depthMeters: 1.2),
        ],
      );
      await cache.put(36.90, 30.65, withNull);

      final result = await cache.get(
        latitude: 36.90,
        longitude: 30.65,
        fetch: () async => fail('fetch should not be called'),
      );

      expect(result.samples.first.depthMeters, isNull);
      expect(result.samples.last.depthMeters, 1.2);
    });
  });
}
