import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/models/beach_amenity.dart';
import 'package:beachiq/logic/wave_shore_relation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('classifyDirection', () {
    group('flowingToward convention (ocean current)', () {
      final cases = <String, ({double degrees, double seaward, ShoreRelation expected})>{
        'bearing equal to the seaward normal -> awayFromShore': (
          degrees: 90,
          seaward: 90,
          expected: ShoreRelation.awayFromShore,
        ),
        'bearing opposite the seaward normal -> towardShore': (
          degrees: 270,
          seaward: 90,
          expected: ShoreRelation.towardShore,
        ),
        'bearing perpendicular to the seaward normal (+90) -> alongShore': (
          degrees: 180,
          seaward: 90,
          expected: ShoreRelation.alongShore,
        ),
        'bearing perpendicular to the seaward normal (-90) -> alongShore': (
          degrees: 0,
          seaward: 90,
          expected: ShoreRelation.alongShore,
        ),
        'exactly at the 45° threshold toward seaward -> awayFromShore (inclusive)':
            (degrees: 135, seaward: 90, expected: ShoreRelation.awayFromShore),
        'just past the 45° threshold toward seaward -> alongShore': (
          degrees: 136,
          seaward: 90,
          expected: ShoreRelation.alongShore,
        ),
        'exactly at the 45° threshold toward landward -> towardShore (inclusive)':
            (degrees: 315, seaward: 90, expected: ShoreRelation.towardShore),
        'just past the 45° threshold toward landward -> alongShore': (
          degrees: 316,
          seaward: 90,
          expected: ShoreRelation.alongShore,
        ),
        'wrap-around: 350° bearing vs 10° seaward normal (20° apart) -> awayFromShore':
            (degrees: 350, seaward: 10, expected: ShoreRelation.awayFromShore),
        'wrap-around: 10° bearing vs 350° seaward normal (20° apart) -> awayFromShore':
            (degrees: 10, seaward: 350, expected: ShoreRelation.awayFromShore),
        'wrap-around: bearing/seaward both near 0°, opposite travel -> towardShore':
            (degrees: 185, seaward: 5, expected: ShoreRelation.towardShore),
        'negative and >360 inputs normalize the same as their in-range equivalents':
            (
              degrees: -270, // same ray as 90
              seaward: 450, // same ray as 90
              expected: ShoreRelation.awayFromShore,
            ),
      };

      cases.forEach((description, c) {
        test('given $description, classifyDirection -> ${c.expected}', () {
          final result = classifyDirection(
            degrees: c.degrees,
            convention: DirectionConvention.flowingToward,
            seawardBearingDegrees: c.seaward,
          );

          expect(result, c.expected);
        });
      });
    });

    group('comingFrom convention (wave direction)', () {
      test('given a wave direction equal to the seaward normal (coming from '
          'the open sea), classifyDirection -> towardShore', () {
        // Wave "direction" is where it comes FROM, so a wave whose
        // bearing matches the seaward normal is actually travelling
        // landward (seaward + 180) -> towardShore.
        final result = classifyDirection(
          degrees: 90,
          convention: DirectionConvention.comingFrom,
          seawardBearingDegrees: 90,
        );

        expect(result, ShoreRelation.towardShore);
      });

      test('given a wave direction opposite the seaward normal (coming from '
          'the shore), classifyDirection -> awayFromShore', () {
        final result = classifyDirection(
          degrees: 270,
          convention: DirectionConvention.comingFrom,
          seawardBearingDegrees: 90,
        );

        expect(result, ShoreRelation.awayFromShore);
      });

      test('given a wave direction perpendicular to the seaward normal, '
          'classifyDirection -> alongShore', () {
        final result = classifyDirection(
          degrees: 0,
          convention: DirectionConvention.comingFrom,
          seawardBearingDegrees: 90,
        );

        expect(result, ShoreRelation.alongShore);
      });

      test('given a wave bearing and seaward normal that both wrap around '
          '(350°), classifyDirection normalizes before comparing -> '
          'towardShore', () {
        // Travel direction = 350 + 180 = 530°, which normalizes to the
        // same ray as 170° — exactly opposite the 350° seaward normal, so
        // the wave is heading straight at the shore.
        final result = classifyDirection(
          degrees: 350,
          convention: DirectionConvention.comingFrom,
          seawardBearingDegrees: 350,
        );

        expect(result, ShoreRelation.towardShore);
      });
    });

    group('shoreRelationThresholdDegrees', () {
      test('is documented as a named constant equal to 45 degrees', () {
        expect(shoreRelationThresholdDegrees, 45);
      });
    });
  });

  group('seawardBearingFromGeometry', () {
    // A short synthetic east-west shoreline (a beach "way") a little north
    // of a cluster of land-side amenities (parking, cafe) a little south of
    // it. The amenities anchor the heuristic's "landward" side, so the
    // derived seaward bearing should point away from them, i.e. roughly due
    // north (0°), back toward the beach geometry.
    final shorelineGeometry = [
      const LatLng(36.000, 28.000),
      const LatLng(36.000, 28.010),
    ];
    final landSideAmenities = [
      const BeachAmenity(
        kind: AmenityKind.parking,
        position: LatLng(35.990, 28.003),
      ),
      const BeachAmenity(
        kind: AmenityKind.cafe,
        position: LatLng(35.990, 28.007),
      ),
    ];

    test('given geometry north of its amenities, '
        'seawardBearingFromGeometry -> points back toward the geometry '
        '(roughly due north, away from the amenity cluster)', () {
      final beach = Beach(
        name: 'Synthetic Beach',
        city: 'Testville',
        latitude: 36.000,
        longitude: 28.005,
        geometry: shorelineGeometry,
        amenities: landSideAmenities,
      );

      final bearing = seawardBearingFromGeometry(beach);

      expect(bearing, isNotNull);
      expect(bearing, closeTo(0, 5));
    });

    test('given geometry south of its amenities, seawardBearingFromGeometry -> '
        'points roughly due south (the opposite case)', () {
      final beach = Beach(
        name: 'Synthetic Beach',
        city: 'Testville',
        latitude: 36.000,
        longitude: 28.005,
        geometry: [const LatLng(35.990, 28.000), const LatLng(35.990, 28.010)],
        amenities: [
          const BeachAmenity(
            kind: AmenityKind.parking,
            position: LatLng(36.000, 28.005),
          ),
        ],
      );

      final bearing = seawardBearingFromGeometry(beach);

      expect(bearing, isNotNull);
      // Due south is +-180 degrees; closeTo doesn't wrap, so compare via
      // the absolute value crossing the +-180 boundary.
      expect(bearing!.abs(), greaterThan(175));
    });

    test('given a beach with no geometry, seawardBearingFromGeometry -> null '
        '(never a fabricated bearing)', () {
      final beach = Beach(
        name: 'No Geometry Beach',
        city: 'Testville',
        latitude: 36.000,
        longitude: 28.005,
        amenities: landSideAmenities,
      );

      expect(seawardBearingFromGeometry(beach), isNull);
    });

    test(
      'given a beach with geometry but no amenities, '
      'seawardBearingFromGeometry -> null (no anchor to derive a side from)',
      () {
        final beach = Beach(
          name: 'No Amenities Beach',
          city: 'Testville',
          latitude: 36.000,
          longitude: 28.005,
          geometry: shorelineGeometry,
        );

        expect(seawardBearingFromGeometry(beach), isNull);
      },
    );

    test(
      'given a beach whose geometry centroid and amenity average coincide, '
      'seawardBearingFromGeometry -> null (no stable direction to derive)',
      () {
        final beach = Beach(
          name: 'Degenerate Beach',
          city: 'Testville',
          latitude: 36.000,
          longitude: 28.005,
          geometry: const [LatLng(36.000, 28.005)],
          amenities: [
            const BeachAmenity(
              kind: AmenityKind.parking,
              position: LatLng(36.000, 28.005),
            ),
          ],
        );

        expect(seawardBearingFromGeometry(beach), isNull);
      },
    );
  });
}
