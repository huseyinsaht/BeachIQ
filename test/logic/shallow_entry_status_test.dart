import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/shallow_entry.dart';
import 'package:beachiq/logic/shallow_entry_status.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

ShallowEntryClassification _classify(List<DepthSample> samples) {
  return classifyShallowEntry(DepthProfile(samples: samples, available: true));
}

void main() {
  group('shallowEntryStatusLabel', () {
    test('given gentle, shallowEntryStatusLabel -> "Gentle"', () {
      expect(shallowEntryStatusLabel(ShallowEntrySteepness.gentle), 'Gentle');
    });

    test('given moderate, shallowEntryStatusLabel -> "Moderate"', () {
      expect(
        shallowEntryStatusLabel(ShallowEntrySteepness.moderate),
        'Moderate',
      );
    });

    test('given steep, shallowEntryStatusLabel -> "Steep"', () {
      expect(shallowEntryStatusLabel(ShallowEntrySteepness.steep), 'Steep');
    });

    test('given unknown, shallowEntryStatusLabel -> null (never a label for '
        '"no data")', () {
      expect(shallowEntryStatusLabel(ShallowEntrySteepness.unknown), isNull);
    });
  });

  group('shallowEntryStatusColor', () {
    test('given gentle/moderate/steep, shallowEntryStatusColor -> a '
        'distinct non-null color each', () {
      final gentle = shallowEntryStatusColor(ShallowEntrySteepness.gentle);
      final moderate = shallowEntryStatusColor(ShallowEntrySteepness.moderate);
      final steep = shallowEntryStatusColor(ShallowEntrySteepness.steep);

      expect(gentle, isNotNull);
      expect(moderate, isNotNull);
      expect(steep, isNotNull);
      expect({gentle, moderate, steep}, hasLength(3));
    });

    test('given unknown, shallowEntryStatusColor -> null', () {
      expect(shallowEntryStatusColor(ShallowEntrySteepness.unknown), isNull);
    });
  });

  group('formatShallowEntrySummary', () {
    test('given unknown, formatShallowEntrySummary -> '
        'noShallowEntryDataLabel', () {
      final classification = _classify(const []);

      expect(
        formatShallowEntrySummary(classification, UnitSystem.metric),
        noShallowEntryDataLabel,
      );
      expect(noShallowEntryDataLabel, 'No data');
    });

    test('given a profile that exits shallow at 200m, '
        'formatShallowEntrySummary (metric) -> "<= 1.2 m for 200 m"', () {
      final classification = _classify(const [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: 1.0),
        DepthSample(distanceMeters: 200, depthMeters: 1.5),
      ]);

      expect(
        formatShallowEntrySummary(classification, UnitSystem.metric),
        '<= 1.2 m for 200 m',
      );
    });

    test('given the same profile, formatShallowEntrySummary (imperial) -> '
        'feet for both numbers', () {
      final classification = _classify(const [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: 1.0),
        DepthSample(distanceMeters: 200, depthMeters: 1.5),
      ]);

      final result = formatShallowEntrySummary(
        classification,
        UnitSystem.imperial,
      );

      expect(result, contains('ft'));
      expect(result, isNot(contains(' m')));
    });

    test('given every valid sample stays shallow out to the end of the '
        'transect, formatShallowEntrySummary -> "<= 1.2 m beyond 400 m"', () {
      final classification = _classify(const [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: 0.6),
        DepthSample(distanceMeters: 200, depthMeters: 0.8),
        DepthSample(distanceMeters: 300, depthMeters: 0.9),
        DepthSample(distanceMeters: 400, depthMeters: 1.0),
      ]);

      expect(
        formatShallowEntrySummary(classification, UnitSystem.metric),
        '<= 1.2 m beyond 400 m',
      );
    });
  });
}
