/// Classifies a compass bearing (current or wave) relative to a beach's
/// shore: does the water move toward the beach, away from it (drift-out /
/// rip-current risk), or roughly parallel to it?
///
/// Despite the file name (kept for issue #164's history), this is a general
/// shore-relation classifier used for *both* the ocean current direction
/// (primary, per the issue's 2026-10-01 update) and the wave direction
/// (secondary) — see [classifyDirection]'s `convention` parameter.
library;

import 'package:latlong2/latlong.dart';

import '../data/models/beach.dart';

const Distance _distance = Distance();

/// Below this separation (in meters) between a [Beach]'s geometry centroid
/// and its amenities' average position, [seawardBearingFromGeometry] treats
/// the two points as effectively coincident and returns null rather than a
/// meaningless/unstable bearing between two near-identical points.
const double _minAnchorSeparationMeters = 1;

/// Derives a beach's seaward-pointing bearing (degrees clockwise from true
/// north, suitable as [classifyDirection]'s `seawardBearingDegrees`) from
/// its OSM-sourced [Beach.geometry] and [Beach.amenities].
///
/// **This is a heuristic approximation, not ground truth** — OSM's
/// `natural=beach` ways carry no tag for which side faces open water, so
/// there is no way to read the true seaward direction directly off the
/// geometry. Instead this assumes land-side amenities (parking, cafés,
/// showers, etc. — see `beach_amenity.dart`) cluster on the landward side,
/// a reasonable but imperfect proxy: it takes the bearing from the
/// amenities' average position toward the beach geometry's centroid, i.e.
/// "away from where the amenities cluster", as the seaward direction. A
/// beach with amenities spread unevenly around it (e.g. on a headland), or
/// with amenities that happen to sit seaward of the sand (rare, but
/// possible for a pier-mounted cafe), will get a wrong bearing from this
/// heuristic.
///
/// Returns null — never a fabricated/guessed bearing — when [beach] has no
/// geometry, no amenities to anchor the heuristic, or when its geometry
/// centroid and amenity average are too close together
/// ([_minAnchorSeparationMeters]) to yield a stable direction.
double? seawardBearingFromGeometry(Beach beach) {
  final geometry = beach.geometry;
  if (geometry == null || geometry.isEmpty) return null;
  if (beach.amenities.isEmpty) return null;

  final geometryCentroid = _average(geometry);
  final amenityAverage = _average([
    for (final a in beach.amenities) a.position,
  ]);

  if (_distance.as(LengthUnit.Meter, amenityAverage, geometryCentroid) <
      _minAnchorSeparationMeters) {
    return null;
  }

  return _distance.bearing(amenityAverage, geometryCentroid);
}

LatLng _average(List<LatLng> points) {
  var latSum = 0.0;
  var lonSum = 0.0;
  for (final p in points) {
    latSum += p.latitude;
    lonSum += p.longitude;
  }
  return LatLng(latSum / points.length, lonSum / points.length);
}

/// The two bearing conventions [SeaCondition] documents for its direction
/// fields (see its doc comments on `waveDirection`/`currentDirection` for
/// the authoritative explanation) — [classifyDirection] needs to know which
/// one it was given so it can recover the actual direction of travel before
/// comparing it against the shore.
enum DirectionConvention {
  /// Oceanographic "flowing toward" convention (ocean current direction):
  /// the bearing already *is* the direction of travel.
  flowingToward,

  /// Meteorological "coming from" convention (wave/wind direction): the
  /// bearing is where the wave originates, so the actual direction of
  /// travel is the opposite of it (bearing + 180°).
  comingFrom,
}

/// How a current's or wave's direction of travel relates to a beach's
/// shore.
enum ShoreRelation {
  /// Moving toward the beach (the opposite of the shore's seaward normal).
  towardShore,

  /// Moving away from the beach, out to sea (aligned with the shore's
  /// seaward normal) — flag this visually: it signals drift-out /
  /// rip-current risk for anyone swimming.
  awayFromShore,

  /// Moving roughly parallel to the shoreline — neither toward nor away.
  alongShore,
}

/// How many degrees either side of the shore-normal (the line
/// perpendicular to the shore, pointing straight out to sea) a direction of
/// travel must fall within to count as "toward" or "away" from shore,
/// rather than "along" it.
///
/// A direction of travel within [shoreRelationThresholdDegrees] of the
/// seaward normal is [ShoreRelation.awayFromShore]; within the same
/// threshold of the *landward* normal (the seaward normal + 180°) is
/// [ShoreRelation.towardShore]; everything else — the remaining
/// `180 - 2 * shoreRelationThresholdDegrees` degrees, split evenly either
/// side of the shoreline itself — is [ShoreRelation.alongShore].
///
/// 45° means "toward"/"away" together cover a full half of the compass
/// (two 90°-wide cones centered on the shore-normal and its reciprocal),
/// leaving the other half (two 90°-wide cones straddling the shoreline
/// itself) as "along shore".
const double shoreRelationThresholdDegrees = 45;

/// Classifies [degrees] (a compass bearing in [convention]'s convention)
/// relative to a shore whose seaward-pointing normal is
/// [seawardBearingDegrees] (also degrees clockwise from true north, pointing
/// from the beach straight out to open water).
///
/// All three bearing inputs accept any `double`, including negative values
/// or values at/above 360° (e.g. comparing 350° against 10° must resolve as
/// a 20° difference, not a 340° one) — this function normalizes internally,
/// so callers never need to pre-clamp a bearing into `[0, 360)`.
ShoreRelation classifyDirection({
  required double degrees,
  required DirectionConvention convention,
  required double seawardBearingDegrees,
}) {
  // Recover the actual direction of travel: "coming from" bearings point the
  // opposite way from where the water is headed.
  final travelBearingDegrees = convention == DirectionConvention.comingFrom
      ? degrees + 180
      : degrees;

  final differenceFromSeawardDegrees = _angularDifferenceDegrees(
    travelBearingDegrees,
    seawardBearingDegrees,
  );

  if (differenceFromSeawardDegrees <= shoreRelationThresholdDegrees) {
    return ShoreRelation.awayFromShore;
  }
  if (differenceFromSeawardDegrees >= 180 - shoreRelationThresholdDegrees) {
    return ShoreRelation.towardShore;
  }
  return ShoreRelation.alongShore;
}

/// The smallest angle between two compass bearings, in `[0, 180]` degrees,
/// handling wrap-around (e.g. 350° vs 10° is a 20° difference, not 340°) and
/// any input outside `[0, 360)`.
double _angularDifferenceDegrees(double a, double b) {
  final rawDifference = (a - b) % 360;
  final normalized = (rawDifference + 360) % 360; // now in [0, 360)
  return normalized > 180 ? 360 - normalized : normalized;
}
