/// A nearshore depth profile for one beach, as sampled along a short
/// seaward transect (see `lib/logic/transect.dart`) by `BathymetryService`
/// (issue #216): a rough, approximate indication of how the seabed falls
/// away from the shore, for non-swimmers/beginners ("is this a gentle
/// beach?"). This is never a safety guarantee -- real nearshore bathymetry
/// varies at a finer scale than EMODnet's ~115 m grid cells, and a sandbar,
/// drop-off or rip channel can exist well inside a single cell.
library;

/// One sample along a [DepthProfile]'s transect: the distance from the
/// shoreline and the depth measured there.
///
/// [depthMeters] is `null` for a land or NoData grid cell -- EMODnet has no
/// usable number there, and this must never be reported as a depth of `0`,
/// which would wrongly read as "right at the waterline". A non-null value
/// is always a positive number of meters below mean sea level.
class DepthSample {
  const DepthSample({required this.distanceMeters, this.depthMeters});

  /// Distance from the shoreline along the transect, in meters (e.g. 0,
  /// 100, 200, 300, 400 -- see `defaultTransectDistancesMeters`).
  final double distanceMeters;

  /// Depth in meters at this point, or `null` for land/NoData.
  final double? depthMeters;
}

/// A nearshore depth profile for one beach: a short transect of
/// [DepthSample]s running out from the shoreline along the beach's seaward
/// bearing.
///
/// [available] is `false` whenever no usable profile could be produced at
/// all (no beach geometry to anchor a transect on, every sample request
/// failed, etc.) -- [samples] is then empty, and callers should show
/// "no data" rather than a fabricated or all-zero profile. [approximate] is
/// always `true`: this is a coarse, best-effort indication from a ~115 m
/// resolution dataset, never a surveyed or guaranteed depth.
class DepthProfile {
  const DepthProfile({
    required this.samples,
    required this.available,
    this.approximate = true,
  });

  /// The "nothing to show" result: no samples, [available] is `false`.
  /// [BathymetryService] returns this instead of throwing whenever a
  /// profile cannot be produced, so callers never have to guess whether a
  /// [DepthProfile] is usable -- they only ever need to check [available].
  const DepthProfile.unavailable()
    : samples = const [],
      available = false,
      approximate = true;

  /// The transect's samples, in order of increasing [DepthSample.distanceMeters].
  /// Empty when [available] is `false`.
  final List<DepthSample> samples;

  /// Whether this profile has any usable data at all. `false` means
  /// [samples] is empty and nothing should be shown.
  final bool available;

  /// Always `true` -- see the class doc comment. Kept as a field (rather
  /// than a hardcoded assumption in callers) so it reads explicitly at
  /// every call site that renders this data, e.g. "~ approximate" next to
  /// a UI label.
  final bool approximate;

  /// [samples] with a non-null [DepthSample.depthMeters] -- land/NoData
  /// points excluded. Used by `lib/logic/shallow_entry.dart` to decide
  /// whether there is enough data to classify this profile at all.
  List<DepthSample> get validSamples =>
      samples.where((sample) => sample.depthMeters != null).toList();
}
