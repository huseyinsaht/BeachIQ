/// Classifies a compass bearing (current or wave) relative to a beach's
/// shore: does the water move toward the beach, away from it (drift-out /
/// rip-current risk), or roughly parallel to it?
///
/// Despite the file name (kept for issue #164's history), this is a general
/// shore-relation classifier used for *both* the ocean current direction
/// (primary, per the issue's 2026-10-01 update) and the wave direction
/// (secondary) — see [classifyDirection]'s `convention` parameter.
library;

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
