import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/shallow_entry.dart';
import 'package:beachiq/logic/shallow_entry_verdict.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

const DepthProfile _gentleProfile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0, depthMeters: 0.3),
    DepthSample(distanceMeters: 100, depthMeters: 1.0),
    DepthSample(distanceMeters: 200, depthMeters: 1.5),
    DepthSample(distanceMeters: 300, depthMeters: 2.0),
    DepthSample(distanceMeters: 400, depthMeters: 2.5),
  ],
);

const DepthProfile _steepProfile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0, depthMeters: 0.5),
    DepthSample(distanceMeters: 100, depthMeters: 3.2),
    DepthSample(distanceMeters: 200, depthMeters: 4.0),
  ],
);

const DepthProfile _moderateProfile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0, depthMeters: 0.4),
    DepthSample(distanceMeters: 100, depthMeters: 2.0),
    DepthSample(distanceMeters: 200, depthMeters: 2.8),
  ],
);

const DepthProfile _alwaysShallowProfile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0, depthMeters: 0.3),
    DepthSample(distanceMeters: 100, depthMeters: 0.8),
    DepthSample(distanceMeters: 200, depthMeters: 1.0),
    DepthSample(distanceMeters: 300, depthMeters: 1.1),
    DepthSample(distanceMeters: 400, depthMeters: 1.2),
  ],
);

const DepthProfile _noShallowZoneProfile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0),
    DepthSample(distanceMeters: 100, depthMeters: 2.0),
    DepthSample(distanceMeters: 200, depthMeters: 2.8),
  ],
);

void main() {
  group('shallowEntryVerdictLine', () {
    test('given gentle, returns the non-swimmer-friendly copy', () {
      expect(
        shallowEntryVerdictLine(ShallowEntrySteepness.gentle),
        'Shallow for a long way out. Easier for non-swimmers.',
      );
    });

    test('given moderate, returns the "stay close" copy', () {
      expect(
        shallowEntryVerdictLine(ShallowEntrySteepness.moderate),
        'Gets deep fairly quickly. Non-swimmers should stay close to shore.',
      );
    });

    test('given steep, returns the "not suitable" copy', () {
      expect(
        shallowEntryVerdictLine(ShallowEntrySteepness.steep),
        'Drops away quickly. Not suitable for non-swimmers.',
      );
    });

    test('given unknown, returns the "not enough data" copy', () {
      expect(
        shallowEntryVerdictLine(ShallowEntrySteepness.unknown),
        'Not enough depth data for this beach.',
      );
    });
  });

  group('depthApproximationCaveat', () {
    test('never claims the beach is "safe" (only ever "not a safety '
        'guarantee")', () {
      expect(
        RegExp(r'\bsafe\b').hasMatch(depthApproximationCaveat.toLowerCase()),
        isFalse,
      );
    });
  });

  group('hasNoShallowZone', () {
    test('given a profile whose first valid sample is already deeper than '
        'shallowLimitMeters, returns true', () {
      expect(hasNoShallowZone(_noShallowZoneProfile), isTrue);
    });

    test('given a profile whose first valid sample is at or under '
        'shallowLimitMeters, returns false', () {
      expect(hasNoShallowZone(_gentleProfile), isFalse);
    });

    test('given no valid samples at all, returns false (that is "unknown", '
        'not "no shallow zone")', () {
      expect(hasNoShallowZone(const DepthProfile.unavailable()), isFalse);
    });

    test('given land/NoData samples before the first valid one, reads the '
        'first VALID sample, never the first entry in the list', () {
      const profile = DepthProfile(
        available: true,
        samples: [
          DepthSample(distanceMeters: 0),
          DepthSample(distanceMeters: 100, depthMeters: 0.5),
        ],
      );
      expect(hasNoShallowZone(profile), isFalse);
    });

    test('boundary: a first valid sample exactly at shallowLimitMeters is '
        'still a shallow zone (not "no shallow zone")', () {
      const profile = DepthProfile(
        available: true,
        samples: [
          DepthSample(distanceMeters: 0, depthMeters: shallowLimitMeters),
        ],
      );
      expect(hasNoShallowZone(profile), isFalse);
    });
  });

  group('standUpDistanceLabel', () {
    test('given a gentle profile, names the first distance beyond '
        'shallowLimitMeters', () {
      final classification = classifyShallowEntry(_gentleProfile);
      expect(
        standUpDistanceLabel(classification, _gentleProfile, UnitSystem.metric),
        'Stand-up water until about 200 m',
      );
    });

    test('given a profile that never exceeds shallowLimitMeters, says so for '
        'the whole measured distance instead of inventing an exit point', () {
      final classification = classifyShallowEntry(_alwaysShallowProfile);
      expect(
        standUpDistanceLabel(
          classification,
          _alwaysShallowProfile,
          UnitSystem.metric,
        ),
        'Stand-up water the whole way out to about 400 m',
      );
    });

    test('given unknown classification, returns null (no data to say '
        'anything)', () {
      const profile = DepthProfile.unavailable();
      final classification = classifyShallowEntry(profile);
      expect(
        standUpDistanceLabel(classification, profile, UnitSystem.metric),
        isNull,
      );
    });

    test('given a profile with no shallow zone, returns null -- callers show '
        'noShallowZoneMessage instead, never a fabricated shallow start', () {
      final classification = classifyShallowEntry(_noShallowZoneProfile);
      expect(
        standUpDistanceLabel(
          classification,
          _noShallowZoneProfile,
          UnitSystem.metric,
        ),
        isNull,
      );
    });

    test('given an imperial unit preference, formats the distance in feet', () {
      final classification = classifyShallowEntry(_gentleProfile);
      expect(
        standUpDistanceLabel(
          classification,
          _gentleProfile,
          UnitSystem.imperial,
        ),
        'Stand-up water until about 656 ft',
      );
    });
  });

  group('deepFromDistanceLabel', () {
    test('given a steep profile, names the first distance beyond '
        'deepLimitMeters', () {
      final classification = classifyShallowEntry(_steepProfile);
      expect(
        deepFromDistanceLabel(classification, UnitSystem.metric),
        'Deep (2.5 m+) from about 100 m',
      );
    });

    test('given a profile that never exceeds deepLimitMeters, says so for the '
        'whole measured distance instead of inventing a deep point', () {
      final classification = classifyShallowEntry(_alwaysShallowProfile);
      expect(
        deepFromDistanceLabel(classification, UnitSystem.metric),
        'Water stays under 2.5 m for the whole measured distance',
      );
    });

    test('given unknown classification, returns null', () {
      final classification = classifyShallowEntry(
        const DepthProfile.unavailable(),
      );
      expect(deepFromDistanceLabel(classification, UnitSystem.metric), isNull);
    });

    test('given a profile with no shallow zone, still returns the deep-from '
        'label -- independent of whether a shallow zone exists', () {
      final classification = classifyShallowEntry(_noShallowZoneProfile);
      expect(
        deepFromDistanceLabel(classification, UnitSystem.metric),
        'Deep (2.5 m+) from about 200 m',
      );
    });

    test('given a moderate profile, still resolves the deep-from label from '
        'the same firstDeepDistanceMeters field', () {
      final classification = classifyShallowEntry(_moderateProfile);
      expect(
        deepFromDistanceLabel(classification, UnitSystem.metric),
        'Deep (2.5 m+) from about 200 m',
      );
    });
  });
}
