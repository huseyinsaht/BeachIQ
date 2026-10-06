/// Classifies how steeply a beach's seabed falls away from the shore, from
/// a nearshore [DepthProfile] (issue #216) -- a rough, approximate
/// indication for non-swimmers/beginners of "is this a gentle beach?",
/// never a safety guarantee. See `depth_profile.dart`'s doc comment for
/// the data-quality caveats this inherits.
library;

import '../data/models/depth_profile.dart';

/// Below this depth (meters), a point on the transect counts as reliably
/// "shallow" -- about knee-to-waist deep for an adult, a reasonable line
/// for "a non-swimmer can comfortably stand here". Used by
/// [classifyShallowEntry] to compute [ShallowEntryClassification.firstShallowExitDistanceMeters]:
/// the first distance at which the water stops being this shallow.
const double shallowLimitMeters = 1.2;

/// Above this depth (meters), a point on the transect counts as properly
/// "deep" -- clearly over a typical adult's head. Used by
/// [classifyShallowEntry] to compute [ShallowEntryClassification.firstDeepDistanceMeters]:
/// the first distance at which the water becomes this deep, as the natural
/// companion to [shallowLimitMeters] (where "comfortably shallow" ends and
/// where "properly deep" begins are two different lines, not one).
const double deepLimitMeters = 2.5;

/// The transect distance (meters) [classifyShallowEntry]'s gentle/moderate/
/// steep bands are read at -- see the field doc comments below for why.
const double classificationReferenceDistanceMeters = 100;

/// At or below this depth (meters) at [classificationReferenceDistanceMeters],
/// a profile is [ShallowEntrySteepness.gentle].
const double gentleMaxDepthAtReferenceDistanceMeters = 1.5;

/// At or below this depth (meters) at [classificationReferenceDistanceMeters]
/// (but above [gentleMaxDepthAtReferenceDistanceMeters]), a profile is
/// [ShallowEntrySteepness.moderate]; above it, [ShallowEntrySteepness.steep].
const double moderateMaxDepthAtReferenceDistanceMeters = 3.0;

/// How steeply a beach's seabed falls away from the shore, as judged by
/// [classifyShallowEntry].
enum ShallowEntrySteepness {
  /// Depth at [classificationReferenceDistanceMeters] is at or under
  /// [gentleMaxDepthAtReferenceDistanceMeters] -- a long, shallow wade out.
  gentle,

  /// Depth at [classificationReferenceDistanceMeters] is between
  /// [gentleMaxDepthAtReferenceDistanceMeters] and
  /// [moderateMaxDepthAtReferenceDistanceMeters].
  moderate,

  /// Depth at [classificationReferenceDistanceMeters] is over
  /// [moderateMaxDepthAtReferenceDistanceMeters] -- the seabed drops away
  /// quickly.
  steep,

  /// Fewer than two valid (non-null) samples on the transect, or no
  /// reading at [classificationReferenceDistanceMeters] at all -- not
  /// enough data to judge, never guessed.
  unknown,
}

/// The result of classifying a [DepthProfile] -- always carries
/// [approximate] as `true`, since the underlying data is a coarse,
/// best-effort indication (see `depth_profile.dart`).
class ShallowEntryClassification {
  const ShallowEntryClassification({
    required this.steepness,
    required this.firstShallowExitDistanceMeters,
    required this.firstDeepDistanceMeters,
    this.approximate = true,
  });

  /// The gentle/moderate/steep/unknown verdict.
  final ShallowEntrySteepness steepness;

  /// The first transect distance (meters) at which depth exceeds
  /// [shallowLimitMeters] -- where the water stops being reliably
  /// shallow-enough-to-stand-in. `null` means every valid sample out to
  /// the end of the transect stayed at or under [shallowLimitMeters]
  /// ("beyond 400 m", for the default transect), or that no sample
  /// exceeded it because there is no usable data at all.
  final double? firstShallowExitDistanceMeters;

  /// The first transect distance (meters) at which depth exceeds
  /// [deepLimitMeters]. `null` on the same terms as
  /// [firstShallowExitDistanceMeters], read against the deep limit
  /// instead of the shallow one.
  final double? firstDeepDistanceMeters;

  /// Always `true` -- see the class doc comment.
  final bool approximate;
}

/// Classifies [profile]'s shallow-entry steepness.
///
/// Pure function: no I/O, no clock. [ShallowEntrySteepness.unknown] is
/// returned whenever there are fewer than two valid (non-null-depth)
/// samples in [profile], or when the transect has no sample at exactly
/// [classificationReferenceDistanceMeters] with a non-null depth --
/// extrapolating from a different distance would be a guess, which this
/// never does. Otherwise the depth at
/// [classificationReferenceDistanceMeters] alone decides gentle/moderate/
/// steep (see [ShallowEntrySteepness]'s doc comments for the exact
/// boundaries, inclusive at both 1.5 m and 3 m).
ShallowEntryClassification classifyShallowEntry(DepthProfile profile) {
  final firstShallowExitDistanceMeters = _firstDistanceExceeding(
    profile.samples,
    shallowLimitMeters,
  );
  final firstDeepDistanceMeters = _firstDistanceExceeding(
    profile.samples,
    deepLimitMeters,
  );

  final depthAtReference = _depthAtDistance(
    profile,
    classificationReferenceDistanceMeters,
  );

  ShallowEntrySteepness steepness;
  if (profile.validSamples.length < 2 || depthAtReference == null) {
    steepness = ShallowEntrySteepness.unknown;
  } else if (depthAtReference <= gentleMaxDepthAtReferenceDistanceMeters) {
    steepness = ShallowEntrySteepness.gentle;
  } else if (depthAtReference <= moderateMaxDepthAtReferenceDistanceMeters) {
    steepness = ShallowEntrySteepness.moderate;
  } else {
    steepness = ShallowEntrySteepness.steep;
  }

  return ShallowEntryClassification(
    steepness: steepness,
    firstShallowExitDistanceMeters: firstShallowExitDistanceMeters,
    firstDeepDistanceMeters: firstDeepDistanceMeters,
  );
}

double? _depthAtDistance(DepthProfile profile, double distanceMeters) {
  for (final sample in profile.samples) {
    if (sample.distanceMeters == distanceMeters) return sample.depthMeters;
  }
  return null;
}

double? _firstDistanceExceeding(List<DepthSample> samples, double limitMeters) {
  final sortedByDistance = [...samples]
    ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  for (final sample in sortedByDistance) {
    final depth = sample.depthMeters;
    if (depth != null && depth > limitMeters) return sample.distanceMeters;
  }
  return null;
}
