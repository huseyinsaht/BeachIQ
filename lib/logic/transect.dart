/// Computes points along a bearing from a start coordinate -- the
/// nearshore depth transect `BathymetryService` (issue #216) samples.
library;

import 'package:latlong2/latlong.dart';

import '../data/models/beach.dart';
import 'wave_shore_relation.dart';

const Distance _distance = Distance();

/// Distances (meters from the shoreline) a nearshore depth transect is
/// sampled at, per issue #216's acceptance criteria. Both
/// [transectPoints] and [seawardTransectFor] default to this.
const List<double> defaultTransectDistancesMeters = [0, 100, 200, 300, 400];

/// Computes points running out from [start] along [bearingDegrees], one
/// per entry in [distancesMeters], in the same order.
///
/// Pure geometry -- no beach-specific logic, no I/O -- built on latlong2's
/// `Distance.offset` (great-circle/Vincenty), the same distance machinery
/// already used elsewhere in this repo (see `beach_cache.dart`'s haversine
/// helper and `wave_shore_relation.dart`'s `Distance.bearing`). Returns an
/// empty list for an empty [distancesMeters] rather than throwing.
///
/// [bearingDegrees] is a compass bearing (degrees clockwise from true
/// north); any value, including negative or >= 360, is accepted since
/// `Distance.offset` normalizes internally.
List<LatLng> transectPoints({
  required LatLng start,
  required double bearingDegrees,
  List<double> distancesMeters = defaultTransectDistancesMeters,
}) {
  return [
    for (final distanceMeters in distancesMeters)
      _distance.offset(start, distanceMeters, bearingDegrees),
  ];
}

/// Builds a beach's seaward depth transect: points running out from its
/// shoreline (its OSM geometry's centroid) along its seaward bearing (see
/// [seawardBearingFromGeometry]), at [distancesMeters].
///
/// Returns `null` -- never a guessed direction, and never a transect
/// anchored at a made-up point -- when [beach] has no geometry, or when
/// [seawardBearingFromGeometry] itself cannot determine a seaward bearing
/// (no amenities to anchor the heuristic, or the anchor points are too
/// close together; see that function's own doc comment). No beach geometry
/// means no transect.
List<LatLng>? seawardTransectFor(
  Beach beach, {
  List<double> distancesMeters = defaultTransectDistancesMeters,
}) {
  final geometry = beach.geometry;
  if (geometry == null || geometry.isEmpty) return null;

  final bearingDegrees = seawardBearingFromGeometry(beach);
  if (bearingDegrees == null) return null;

  final shorePoint = _centroid(geometry);
  return transectPoints(
    start: shorePoint,
    bearingDegrees: bearingDegrees,
    distancesMeters: distancesMeters,
  );
}

LatLng _centroid(List<LatLng> points) {
  var latSum = 0.0;
  var lonSum = 0.0;
  for (final point in points) {
    latSum += point.latitude;
    lonSum += point.longitude;
  }
  return LatLng(latSum / points.length, lonSum / points.length);
}
