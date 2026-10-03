import 'package:latlong2/latlong.dart';

/// The kind of amenity attached to a [Beach] (see `Beach.amenities`).
enum AmenityKind {
  toilets,
  shower,
  changingRoom,
  parking,
  cafe,
  beachResort,
  lifeguard,
}

/// A single real-world amenity (toilet, shower, cafe, parking spot, beach
/// club or lifeguard post) found near a beach by the Overpass query, with
/// its actual map position — unlike `Beach`'s boolean `has...` flags, which
/// only say whether at least one of a kind exists nearby.
class BeachAmenity {
  const BeachAmenity({required this.kind, required this.position, this.name});

  final AmenityKind kind;
  final LatLng position;

  /// The OSM `name` tag, when the amenity element carries one.
  final String? name;
}
