import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:latlong2/latlong.dart';

import '../models/measured_nearshore_depth.dart';

/// Looks up on-site nearshore depth measurements (issue #390) from the
/// bundled `assets/measured_depths.json`.
///
/// Loading never throws: a missing, unreadable or malformed file simply
/// yields no entries, and individual invalid entries are dropped (see
/// [MeasuredNearshoreDepth.tryParse]) -- the app then shows its usual
/// "approximate" depth wording, never a made-up measured value.
class MeasuredDepthRepository {
  MeasuredDepthRepository(this.entries);

  /// A repository with no measurements.
  const MeasuredDepthRepository.empty() : entries = const [];

  static const String defaultAssetPath = 'assets/measured_depths.json';

  static const Distance _distance = Distance();

  final List<MeasuredNearshoreDepth> entries;

  /// Loads [assetPath] from [bundle] (the app's `rootBundle` by default).
  static Future<MeasuredDepthRepository> load({
    AssetBundle? bundle,
    String assetPath = defaultAssetPath,
  }) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(assetPath);
      return MeasuredDepthRepository.fromJsonString(raw);
    } catch (_) {
      return const MeasuredDepthRepository.empty();
    }
  }

  /// Parses the asset's JSON text (`{"beaches": [ ... ]}`).
  factory MeasuredDepthRepository.fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['beaches'] : null;
      if (list is! List) return const MeasuredDepthRepository.empty();
      return MeasuredDepthRepository([
        for (final item in list)
          if (MeasuredNearshoreDepth.tryParse(item) case final entry?) entry,
      ]);
    } catch (_) {
      return const MeasuredDepthRepository.empty();
    }
  }

  /// The measurement for the beach at ([latitude], [longitude]): the
  /// closest entry whose own radius contains that position, else `null`.
  MeasuredNearshoreDepth? findFor(double latitude, double longitude) {
    final point = LatLng(latitude, longitude);
    MeasuredNearshoreDepth? best;
    var bestDistance = double.infinity;
    for (final entry in entries) {
      final meters = _distance(point, LatLng(entry.latitude, entry.longitude));
      if (meters <= entry.radiusMeters && meters < bestDistance) {
        best = entry;
        bestDistance = meters;
      }
    }
    return best;
  }
}
