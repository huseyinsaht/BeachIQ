/// One on-site depth reading: [depthCm] centimeters of water at
/// [distanceMeters] meters from the water's edge.
class MeasuredDepthPoint {
  const MeasuredDepthPoint({
    required this.distanceMeters,
    required this.depthCm,
  });

  final int distanceMeters;
  final int depthCm;

  double get depthMeters => depthCm / 100;
}

/// A real, on-site depth measurement of the first ~10 m from the water's
/// edge at one beach (issue #390). This is the only source of *certain*
/// nearshore depth the app has: nothing is derived or estimated, and a
/// beach without an entry shows no 0-10 m values at all.
///
/// Entries come from the bundled `assets/measured_depths.json` (format and
/// measuring guide: `docs/measured-depth.md`). An entry applies to a beach
/// whose position is within [radiusMeters] of ([latitude], [longitude]).
class MeasuredNearshoreDepth {
  const MeasuredNearshoreDepth({
    required this.beachName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.measuredOn,
    required this.measuredBy,
    required this.method,
    required this.reference,
    required this.points,
    this.note,
  });

  /// Default match radius when an entry does not set one.
  static const double defaultRadiusMeters = 150;

  /// Default description of where distances start from.
  static const String defaultReference =
      "Water's edge at the time of measurement";

  /// The farthest measured distance the model accepts.
  static const int maxDistanceMeters = 10;

  final String beachName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime measuredOn;
  final String measuredBy;
  final String method;
  final String reference;
  final String? note;

  /// Readings ordered by increasing distance from the water's edge.
  final List<MeasuredDepthPoint> points;

  /// Parses one JSON entry. Returns `null` for anything invalid -- missing
  /// fields, out-of-range numbers, unordered or empty readings -- so a bad
  /// entry is dropped instead of showing a wrong depth or crashing.
  static MeasuredNearshoreDepth? tryParse(Object? json) {
    if (json is! Map) return null;
    try {
      final name = _nonEmptyString(json['beachName']);
      final by = _nonEmptyString(json['measuredBy']);
      final method = _nonEmptyString(json['method']);
      final lat = _number(json['latitude']);
      final lon = _number(json['longitude']);
      final date = DateTime.tryParse('${json['measuredOn']}');
      if (name == null ||
          by == null ||
          method == null ||
          lat == null ||
          lon == null ||
          date == null ||
          lat < -90 ||
          lat > 90 ||
          lon < -180 ||
          lon > 180) {
        return null;
      }

      final radius = json['radiusMeters'] == null
          ? defaultRadiusMeters
          : _number(json['radiusMeters']);
      if (radius == null || radius < 25 || radius > 1000) return null;

      final rawPoints = json['points'];
      if (rawPoints is! List || rawPoints.isEmpty || rawPoints.length > 12) {
        return null;
      }
      final points = <MeasuredDepthPoint>[];
      for (final raw in rawPoints) {
        if (raw is! Map) return null;
        final distance = raw['distanceMeters'];
        final depth = raw['depthCm'];
        if (distance is! int || depth is! int) return null;
        if (distance < 1 || distance > maxDistanceMeters) return null;
        if (depth < 0 || depth > 2000) return null;
        if (points.isNotEmpty && distance <= points.last.distanceMeters) {
          return null;
        }
        points.add(
          MeasuredDepthPoint(distanceMeters: distance, depthCm: depth),
        );
      }

      return MeasuredNearshoreDepth(
        beachName: name,
        latitude: lat,
        longitude: lon,
        radiusMeters: radius,
        measuredOn: date,
        measuredBy: by,
        method: method,
        reference: _nonEmptyString(json['reference']) ?? defaultReference,
        note: _nonEmptyString(json['note']),
        points: List.unmodifiable(points),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : null;
}
