/// A place result from [GeocodingService], e.g. for picking a map
/// location by name instead of tapping the map.
class Place {
  final String name;

  /// First-level administrative region (state/province), when the API
  /// returns one.
  final String? admin1;

  final String? country;
  final double latitude;
  final double longitude;

  Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.admin1,
    this.country,
  });

  /// Parses a single Open-Meteo geocoding result entry, returning `null`
  /// for an entry missing the fields a [Place] cannot do without (`name`,
  /// `latitude`, `longitude`) instead of throwing, so one malformed entry
  /// does not fail the whole search.
  static Place? tryFromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (name is! String || latitude is! num || longitude is! num) {
      return null;
    }
    final admin1 = json['admin1'];
    final country = json['country'];
    return Place(
      name: name,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      admin1: admin1 is String ? admin1 : null,
      country: country is String ? country : null,
    );
  }
}
