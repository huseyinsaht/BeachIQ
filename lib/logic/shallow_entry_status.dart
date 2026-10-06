/// Status-word/color mapping and tile/hero value formatting for
/// `ShallowEntrySteepness` (issue #216's classification), for the Home
/// stat grid's water-depth tile and its detail screen (issue #217) — in
/// the same small-pure-function-module style as
/// `lib/logic/wind_status.dart`/`lib/logic/uv_band.dart`.
library;

import 'package:flutter/material.dart';

import 'shallow_entry.dart';
import 'transect.dart';
import 'unit_preferences.dart';

/// Shown by [formatShallowEntrySummary] (and usable by callers directly)
/// whenever there isn't enough data to classify a profile at all —
/// matches `home_screen.dart`'s own `_noData` constant.
const String noShallowEntryDataLabel = 'No data';

/// A short capitalized label for [steepness] ("Gentle"/"Moderate"/
/// "Steep"), or `null` for [ShallowEntrySteepness.unknown] — "no data" is
/// a distinct state from any of the three real bands, so callers should
/// show their own "No data" copy instead of treating "unknown" as a
/// steepness word.
String? shallowEntryStatusLabel(ShallowEntrySteepness steepness) {
  switch (steepness) {
    case ShallowEntrySteepness.gentle:
      return 'Gentle';
    case ShallowEntrySteepness.moderate:
      return 'Moderate';
    case ShallowEntrySteepness.steep:
      return 'Steep';
    case ShallowEntrySteepness.unknown:
      return null;
  }
}

/// A status color for [steepness] (green/orange/red, matching the rest of
/// the app's moderate/high palette — see `wind_status.dart`'s own
/// colors), or `null` for [ShallowEntrySteepness.unknown] — see
/// [shallowEntryStatusLabel].
Color? shallowEntryStatusColor(ShallowEntrySteepness steepness) {
  switch (steepness) {
    case ShallowEntrySteepness.gentle:
      return const Color(0xFF2E7D32);
    case ShallowEntrySteepness.moderate:
      return const Color(0xFFFFA726);
    case ShallowEntrySteepness.steep:
      return const Color(0xFFEF5350);
    case ShallowEntrySteepness.unknown:
      return null;
  }
}

/// A formatted summary of [classification] for the Home water-depth
/// tile's value and its detail screen's hero value: how far out from
/// shore the water stays "comfortably shallow" (at or under
/// [shallowLimitMeters]), e.g. `"<= 1.2 m for 180 m"`, or
/// `"<= 1.2 m beyond 400 m"` when every valid sample out to the end of the
/// transect never exceeded [shallowLimitMeters]. Returns
/// [noShallowEntryDataLabel] for [ShallowEntrySteepness.unknown] — never a
/// fabricated distance.
String formatShallowEntrySummary(
  ShallowEntryClassification classification,
  UnitSystem unitSystem,
) {
  if (classification.steepness == ShallowEntrySteepness.unknown) {
    return noShallowEntryDataLabel;
  }

  final depthLabel = formatDepthMeters(shallowLimitMeters, unitSystem);
  final exitDistanceMeters = classification.firstShallowExitDistanceMeters;
  if (exitDistanceMeters == null) {
    final transectEndLabel = formatDistanceMeters(
      defaultTransectDistancesMeters.last,
      unitSystem,
    );
    return '<= $depthLabel beyond $transectEndLabel';
  }

  final exitLabel = formatDistanceMeters(exitDistanceMeters, unitSystem);
  return '<= $depthLabel for $exitLabel';
}
