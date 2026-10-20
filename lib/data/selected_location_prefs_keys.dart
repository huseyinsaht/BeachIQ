/// `SharedPreferences` keys for the home screen's persisted selected
/// location (lat/lon/display name — see `home_screen.dart`'s
/// `_restoreSelectedLocation`/`_persistSelectedLocation`).
///
/// Promoted out of `home_screen.dart` (where they used to be private to
/// `_HomeScreenState`) so `lib/logic/background_alert_task.dart` (issue
/// #359) can read the same persisted location without duplicating the
/// string literals.
const selectedLocationLatPrefsKey = 'home_selected_location_lat';
const selectedLocationLonPrefsKey = 'home_selected_location_lon';
const selectedLocationNamePrefsKey = 'home_selected_location_name';
