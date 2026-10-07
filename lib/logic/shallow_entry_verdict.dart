/// Plain-language, non-swimmer-focused verdict copy derived from an
/// existing [ShallowEntryClassification] (issue #256) -- no new
/// thresholds, just wording on top of `classifyShallowEntry`'s own
/// gentle/moderate/steep/unknown bands and
/// [ShallowEntryClassification.firstShallowExitDistanceMeters]/
/// [ShallowEntryClassification.firstDeepDistanceMeters].
///
/// Kept as small pure functions (no widget/painting code) in their own
/// file, sibling to `shallow_entry.dart`/`shallow_entry_status.dart`, so a
/// later screen (issue #257's beach summary) can reuse the exact same
/// wording instead of duplicating it.
library;

import '../data/models/depth_profile.dart';
import 'shallow_entry.dart';
import 'transect.dart';
import 'unit_preferences.dart';

/// Always shown under [shallowEntryVerdictLine] -- states the data's own
/// limits rather than implying a guarantee. Never uses the word "safe"
/// (see the class doc comments on `DepthProfile`/`ShallowEntryClassification`
/// for why).
const String depthApproximationCaveat =
    'Approximate (~115 m data). Not a safety guarantee. Waves, currents, '
    'sandbars and sudden drop-offs are not captured.';

/// Shown instead of a (never invented) shallow-start label when
/// [hasNoShallowZone] is `true`. Never uses the word "safe".
const String noShallowZoneMessage =
    'No shallow stand-up zone in this data (it may exist closer to shore '
    'than the data can show).';

/// One plain-language sentence judging [steepness] for non-swimmers, shown
/// at the top of the water-depth detail screen (issue #256). Always paired
/// with [depthApproximationCaveat] by the caller. Owner-reviewable copy --
/// see issue #256.
String shallowEntryVerdictLine(ShallowEntrySteepness steepness) {
  switch (steepness) {
    case ShallowEntrySteepness.gentle:
      return 'Shallow for a long way out. Easier for non-swimmers.';
    case ShallowEntrySteepness.moderate:
      return 'Gets deep fairly quickly. Non-swimmers should stay close to '
          'shore.';
    case ShallowEntrySteepness.steep:
      return 'Drops away quickly. Not suitable for non-swimmers.';
    case ShallowEntrySteepness.unknown:
      return 'Not enough depth data for this beach.';
  }
}

/// `true` when [profile]'s first valid (non-null-depth) sample, ordered by
/// distance, is already deeper than [shallowLimitMeters] -- i.e. there is
/// no stand-up-shallow zone anywhere in the *measured* data. This is a
/// distinct state from [ShallowEntrySteepness.unknown] (no usable data at
/// all): here there IS data, and it starts deep. Returns `false` when
/// there are no valid samples at all -- that case is "unknown", handled by
/// [shallowEntryVerdictLine] instead, never this message.
bool hasNoShallowZone(DepthProfile profile) {
  final validSamples = profile.validSamples;
  if (validSamples.isEmpty) return false;
  final sorted = [...validSamples]
    ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  final firstDepth = sorted.first.depthMeters;
  return firstDepth != null && firstDepth > shallowLimitMeters;
}

/// A plain-language description of where the "stand-up" shallow water
/// (at or under [shallowLimitMeters]) ends along the transect, e.g.
/// `"Stand-up water until about 180 m"`. Returns `null` when
/// [classification] is [ShallowEntrySteepness.unknown] (no data to say
/// anything) or when [hasNoShallowZone] is `true` for [profile] --
/// callers should show [noShallowZoneMessage] in that second case instead,
/// never a fabricated shallow start.
String? standUpDistanceLabel(
  ShallowEntryClassification classification,
  DepthProfile profile,
  UnitSystem unitSystem,
) {
  if (classification.steepness == ShallowEntrySteepness.unknown) return null;
  if (hasNoShallowZone(profile)) return null;

  final exitDistanceMeters = classification.firstShallowExitDistanceMeters;
  if (exitDistanceMeters == null) {
    final transectEndLabel = formatDistanceMeters(
      defaultTransectDistancesMeters.last,
      unitSystem,
    );
    return 'Stand-up water the whole way out to about $transectEndLabel';
  }
  final exitLabel = formatDistanceMeters(exitDistanceMeters, unitSystem);
  return 'Stand-up water until about $exitLabel';
}

/// A plain-language description of where "deep" water (over
/// [deepLimitMeters]) begins, e.g. `"Deep (2.5 m+) from about 320 m"`.
/// Returns `null` for [ShallowEntrySteepness.unknown] only -- unlike
/// [standUpDistanceLabel], this is still shown when [hasNoShallowZone] is
/// `true`, since the deep threshold is independent of whether a shallow
/// zone exists.
String? deepFromDistanceLabel(
  ShallowEntryClassification classification,
  UnitSystem unitSystem,
) {
  if (classification.steepness == ShallowEntrySteepness.unknown) return null;

  final deepLabel = formatDepthMeters(deepLimitMeters, unitSystem);
  final startDistanceMeters = classification.firstDeepDistanceMeters;
  if (startDistanceMeters == null) {
    return 'Water stays under $deepLabel for the whole measured distance';
  }
  final startLabel = formatDistanceMeters(startDistanceMeters, unitSystem);
  return 'Deep ($deepLabel+) from about $startLabel';
}
