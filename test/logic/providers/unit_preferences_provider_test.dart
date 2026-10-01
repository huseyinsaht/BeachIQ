import 'package:beachiq/logic/providers/unit_preferences_provider.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('UnitPreferencesProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to metric when nothing is persisted', () async {
      final provider = UnitPreferencesProvider(await prefs());
      expect(provider.unitSystem, UnitSystem.metric);
    });

    test('loads a persisted imperial value on construction', () async {
      SharedPreferences.setMockInitialValues({'unit_system': 'imperial'});
      final provider = UnitPreferencesProvider(await prefs());
      expect(provider.unitSystem, UnitSystem.imperial);
    });

    test('an unrecognized persisted value falls back to metric', () async {
      SharedPreferences.setMockInitialValues({'unit_system': 'garbage'});
      final provider = UnitPreferencesProvider(await prefs());
      expect(provider.unitSystem, UnitSystem.metric);
    });

    test('setUnitSystem persists the choice and notifies listeners', () async {
      final preferences = await prefs();
      final provider = UnitPreferencesProvider(preferences);
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.setUnitSystem(UnitSystem.imperial);

      expect(provider.unitSystem, UnitSystem.imperial);
      expect(notified, isTrue);
      expect(preferences.getString('unit_system'), 'imperial');
    });

    test('setUnitSystem to the current value is a no-op', () async {
      final provider = UnitPreferencesProvider(await prefs());
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setUnitSystem(UnitSystem.metric);

      expect(notifyCount, 0);
    });

    test('toggle switches between metric and imperial', () async {
      final provider = UnitPreferencesProvider(await prefs());

      await provider.toggle();
      expect(provider.unitSystem, UnitSystem.imperial);

      await provider.toggle();
      expect(provider.unitSystem, UnitSystem.metric);
    });

    test('a value persisted by one instance is read by a new instance', () async {
      final preferences = await prefs();
      final first = UnitPreferencesProvider(preferences);
      await first.toggle();

      final second = UnitPreferencesProvider(preferences);
      expect(second.unitSystem, UnitSystem.imperial);
    });
  });
}
