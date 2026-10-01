import 'package:latlong2/latlong.dart';

import '../models/beach.dart';

/// Radius (in meters) within which an amenity is considered to belong to a
/// beach. Must match the `around.b:150` radius used in the Overpass query
/// built by `overpass_query_builder.dart`.
const int _amenityAttachRadiusMeters = 150;

/// Distance (in meters) below which two beach ways are considered to be
/// duplicate/adjoining representations of the same physical beach (e.g.
/// because OSM splits a long beach into several adjoining `way`s, or two
/// ways share/nearly-share an endpoint).
const double _adjoiningBeachThresholdMeters = 30;

const Distance _distance = Distance();

/// Turns a raw, decoded Overpass JSON response (as returned by
/// `OverpassService.query`) into a list of [Beach] objects.
///
/// Beach ways/nodes (`natural=beach`) become [Beach]s. Nearby amenity
/// elements (`amenity=shower|toilets|changing_room|parking|cafe`,
/// `emergency=lifeguard`, `leisure=beach_resort`) are attached to the
/// nearest beach within [_amenityAttachRadiusMeters]. Adjoining beach ways
/// that represent the same physical beach are merged into a single [Beach].
List<Beach> mapOverpassToBeaches(Map<String, dynamic> rawResponse) {
  final rawElements = rawResponse['elements'];
  if (rawElements is! List) return [];

  final beachElements = <_OsmElement>[];
  final amenityElements = <_OsmElement>[];

  for (final raw in rawElements) {
    if (raw is! Map) continue;
    final element = _OsmElement.fromJson(raw.cast<String, dynamic>());
    if (element == null) continue;

    if (element.tags['natural'] == 'beach') {
      beachElements.add(element);
    } else if (_amenityKind(element.tags) != null) {
      amenityElements.add(element);
    }
  }

  if (beachElements.isEmpty) return [];

  final groups = _mergeAdjoiningBeaches(beachElements);

  for (final amenity in amenityElements) {
    _attachAmenityToNearestBeach(amenity, groups);
  }

  return groups.map((g) => g.toBeach()).toList();
}

enum _AmenityKind { shower, toilets, changingRoom, parking, cafe, lifeguard, beachResort }

_AmenityKind? _amenityKind(Map<String, dynamic> tags) {
  switch (tags['amenity']) {
    case 'shower':
      return _AmenityKind.shower;
    case 'toilets':
      return _AmenityKind.toilets;
    case 'changing_room':
      return _AmenityKind.changingRoom;
    case 'parking':
      return _AmenityKind.parking;
    case 'cafe':
      return _AmenityKind.cafe;
  }
  if (tags['emergency'] == 'lifeguard') return _AmenityKind.lifeguard;
  if (tags['leisure'] == 'beach_resort') return _AmenityKind.beachResort;
  return null;
}

BeachFee _parseFee(String? raw) {
  switch (raw) {
    case 'yes':
      return BeachFee.paid;
    case 'no':
      return BeachFee.free;
    default:
      return BeachFee.unknown;
  }
}

/// A parsed OSM element (node/way/relation) reduced to what the mapper
/// needs: its tags, a representative point, and (for ways) its full
/// geometry.
class _OsmElement {
  _OsmElement({required this.tags, required this.point, this.geometry});

  final Map<String, dynamic> tags;
  final LatLng point;

  /// Full line/polygon geometry, when the element carries one (Overpass
  /// `out geom`). Null for plain nodes or center-only elements.
  final List<LatLng>? geometry;

  /// The points to use for distance calculations: the full geometry when
  /// available, otherwise just [point].
  List<LatLng> get referencePoints => geometry ?? [point];

  static _OsmElement? fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    List<LatLng>? geometry;
    final rawGeometry = json['geometry'];
    if (rawGeometry is List) {
      final points = <LatLng>[];
      for (final entry in rawGeometry) {
        if (entry is Map && entry['lat'] != null && entry['lon'] != null) {
          points.add(LatLng((entry['lat'] as num).toDouble(), (entry['lon'] as num).toDouble()));
        }
      }
      if (points.isNotEmpty) geometry = points;
    }

    LatLng? point;
    if (json['lat'] != null && json['lon'] != null) {
      point = LatLng((json['lat'] as num).toDouble(), (json['lon'] as num).toDouble());
    } else if (json['center'] is Map) {
      final center = (json['center'] as Map).cast<String, dynamic>();
      if (center['lat'] != null && center['lon'] != null) {
        point = LatLng((center['lat'] as num).toDouble(), (center['lon'] as num).toDouble());
      }
    }
    point ??= geometry != null ? _centroid(geometry) : null;

    if (point == null) return null;
    return _OsmElement(tags: tags, point: point, geometry: geometry);
  }
}

LatLng _centroid(List<LatLng> points) {
  var latSum = 0.0;
  var lonSum = 0.0;
  for (final p in points) {
    latSum += p.latitude;
    lonSum += p.longitude;
  }
  return LatLng(latSum / points.length, lonSum / points.length);
}

