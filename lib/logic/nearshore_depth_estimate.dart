import '../data/models/depth_profile.dart';
import 'beach_surface.dart';
import 'shallow_entry.dart';
import 'unit_preferences.dart';

/// An *estimate* of how deep the water is within the first 10 m from the
/// water's edge, for beaches nobody has measured (issue #392).
///
/// There is no dataset for this range (EMODnet's grid is ~115 m), so the
/// estimate only uses two things the app already has: the beach's OSM
/// surface and the depth ~100 m out ([classificationReferenceDistanceMeters]).
/// It is deliberately conservative and never presented as a measurement.
///
/// Model, for **sand** only (documented in `docs/nearshore-estimate.md`):
/// a beach profile is at least as steep near the water as a straight line to
/// the 100 m depth, and no steeper than a `depth ~ distance^0.5` curve. So at
/// 10 m the depth is between [linearFactor] (0.10, the straight line) and
/// [steepFactor] (0.32, `0.1^0.5`) times the 100 m depth. These factors are
/// **provisional** until they are checked against real measurements.
///
/// Coarser beaches (pebbles, gravel, rock) are steeper and far less
/// predictable, so they get a qualitative warning and no numbers. A missing
/// or unrecognised surface, or a missing 100 m depth, gives no estimate.
enum NearshoreEstimateKind {
  /// A numeric range: [NearshoreDepthEstimate.lowMeters] to
  /// [NearshoreDepthEstimate.highMeters].
  range,

  /// The range's upper end reaches [NearshoreDepthEstimate.deepWarningMeters]:
  /// no numbers, a "can be deep within 10 m" warning.
  mayBeDeep,

  /// A coarse or rocky beach: usually steeper, no numbers.
  steepBeachType,
}

class NearshoreDepthEstimate {
  const NearshoreDepthEstimate._({
    required this.kind,
    required this.surface,
    this.lowMeters,
    this.highMeters,
  });

  /// Straight line from the water's edge (0 m) to the 100 m depth.
  static const double linearFactor = 0.10;

  /// A `depth ~ distance^0.5` curve: the steep-near-shore end.
  static const double steepFactor = 0.32;

  /// About waist-to-chest deep on an adult: from here the app stops showing
  /// numbers and warns instead.
  static const double deepWarningMeters = 1.2;

  final NearshoreEstimateKind kind;
  final BeachSurface surface;

  /// Lower and upper depth at 10 m, only for [NearshoreEstimateKind.range].
  final double? lowMeters;
  final double? highMeters;

  /// The estimate for [surface] (an OSM `surface` value) and [profile], or
  /// `null` when there is nothing honest to say.
  static NearshoreDepthEstimate? from({
    required String? osmSurface,
    required DepthProfile? profile,
  }) {
    final surface = parseBeachSurface(osmSurface);
    if (surface == null) return null;

    if (surface != BeachSurface.sand) {
      return NearshoreDepthEstimate._(
        kind: NearshoreEstimateKind.steepBeachType,
        surface: surface,
      );
    }

    final depth100 = _depthAt100m(profile);
    if (depth100 == null || depth100 <= 0) return null;

    final high = depth100 * steepFactor;
    if (high >= deepWarningMeters) {
      return NearshoreDepthEstimate._(
        kind: NearshoreEstimateKind.mayBeDeep,
        surface: surface,
      );
    }
    return NearshoreDepthEstimate._(
      kind: NearshoreEstimateKind.range,
      surface: surface,
      lowMeters: depth100 * linearFactor,
      highMeters: high,
    );
  }

  static double? _depthAt100m(DepthProfile? profile) {
    if (profile == null || !profile.available) return null;
    for (final sample in profile.samples) {
      if (sample.distanceMeters == classificationReferenceDistanceMeters) {
        return sample.depthMeters;
      }
    }
    return null;
  }

  /// "about 0.1-0.3 m" / "up to 0.3 m" for [NearshoreEstimateKind.range]; the
  /// upper end is rounded **up** and the lower end **down** to 0.1 so the
  /// shown range always contains the model's range. `null` for other kinds.
  String? rangeText(UnitSystem unitSystem) {
    if (kind != NearshoreEstimateKind.range) return null;
    final high = _roundUp(highMeters!);
    final low = _roundDown(lowMeters!);
    if (low < 0.1) {
      return 'up to ${formatDepthMeters(high, unitSystem)}';
    }
    final highText = formatDepthMeters(high, unitSystem);
    final lowText = formatDepthMeters(low, unitSystem);
    return 'about $lowText to $highText';
  }

  static double _roundUp(double v) => (v * 10).ceil() / 10;
  static double _roundDown(double v) => (v * 10).floor() / 10;
}
