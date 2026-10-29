import 'package:beachiq/logic/beach_surface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBeachSurface', () {
    test('given null, parseBeachSurface -> null', () {
      expect(parseBeachSurface(null), isNull);
    });

    test('given an empty string, parseBeachSurface -> null', () {
      expect(parseBeachSurface(''), isNull);
    });

    test('given an unrecognised value, parseBeachSurface -> null', () {
      expect(parseBeachSurface('grass'), isNull);
    });

    test('given a list of several OSM values, parseBeachSurface -> null', () {
      expect(parseBeachSurface('sand;rock'), isNull);
    });

    final cases =
        <({String description, String osmSurface, BeachSurface expected})>[
          (
            description: 'sand',
            osmSurface: 'sand',
            expected: BeachSurface.sand,
          ),
          (
            description: 'pebbles',
            osmSurface: 'pebbles',
            expected: BeachSurface.pebbles,
          ),
          (
            description: 'pebblestone (OSM alias of pebbles)',
            osmSurface: 'pebblestone',
            expected: BeachSurface.pebbles,
          ),
          (
            description: 'shingle (OSM alias of pebbles)',
            osmSurface: 'shingle',
            expected: BeachSurface.pebbles,
          ),
          (
            description: 'gravel',
            osmSurface: 'gravel',
            expected: BeachSurface.gravel,
          ),
          (
            description: 'fine_gravel (OSM alias of gravel)',
            osmSurface: 'fine_gravel',
            expected: BeachSurface.gravel,
          ),
          (
            description: 'rock',
            osmSurface: 'rock',
            expected: BeachSurface.rock,
          ),
          (
            description: 'rocks (OSM alias of rock)',
            osmSurface: 'rocks',
            expected: BeachSurface.rock,
          ),
        ];

    for (final c in cases) {
      test('given the OSM value "${c.osmSurface}" (${c.description}), '
          'parseBeachSurface -> ${c.expected}', () {
        expect(parseBeachSurface(c.osmSurface), c.expected);
      });

      test(
        'given "${c.osmSurface}" in upper case, parseBeachSurface -> ${c.expected}',
        () {
          expect(parseBeachSurface(c.osmSurface.toUpperCase()), c.expected);
        },
      );

      test('given "${c.osmSurface}" with surrounding whitespace, '
          'parseBeachSurface -> ${c.expected}', () {
        expect(parseBeachSurface('  ${c.osmSurface}  '), c.expected);
      });
    }
  });

  group('beachSurfaceLabel', () {
    test('given sand, beachSurfaceLabel -> "Sand"', () {
      expect(beachSurfaceLabel(BeachSurface.sand), 'Sand');
    });

    test('given pebbles, beachSurfaceLabel -> "Pebbles"', () {
      expect(beachSurfaceLabel(BeachSurface.pebbles), 'Pebbles');
    });

    test('given gravel, beachSurfaceLabel -> "Gravel"', () {
      expect(beachSurfaceLabel(BeachSurface.gravel), 'Gravel');
    });

    test('given rock, beachSurfaceLabel -> "Rock"', () {
      expect(beachSurfaceLabel(BeachSurface.rock), 'Rock');
    });

    test('every surface has a non-empty, distinct label', () {
      final labels = BeachSurface.values.map(beachSurfaceLabel).toList();

      for (final label in labels) {
        expect(label, isNotEmpty);
      }
      expect(labels.toSet(), hasLength(BeachSurface.values.length));
    });
  });

  group('beachSurfaceLabelFor', () {
    test('given null, beachSurfaceLabelFor -> null', () {
      expect(beachSurfaceLabelFor(null), isNull);
    });

    test('given an unrecognised OSM value, beachSurfaceLabelFor -> null', () {
      expect(beachSurfaceLabelFor('dirt'), isNull);
    });

    test('given "sand", beachSurfaceLabelFor -> "Sand"', () {
      expect(beachSurfaceLabelFor('sand'), 'Sand');
    });

    test(
      'given "shingle" (an alias of pebbles), beachSurfaceLabelFor -> "Pebbles"',
      () {
        expect(beachSurfaceLabelFor('shingle'), 'Pebbles');
      },
    );
  });
}
