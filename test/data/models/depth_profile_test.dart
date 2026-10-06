import 'package:beachiq/data/models/depth_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DepthProfile', () {
    group('unavailable', () {
      test('given DepthProfile.unavailable, it -> has no samples, is not '
          'available, but still carries approximate: true', () {
        const profile = DepthProfile.unavailable();

        expect(profile.samples, isEmpty);
        expect(profile.available, isFalse);
        expect(profile.approximate, isTrue);
      });
    });

    group('validSamples', () {
      test('given a mix of valid and null-depth samples, validSamples -> '
          'excludes the null (land/NoData) ones', () {
        const profile = DepthProfile(
          available: true,
          samples: [
            DepthSample(distanceMeters: 0, depthMeters: null),
            DepthSample(distanceMeters: 100, depthMeters: 1.0),
            DepthSample(distanceMeters: 200, depthMeters: null),
            DepthSample(distanceMeters: 300, depthMeters: 2.0),
          ],
        );

        final valid = profile.validSamples;

        expect(valid.length, 2);
        expect(valid.map((s) => s.distanceMeters), [100, 300]);
      });

      test('given an empty samples list, validSamples -> is empty, not an '
          'error', () {
        const profile = DepthProfile(available: false, samples: []);

        expect(profile.validSamples, isEmpty);
      });

      test('given every sample has a null depth, validSamples -> is empty', () {
        const profile = DepthProfile(
          available: true,
          samples: [
            DepthSample(distanceMeters: 0, depthMeters: null),
            DepthSample(distanceMeters: 100, depthMeters: null),
          ],
        );

        expect(profile.validSamples, isEmpty);
      });
    });

    group('DepthSample', () {
      test('given a land/NoData sample, depthMeters -> is null, never 0', () {
        const sample = DepthSample(distanceMeters: 0);

        expect(sample.depthMeters, isNull);
      });
    });
  });
}
