import 'package:geocoding/geocoding.dart';

import 'reverse_geocode_cache.dart';

/// The minimal `geocoding` surface [ReverseGeocodingService] depends on,
/// factored out of the real `Geocoding.placemarkFromCoordinates` method so
/// tests can substitute a fake that never touches a real platform channel
/// (calling the real method outside a running app throws a
/// `MissingPluginException`), mirroring `device_location_service.dart`'s
/// `DeviceLocationSource` pattern. [Placemark] itself is `geocoding`'s own
/// plain, `@immutable` result type — safe to construct directly in a fake
/// or a test.
abstract class PlacemarkLookup {
  Future<List<Placemark>> lookup(double latitude, double longitude);
}

/// Production [PlacemarkLookup], delegating to the real `geocoding`
/// plugin's `Geocoding.placemarkFromCoordinates`.
class GeocodingPlacemarkLookup implements PlacemarkLookup {
  GeocodingPlacemarkLookup([Geocoding? geocoding])
    : _geocoding = geocoding ?? Geocoding();

  final Geocoding _geocoding;

  @override
  Future<List<Placemark>> lookup(double latitude, double longitude) =>
      _geocoding.placemarkFromCoordinates(latitude, longitude);
}

/// Builds a short display name ("locality / sub-administrative area, plus
/// region when useful", per issue #254) from a single reverse-geocoded
/// [Placemark], e.g. `"Çeşme, İzmir"`. Returns `null` when the placemark
/// carries no usable city-level name at all — never a fabricated one; a
/// region with no city still falls back to the region alone rather than
/// nothing, when that's all that's available.
String? displayNameFromPlacemark(Placemark placemark) {
  final city = _firstNonBlank([
    placemark.locality,
    placemark.subAdministrativeArea,
  ]);
  final region = _firstNonBlank([placemark.administrativeArea]);

  if (city == null) return region;
  if (region == null || region == city) return city;
  return '$city, $region';
}

String? _firstNonBlank(List<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// Issue #254's reverse-geocoding lookup, wrapping [PlacemarkLookup] (the
/// real `geocoding` plugin in production) behind a [ReverseGeocodeCache]
/// (grid-cell-keyed, `SharedPreferences`-backed, same idea as
/// `depth_cache.dart`) so the same area is never looked up twice.
///
/// [resolveName] is used both for the "Use my location" device pick and
/// for a plain map tap (replacing `location_map_card.dart`'s coordinate-
/// label fallback, which stays the ultimate fallback for when this
/// returns `null`). Any failure — a `PlatformException` (rate limiting, no
/// Google Play Services), an empty result, or a placemark with no usable
/// name — resolves to `null`, never a made-up name and never a thrown
/// exception, so a caller can always safely fall back to
/// `formatCoordinates`.
class ReverseGeocodingService {
  ReverseGeocodingService(this._lookup, this._cache);

  final PlacemarkLookup _lookup;
  final ReverseGeocodeCache _cache;

  Future<String?> resolveName(double latitude, double longitude) {
    return _cache.get(
      latitude: latitude,
      longitude: longitude,
      fetch: () => _fetch(latitude, longitude),
    );
  }

  Future<String?> _fetch(double latitude, double longitude) async {
    try {
      final placemarks = await _lookup.lookup(latitude, longitude);
      if (placemarks.isEmpty) return null;
      return displayNameFromPlacemark(placemarks.first);
    } catch (_) {
      return null;
    }
  }
}
