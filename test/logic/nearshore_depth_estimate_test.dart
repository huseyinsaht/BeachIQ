import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/beach_surface.dart';
import 'package:beachiq/logic/nearshore_depth_estimate.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

DepthProfile _profile(double? depthAt100) => DepthProfile(
  available: true,
  samples: [
    const DepthSample(distanceMeters: 0, depthMeters: 0.2),
    DepthSample(distanceMeters: 100, depthMeters: depthAt100),
    const DepthSample(distanceMeters: 200, depthMeters: 6),
  ],
);

void main() {
  group('parseBeachSurface', () {
    test('given the recognised OSM values, maps each kind', () {
      expect(parseBeachSurface('sand'), BeachSurface.sand);
      expect(parseBeachSurface('Sand'), BeachSurface.sand);
      expect(parseBeachSurface(' sand '), BeachSurface.sand);
      for (final v in ['pebbles', 'pebblestone', 'shingle']) {
        expect(parseBeachSurface(v), BeachSurface.pebbles, reason: v);
      }
      for (final v in ['gravel', 'fine_gravel']) {
        expect(parseBeachSurface(v), BeachSurface.gravel, reason: v);
      }
      for (final v in ['rock', 'rocks']) {
        expect(parseBeachSurface(v), BeachSurface.rock, reason: v);
      }
    });

    test('given a missing or unrecognised value, returns null', () {
      expect(parseBeachSurface(null), isNull);
      expect(parseBeachSurface(''), isNull);
      expect(parseBeachSurface('grass'), isNull);
      expect(parseBeachSurface('sand;gravel'), isNull);
    });

    test('labels are short English words', () {
      expect(beachSurfaceLabelFor('sand'), 'Sand');
      expect(beachSurfaceLabelFor('pebbles'), 'Pebbles');
      expect(beachSurfaceLabelFor('gravel'), 'Gravel');
      expect(beachSurfaceLabelFor('rock'), 'Rock');
      expect(beachSurfaceLabelFor('grass'), isNull);
      expect(beachSurfaceLabelFor(null), isNull);
    });
  });

  group('NearshoreDepthEstimate.from', () {
    test('given sand and a shallow 100 m depth, gives a range between the '
        'straight line and the steep curve', () {
      final estimate = NearshoreDepthEstimate.from(
        osmSurface: 'sand',
        profile: _profile(1.0),
      )!;

      expect(estimate.kind, NearshoreEstimateKind.range);
      expect(estimate.lowMeters, closeTo(0.10, 1e-9));
      expect(estimate.highMeters, closeTo(0.32, 1e-9));
      expect(estimate.surface, BeachSurface.sand);
    });

    test('given the model constants, they are the documented provisional '
        'factors', () {
      expect(NearshoreDepthEstimate.linearFactor, 0.10);
      expect(NearshoreDepthEstimate.steepFactor, 0.32);
      expect(NearshoreDepthEstimate.deepWarningMeters, 1.2);
    });

    test('given the upper end just below the deep limit, still a range', () {
      // 3.7 m * 0.32 = 1.184 m < 1.2 m.
      final estimate = NearshoreDepthEstimate.from(
        osmSurface: 'sand',
        profile: _profile(3.7),
      )!;

      expect(estimate.kind, NearshoreEstimateKind.range);
    });

    test('given the upper end reaching the deep limit, warns instead of '
        'giving numbers', () {
      // 3.75 m * 0.32 = 1.2 m.
      final estimate = NearshoreDepthEstimate.from(
        osmSurface: 'sand',
        profile: _profile(3.75),
      )!;

      expect(estimate.kind, NearshoreEstimateKind.mayBeDeep);
      expect(estimate.lowMeters, isNull);
      expect(estimate.highMeters, isNull);
      expect(estimate.rangeText(UnitSystem.metric), isNull);
    });

    test('given pebbles, gravel or rock, gives a qualitative warning with no '
        'numbers, even without a profile', () {
      for (final surface in ['pebbles', 'gravel', 'rock']) {
        final estimate = NearshoreDepthEstimate.from(
          osmSurface: surface,
          profile: null,
        )!;

        expect(estimate.kind, NearshoreEstimateKind.steepBeachType);
        expect(estimate.lowMeters, isNull);
        expect(estimate.rangeText(UnitSystem.metric), isNull);
      }
    });

    test('given an unknown surface, gives no estimate', () {
      expect(
        NearshoreDepthEstimate.from(osmSurface: null, profile: _profile(1)),
        isNull,
      );
      expect(
        NearshoreDepthEstimate.from(osmSurface: 'grass', profile: _profile(1)),
        isNull,
      );
    });

    test('given sand but no usable 100 m depth, gives no estimate', () {
      expect(
        NearshoreDepthEstimate.from(osmSurface: 'sand', profile: null),
        isNull,
      );
      expect(
        NearshoreDepthEstimate.from(
          osmSurface: 'sand',
          profile: const DepthProfile.unavailable(),
        ),
        isNull,
      );
      expect(
        NearshoreDepthEstimate.from(
          osmSurface: 'sand',
          profile: _profile(null),
        ),
        isNull,
      );
      expect(
        NearshoreDepthEstimate.from(osmSurface: 'sand', profile: _profile(0)),
        isNull,
      );
      expect(
        NearshoreDepthEstimate.from(osmSurface: 'sand', profile: _profile(-2)),
        isNull,
      );
    });

    test('given a profile without a 100 m sample, gives no estimate', () {
      const profile = DepthProfile(
        available: true,
        samples: [DepthSample(distanceMeters: 200, depthMeters: 2)],
      );

      expect(
        NearshoreDepthEstimate.from(osmSurface: 'sand', profile: profile),
        isNull,
      );
    });
  });

  group('rangeText', () {
    String? text(double depth100, [UnitSystem u = UnitSystem.metric]) =>
        NearshoreDepthEstimate.from(
          osmSurface: 'sand',
          profile: _profile(depth100),
        )!.rangeText(u);

    test('given a very shallow beach, says "up to" the rounded-up top', () {
      // 0.5 m -> 0.05 to 0.16 m.
      expect(text(0.5), 'up to 0.2 m');
    });

    test('given a deeper range, shows both ends rounded outward', () {
      // 3 m -> 0.30 to 0.96 m -> 0.3 to 1.0.
      expect(text(3), 'about 0.3 m to 1.0 m');
    });

    test('rounds the upper end up and the lower end down', () {
      // 2.0 m -> 0.20 to 0.64 -> 0.2 to 0.7.
      expect(text(2.0), 'about 0.2 m to 0.7 m');
    });

    test('given imperial, formats in feet', () {
      // 3 m -> 0.3 to 1.0 m -> 1.0 ft to 3.3 ft.
      expect(text(3, UnitSystem.imperial), 'about 1.0 ft to 3.3 ft');
    });
  });
}
