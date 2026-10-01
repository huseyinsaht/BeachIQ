import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/logic/providers/favorites_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _alacati = Beach(
  name: 'Alaçatı Plajı',
  city: 'İzmir',
  latitude: 38.2820,
  longitude: 26.3710,
);
final _patara = Beach(
  name: 'Patara Plajı',
  city: 'Antalya',
  latitude: 36.2650,
  longitude: 29.3160,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('FavoritesProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts with nothing favorited when nothing is persisted', () async {
      final provider = FavoritesProvider(await prefs());

      expect(provider.isFavorite(_alacati), isFalse);
      expect(provider.favoritesAmong([_alacati, _patara]), isEmpty);
    });

    test('toggleFavorite marks a beach as a favorite and notifies', () async {
      final provider = FavoritesProvider(await prefs());
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.toggleFavorite(_alacati);

      expect(provider.isFavorite(_alacati), isTrue);
      expect(provider.isFavorite(_patara), isFalse);
      expect(notified, isTrue);
    });

    test('toggling a favorite again removes it', () async {
      final provider = FavoritesProvider(await prefs());

      await provider.toggleFavorite(_alacati);
      await provider.toggleFavorite(_alacati);

      expect(provider.isFavorite(_alacati), isFalse);
    });

    test('favoritesAmong returns only the favorited beaches, in order', () async {
      final provider = FavoritesProvider(await prefs());

      await provider.toggleFavorite(_patara);

      expect(provider.favoritesAmong([_alacati, _patara]), [_patara]);
    });

    test('a favorite persisted by one instance is read by a new instance', () async {
      final preferences = await prefs();
      final first = FavoritesProvider(preferences);
      await first.toggleFavorite(_alacati);

      final second = FavoritesProvider(preferences);

      expect(second.isFavorite(_alacati), isTrue);
    });

    test(
      'two beaches with the same name but a different city are distinct',
      () async {
        final provider = FavoritesProvider(await prefs());
        final otherCity = Beach(
          name: _alacati.name,
          city: 'Different City',
          latitude: 0,
          longitude: 0,
        );

        await provider.toggleFavorite(_alacati);

        expect(provider.isFavorite(_alacati), isTrue);
        expect(provider.isFavorite(otherCity), isFalse);
      },
    );
  });
}
