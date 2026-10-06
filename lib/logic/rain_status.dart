/// Rain-chance status classification for the Home stat grid's rain chance
/// tile (issue #215), in the same small-pure-function-module style as
/// `lib/logic/wind_status.dart`/`lib/logic/uv_band.dart`.
library;

import 'package:flutter/material.dart';

import 'swim_suitability.dart';

/// A short rain-chance status word, from least to most likely.
enum RainChanceStatus { low, medium, high }

/// Classifies [rainChancePercent] into a [RainChanceStatus], reusing
/// `swim_suitability.dart`'s exact `moderateRainChancePercent`/
/// `highRainChancePercent` thresholds so this status word can never drift
/// from the swim verdict's own numbers.
///
/// Returns `null` when [rainChancePercent] itself is `null` — "no data" is
/// a distinct state from "low", so callers should show their own "no data"
/// copy instead of treating a `null` as low.
RainChanceStatus? rainChanceStatusFor(double? rainChancePercent) {
  if (rainChancePercent == null) return null;
  if (rainChancePercent >= highRainChancePercent) return RainChanceStatus.high;
  if (rainChancePercent >= moderateRainChancePercent) {
    return RainChanceStatus.medium;
  }
  return RainChanceStatus.low;
}

/// A short capitalized label for [status] (e.g. "Medium"), for the Home
/// stat grid's rain chance tile.
String rainChanceStatusLabel(RainChanceStatus status) {
  switch (status) {
    case RainChanceStatus.low:
      return 'Low';
    case RainChanceStatus.medium:
      return 'Medium';
    case RainChanceStatus.high:
      return 'High';
  }
}

/// A status color for [status], matching the moderate/high threshold
/// colors already used on the wind/rain-chance detail screens' charts (so
/// the same hue means "moderate"/"high" everywhere in the app), plus a
/// green for the low case.
Color rainChanceStatusColor(RainChanceStatus status) {
  switch (status) {
    case RainChanceStatus.low:
      return const Color(0xFF2E7D32);
    case RainChanceStatus.medium:
      return const Color(0xFFFFA726);
    case RainChanceStatus.high:
      return const Color(0xFFEF5350);
  }
}
