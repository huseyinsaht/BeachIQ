import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/shallow_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DepthProfile _profileAt100m(double? depthAt100m, {List<DepthSample>? extra}) {
  return DepthProfile(
    available: true,
    samples: [
      const DepthSample(distanceMeters: 0, depthMeters: 0.3),
      DepthSample(distanceMeters: 100, depthMeters: depthAt100m),
      ...(extra ?? const []),
    ],
  );
}

void main() {
  group('classifyShallowEntry', () {
    group('steepness', () {
      test('given depth 1.0m at 100m, classifyShallowEntry -> gentle', () {
        final result = classifyShallowEntry(_profileAt100m(1.0));

        expect(result.steepness, ShallowEntrySteepness.gentle);
      });

      test('given depth exactly 1.5m at 100m, classifyShallowEntry -> gentle '
          '(inclusive boundary)', () {
        final result = classifyShallowEntry(_profileAt100m(1.5));

        expect(result.steepness, ShallowEntrySteepness.gentle);
      });

      test('given depth 1.51m at 100m, classifyShallowEntry -> moderate', () {
        final result = classifyShallowEntry(_profileAt100m(1.51));

        expect(result.steepness, ShallowEntrySteepness.moderate);
      });

      test('given depth 2.0m at 100m, classifyShallowEntry -> moderate', () {
        final result = classifyShallowEntry(_profileAt100m(2.0));

        expect(result.steepness, ShallowEntrySteepness.moderate);
      });

      test('given depth exactly 3.0m at 100m, classifyShallowEntry -> moderate '
          '(inclusive boundary)', () {
        final result = classifyShallowEntry(_profileAt100m(3.0));

        expect(result.steepness, ShallowEntrySteepness.moderate);
      });

      test('given depth 3.01m at 100m, classifyShallowEntry -> steep', () {
        final result = classifyShallowEntry(_profileAt100m(3.01));

        expect(result.steepness, ShallowEntrySteepness.steep);
      });

      test('given depth 10m at 100m, classifyShallowEntry -> steep', () {
        final result = classifyShallowEntry(_profileAt100m(10));

        expect(result.steepness, ShallowEntrySteepness.steep);
      });
    });

    group('unknown (not enough data)', () {
      test('given an empty profile, classifyShallowEntry -> unknown', () {
        const profile = DepthProfile.unavailable();

        final result = classifyShallowEntry(profile);

        expect(result.steepness, ShallowEntrySteepness.unknown);
        expect(result.firstShallowExitDistanceMeters, isNull);
        expect(result.firstDeepDistanceMeters, isNull);
      });

      test('given only one valid sample (depth at 100m known, nothing else), '
          'classifyShallowEntry -> unknown', () {
        const profile = DepthProfile(
          available: true,
          samples: [
            DepthSample(distanceMeters: 0, depthMeters: null),
            DepthSample(distanceMeters: 100, depthMeters: 1.0),
            DepthSample(distanceMeters: 200, depthMeters: null),
          ],
        );

        final result = classifyShallowEntry(profile);

        expect(result.steepness, ShallowEntrySteepness.unknown);
      });

      test('given two or more valid samples but no reading at exactly 100m, '
          'classifyShallowEntry -> unknown (never extrapolated)', () {
        const profile = DepthProfile(
          available: true,
          samples: [
            DepthSample(distanceMeters: 0, depthMeters: 0.3),
            DepthSample(distanceMeters: 200, depthMeters: 1.8),
            DepthSample(distanceMeters: 300, depthMeters: 2.4),
          ],
        );

        final result = classifyShallowEntry(profile);

        expect(result.steepness, ShallowEntrySteepness.unknown);
      });

      test('given the 100m sample itself is land/NoData (null) even with '
          'enough other valid samples, classifyShallowEntry -> unknown', () {
        final result = classifyShallowEntry(_profileAt100m(null));

        expect(result.steepness, ShallowEntrySteepness.unknown);
      });
    });

    group('firstShallowExitDistanceMeters', () {
      test('given depth crosses shallowLimitMeters (1.2m) between 100m and '
          '200m, classifyShallowEntry -> reports 200m as the first exceeding '
          'distance', () {
        final profile = _profileAt100m(
          1.0,
          extra: const [
            DepthSample(distanceMeters: 200, depthMeters: 1.5),
            DepthSample(distanceMeters: 300, depthMeters: 2.0),
            DepthSample(distanceMeters: 400, depthMeters: 3.0),
          ],
        );

        final result = classifyShallowEntry(profile);

        expect(result.firstShallowExitDistanceMeters, 200);
      });

      test('given depth exactly at shallowLimitMeters (1.2m) does not count '
          'as exceeding it, classifyShallowEntry -> skips that sample', () {
        final profile = _profileAt100m(
          1.2,
          extra: const [DepthSample(distanceMeters: 200, depthMeters: 1.3)],
        );

        final result = classifyShallowEntry(profile);

        expect(result.firstShallowExitDistanceMeters, 200);
      });

      test('given every valid sample stays at or under shallowLimitMeters out '
          'to 400m, classifyShallowEntry -> firstShallowExitDistanceMeters is '
          'null ("beyond 400 m")', () {
        final profile = _profileAt100m(
          0.8,
          extra: const [
            DepthSample(distanceMeters: 200, depthMeters: 0.9),
            DepthSample(distanceMeters: 300, depthMeters: 1.0),
            DepthSample(distanceMeters: 400, depthMeters: 1.1),
          ],
        );

        final result = classifyShallowEntry(profile);

        expect(result.firstShallowExitDistanceMeters, isNull);
      });
    });

    group('firstDeepDistanceMeters', () {
      test('given depth crosses deepLimitMeters (2.5m) at 300m, '
          'classifyShallowEntry -> reports 300m', () {
        final profile = _profileAt100m(
          1.0,
          extra: const [
            DepthSample(distanceMeters: 200, depthMeters: 1.8),
            DepthSample(distanceMeters: 300, depthMeters: 2.6),
            DepthSample(distanceMeters: 400, depthMeters: 3.2),
          ],
        );

        final result = classifyShallowEntry(profile);

        expect(result.firstDeepDistanceMeters, 300);
      });

      test(
        'given no valid sample exceeds deepLimitMeters, classifyShallowEntry '
        '-> firstDeepDistanceMeters is null',
        () {
          final profile = _profileAt100m(1.0);

          final result = classifyShallowEntry(profile);

          expect(result.firstDeepDistanceMeters, isNull);
        },
      );
    });

    test(
      'given any profile, classifyShallowEntry -> approximate is always true',
      () {
        final result = classifyShallowEntry(_profileAt100m(1.0));

        expect(result.approximate, isTrue);
      },
    );
  });
}