double _minDistanceMeters(List<LatLng> a, List<LatLng> b) {
  var min = double.infinity;
  for (final pa in a) {
    for (final pb in b) {
      final d = _distance.as(LengthUnit.Meter, pa, pb);
      if (d < min) min = d;
    }
  }
  return min;
}

double _minDistanceToPoint(LatLng point, List<LatLng> points) {
  var min = double.infinity;
  for (final p in points) {
    final d = _distance.as(LengthUnit.Meter, point, p);
    if (d < min) min = d;
  }
  return min;
}

/// A group of one or more OSM beach elements that have been merged into a
/// single physical beach, plus the amenity flags attached to it.
class _BeachGroup {
  _BeachGroup({
    required this.name,
    required this.city,
    required this.surface,
    required this.fee,
    required this.point,
    required this.referencePoints,
    required this.geometry,
  });

  final String name;
  final String city;
  final String? surface;
  final BeachFee fee;
  final LatLng point;
  final List<LatLng> referencePoints;
  final List<LatLng>? geometry;

  bool? hasLifeguard;
  bool hasShower = false;
  bool hasToilets = false;
  bool hasChangingRoom = false;
  bool hasParking = false;
  bool hasCafe = false;
  bool hasBeachResort = false;

  factory _BeachGroup.fromMembers(List<_OsmElement> members) {
    final allPoints = <LatLng>[for (final m in members) ...m.referencePoints];

    final hasAnyGeometry = members.any((m) => m.geometry != null);
    final combinedGeometry = hasAnyGeometry
        ? <LatLng>[for (final m in members) ...(m.geometry ?? const [])]
        : null;

    return _BeachGroup(
      name: _firstTag(members, 'name') ?? 'Unnamed beach',
      city: _firstTag(members, 'addr:city') ?? '',
      surface: _firstTag(members, 'surface'),
      fee: _parseFee(_firstTag(members, 'fee')),
      point: _centroid(allPoints),
      referencePoints: allPoints,
      geometry: combinedGeometry,
    );
  }

  Beach toBeach() => Beach(
    name: name,
    city: city,
    latitude: point.latitude,
    longitude: point.longitude,
    surface: surface,
    hasLifeguard: hasLifeguard,
    fee: fee,
    hasShower: hasShower,
    hasToilets: hasToilets,
    hasChangingRoom: hasChangingRoom,
    hasParking: hasParking,
    hasCafe: hasCafe,
    hasBeachResort: hasBeachResort,
    geometry: geometry,
  );
}

String? _firstTag(List<_OsmElement> members, String key) {
  for (final m in members) {
    final value = m.tags[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

/// Merges beach ways/nodes that are adjoining (or effectively duplicates)
/// into single groups, using union-find over pairwise minimum distances.
List<_BeachGroup> _mergeAdjoiningBeaches(List<_OsmElement> beachElements) {
  final n = beachElements.length;
  final parent = List.generate(n, (i) => i);

  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  void union(int a, int b) {
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) parent[ra] = rb;
  }

  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final d = _minDistanceMeters(
        beachElements[i].referencePoints,
        beachElements[j].referencePoints,
      );
      if (d <= _adjoiningBeachThresholdMeters) {
        union(i, j);
      }
    }
  }

  final groupedMembers = <int, List<_OsmElement>>{};
  for (var i = 0; i < n; i++) {
    groupedMembers.putIfAbsent(find(i), () => []).add(beachElements[i]);
  }

  return groupedMembers.values.map(_BeachGroup.fromMembers).toList();
}

/// Finds the nearest beach group to [amenity] (by minimum distance to its
/// reference points) and, if within [_amenityAttachRadiusMeters], marks the
/// matching flag on it.
void _attachAmenityToNearestBeach(_OsmElement amenity, List<_BeachGroup> groups) {
  _BeachGroup? nearest;
  var nearestDistance = double.infinity;

  for (final group in groups) {
    final d = _minDistanceToPoint(amenity.point, group.referencePoints);
    if (d < nearestDistance) {
      nearestDistance = d;
      nearest = group;
    }
  }

  if (nearest == null || nearestDistance > _amenityAttachRadiusMeters) return;

  switch (_amenityKind(amenity.tags)) {
    case _AmenityKind.shower:
      nearest.hasShower = true;
    case _AmenityKind.toilets:
      nearest.hasToilets = true;
    case _AmenityKind.changingRoom:
      nearest.hasChangingRoom = true;
    case _AmenityKind.parking:
      nearest.hasParking = true;
    case _AmenityKind.cafe:
      nearest.hasCafe = true;
    case _AmenityKind.lifeguard:
      nearest.hasLifeguard = true;
    case _AmenityKind.beachResort:
      nearest.hasBeachResort = true;
    case null:
      break;
  }
}
