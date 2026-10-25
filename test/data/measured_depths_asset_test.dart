import 'dart:convert';
import 'dart:io';

import 'package:beachiq/data/models/measured_nearshore_depth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the shipped `assets/measured_depths.json` (issue #390): an invalid
/// entry is silently dropped at runtime, so a typo would hide a real
/// measurement. This fails instead.
void main() {
  test('every entry of the shipped measured_depths.json is valid', () {
    final decoded =
        jsonDecode(File('assets/measured_depths.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(decoded['version'], 1);
    final beaches = decoded['beaches'] as List<dynamic>;
    for (final raw in beaches) {
      final name = (raw as Map)['beachName'];
      expect(
        MeasuredNearshoreDepth.tryParse(raw),
        isNotNull,
        reason: 'invalid entry for "$name" in assets/measured_depths.json',
      );
    }
  });

  test('no two entries describe the same spot twice', () {
    final decoded =
        jsonDecode(File('assets/measured_depths.json').readAsStringSync())
            as Map<String, dynamic>;
    final keys = [
      for (final raw in decoded['beaches'] as List<dynamic>)
        '${(raw as Map)['latitude']},${raw['longitude']}',
    ];

    expect(keys.toSet(), hasLength(keys.length));
  });
}
