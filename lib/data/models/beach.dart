import 'package:latlong2/latlong.dart';

import 'beach_amenity.dart';

/// Whether a beach charges an entry fee, as tagged in OSM (`fee=yes`/`no`).
///
/// [unknown] is used whenever OSM has no `fee` tag at all, so it is never
/// confused with an explicit "no fee" ([free]).
enum BeachFee { free, paid, unknown }

class Beach {
  final String name;
  final String city;
  final double latitude;
  final double longitude;

  /// The ground surface of the beach (OSM `surface` tag), e.g. `sand`,
  /// `gravel`, `pebbles`. Null when OSM has no `surface` tag.
  final String? surface;

  /// Whether a lifeguard (OSM `emergency=lifeguard`) was found near this
  /// beach. Null when no such amenity was found nearby, as OSM has no way
  /// to positively assert the absence of a lifeguard.
  final bool? hasLifeguard;

  /// Whether entry to the beach is paid, free, or unknown (see [BeachFee]).
  final BeachFee fee;

  /// Amenities found near the beach (OSM `amenity`/`leisure` tags). These
  /// default to `false` when nothing was found nearby.
  final bool hasShower;
  final bool hasToilets;
  final bool hasChangingRoom;
  final bool hasParking;
  final bool hasCafe;
  final bool hasBeachResort;

  /// The beach's polygon/line geometry (a list of lat/lon points), when
  /// known. Null when no geometry is available.
  final List<LatLng>? geometry;

  /// Amenities (toilets, showers, cafes, parking, beach clubs, lifeguard
  /// posts) found near this beach, each with its own real map position.
  /// Empty by default, including for a cache entry written before this
  /// field existed. A flag above being `true` always means at least one
  /// amenity of that kind is present here (see `osm_beach_mapper.dart`).
  final List<BeachAmenity> amenities;

  Beach({
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.surface,
    this.hasLifeguard,
    this.fee = BeachFee.unknown,
    this.hasShower = false,
    this.hasToilets = false,
    this.hasChangingRoom = false,
    this.hasParking = false,
    this.hasCafe = false,
    this.hasBeachResort = false,
    this.geometry,
    this.amenities = const [],
  });
}
