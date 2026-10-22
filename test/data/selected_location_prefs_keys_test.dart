import 'package:beachiq/data/selected_location_prefs_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('selected_location_prefs_keys', () {
    test('given the persisted selected-location keys, values -> stay the exact '
        'strings existing installs already have persisted', () {
      // These are SharedPreferences keys written by home_screen.dart and
      // read back by both home_screen.dart and background_alert_task.dart
      // (issue #359). Changing a value here would silently orphan the
      // location already persisted on a user's device, since the old key
      // would no longer be read.
      expect(selectedLocationLatPrefsKey, 'home_selected_location_lat');
      expect(selectedLocationLonPrefsKey, 'home_selected_location_lon');
      expect(selectedLocationNamePrefsKey, 'home_selected_location_name');
    });

    test('given the three persisted keys, they -> are pairwise distinct', () {
      final keys = {
        selectedLocationLatPrefsKey,
        selectedLocationLonPrefsKey,
        selectedLocationNamePrefsKey,
      };

      expect(keys, hasLength(3));
    });
  });
}
