import 'package:beachiq/logic/transect.dart';
import 'package:beachiq/logic/wave_shore_relation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../helpers/builders.dart';

const Distance _distance = Distance();
const double _toleranceMeters = 1;

void main() {
  group('transectPoints', () {
    test('given a north bearing (0°), transectPoints -> points running due '
        'north at the expected distances (<1m error)', () {
      const start = LatLng(36.90, 30.65);
      final points = transectPoints(start: start, bearingDegrees: 0);

      expect(points.length, defaultTransectDistancesMeters.length);
      // The 0m sample should be (within floating-point noise) the start
      // point itself -- not asserted with exact LatLng equality, since an
      // offset-by-zero great-circle calculation can differ from the input
      // by a tiny epsilon rather than being bit-identical.
      expect(points.first.latitude, closeTo(start.latitude, 1e-9));
      expect(points.first.longitude, closeTo(start.longitude, 1e-9));
      for (var i = 0; i < points.length; i++) {
        final actualDistance = _distance.distance(start, points[i]);
        expect(
          (actualDistance - defaultTransectDistancesMeters[i]).abs(),
          lessThan(_toleranceMeters),
        );
        if (defaultTransectDistancesMeters[i] > 0) {
          expect(points[i].latitude, greaterThan(start.latitude));
          expect(points[i].longitude, closeTo(start.longitude, 1e-6));
        }
      }
    });

    test('given an east bearing (90°), transectPoints -> points running due '
        'east at the expected distances (<1m error)', () {
      const start = LatLng(36.90, 30.65);
      final points = transectPoints(start: start, bearingDegrees: 90);

      for (var i = 0; i < points.length; i++) {
        final actualDistance = _distance.distance(start, points[i]);
        expect(
          (actualDistance - defaultTransectDistancesMeters[i]).abs(),
          lessThan(_toleranceMeters),
        );
        if (defaultTransectDistancesMeters[i] > 0) {
          expect(points[i].longitude, greaterThan(start.longitude));
          expect(points[i].latitude, closeTo(start.latitude, 1e-6));
        }
      }
    });

    test('given a southwest bearing (225°), transectPoints -> each point is '
        'the expected distance from start (<1m error)', () {
      const start = LatLng(-12.5, 150.2);
      final points = transectPoints(start: start, bearingDegrees: 225);

      for (var i = 0; i < points.length; i++) {
        final actualDistance = _distance.distance(start, points[i]);
        expect(
          (actualDistance - defaultTransectDistancesMeters[i]).abs(),
          lessThan(_toleranceMeters),
        );
      }
    });

    test(
      'given an empty distances list, transectPoints -> returns an empty list',
      () {
        final points = transectPoints(
          start: const LatLng(0, 0),
          bearingDegrees: 90,
          distancesMeters: const [],
        );

        expect(points, isEmpty);
      },
    );

    test('given a bearing at/above 360°, transectPoints -> produces the same '
        'points as the normalized bearing', () {
      const start = LatLng(10, 10);

      final wrapped = transectPoints(start: start, bearingDegrees: 450);
      final normalized = transectPoints(start: start, bearingDegrees: 90);

      expect(wrapped, normalized);
    });

    test('given a negative bearing, transectPoints -> produces the same '
        'points as the normalized positive bearing', () {
      const start = LatLng(10, 10);

      final negative = transectPoints(start: start, bearingDegrees: -90);
      final normalized = transectPoints(start: start, bearingDegrees: 270);

      expect(negative, normalized);
    });
  });

  group('seawardTransectFor', () {
    test('given a beach with no geometry, seawardTransectFor -> null', () {
      final beach = aBeach(geometry: null);

      expect(seawardTransectFor(beach), isNull);
    });

    test('given a beach with empty geometry, seawardTransectFor -> null', () {
      final beach = aBeach(geometry: const []);

      expect(seawardTransectFor(beach), isNull);
    });

    test('given a beach with geometry but no amenities to anchor a seaward '
        'bearing, seawardTransectFor -> null', () {
      final beach = aBeach(
        geometry: const [LatLng(36.90, 30.65), LatLng(36.901, 30.651)],
        amenities: const [],
      );

      expect(seawardTransectFor(beach), isNull);
    });

    test('given a beach with geometry and amenities, seawardTransectFor -> a '
        'transect starting at the geometry centroid, running along the '
        'seaward bearing, at the default distances', () {
      final geometry = [
        const LatLng(36.900, 30.650),
        const LatLng(36.902, 30.652),
      ];
      final amenities = [
        // South-west of the geometry, so the seaward bearing points
        // roughly north-east, away from the amenity cluster.
        anAmenity(position: const LatLng(36.890, 30.640)),
      ];
      final beach = aBeach(geometry: geometry, amenities: amenities);
      final seawardBearing = seawardBearingFromGeometry(beach);

      final points = seawardTransectFor(beach);

      expect(points, isNotNull);
      expect(points!.length, defaultTransectDistancesMeters.length);
      for (var i = 0; i < points.length; i++) {
        final actualDistance = _distance.distance(points.first, points[i]);
        expect(
          (actualDistance - defaultTransectDistancesMeters[i]).abs(),
          lessThan(_toleranceMeters),
        );
      }
      // The transect's own direction (first -> last point) matches the
      // seaward bearing the heuristic derived.
      final transectBearing = _distance.bearing(points.first, points.last);
      final bearingDifference = (transectBearing - seawardBearing!).abs() % 360;
      expect(
        bearingDifference < 1 || bearingDifference > 359,
        isTrue,
        reason:
            'expected transect bearing $transectBearing to match seaward '
            'bearing $seawardBearing',
      );
    });

    test('given custom distancesMeters, seawardTransectFor -> samples at '
        'those distances instead of the default', () {
      final geometry = [
        const LatLng(36.900, 30.650),
        const LatLng(36.902, 30.652),
      ];
      final amenities = [anAmenity(position: const LatLng(36.890, 30.640))];
      final beach = aBeach(geometry: geometry, amenities: amenities);

      final points = seawardTransectFor(beach, distancesMeters: const [0, 50]);

      expect(points, isNotNull);
      expect(points!.length, 2);
      expect(_distance.distance(points[0], points[1]), closeTo(50, 1));
    });
  });
}
