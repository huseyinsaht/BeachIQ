/// Wind-speed status classification for the Home stat grid's wind speed
/// tile (issue #215), in the same small-pure-function-module style as
/// `lib/logic/uv_band.dart`/`lib/logic/pressure_trend.dart`.
library;

import 'package:flutter/material.dart';

import 'swim_suitability.dart';

/// A short wind-speed status word, from calmest to strongest.
enum WindStatus { calm, moderate, strong }

/// Classifies [windSpeedKmh] into a [WindStatus], reusing
/// `swim_suitability.dart`'s exact `moderateWindSpeedKmh`/
/// `highWindSpeedKmh` thresholds so this status word can never drift from
/// the swim verdict's own numbers.
///
/// Returns `null` when [windSpeedKmh] itself is `null` — "no data" is a
/// distinct state from "calm", so callers should show their own "no data"
/// copy instead of treating a `null` as calm.
WindStatus? windStatusFor(double? windSpeedKmh) {
  if (windSpeedKmh == null) return null;
  if (windSpeedKmh >= highWindSpeedKmh) return WindStatus.strong;
  if (windSpeedKmh >= moderateWindSpeedKmh) return WindStatus.moderate;
  return WindStatus.calm;
}

/// A short capitalized label for [status] (e.g. "Moderate"), for the Home
/// stat grid's wind speed tile.
String windStatusLabel(WindStatus status) {
  switch (status) {
    case WindStatus.calm:
      return 'Calm';
    case WindStatus.moderate:
      return 'Moderate';
    case WindStatus.strong:
      return 'Strong';
  }
}

/// A status color for [status], matching the moderate/high threshold
/// colors already used on the wind/rain-chance detail screens' charts (so
/// the same hue means "moderate"/"high" everywhere in the app), plus a
/// green for the calm case.
Color windStatusColor(WindStatus status) {
  switch (status) {
    case WindStatus.calm:
      return const Color(0xFF2E7D32);
    case WindStatus.moderate:
      return const Color(0xFFFFA726);
    case WindStatus.strong:
      return const Color(0xFFEF5350);
  }
}
