import 'package:beachiq/logic/wind_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windStatusFor', () {
    final cases =
        <({String description, double? windSpeedKmh, WindStatus? expected})>[
          (description: 'null (no data)', windSpeedKmh: null, expected: null),
          (
            description: 'the middle of calm (0 km/h)',
            windSpeedKmh: 0,
            expected: WindStatus.calm,
          ),
          (
            description: 'just under the calm/moderate boundary (19.9 km/h)',
            windSpeedKmh: 19.9,
            expected: WindStatus.calm,
          ),
          (
            description:
                'exactly the calm/moderate boundary (20 km/h, '
                'swim_suitability.dart\'s moderateWindSpeedKmh)',
            windSpeedKmh: 20,
            expected: WindStatus.moderate,
          ),
          (
            description: 'the middle of moderate (30 km/h)',
            windSpeedKmh: 30,
            expected: WindStatus.moderate,
          ),
          (
            description:
                'just under the moderate/strong boundary '
                '(39.9 km/h)',
            windSpeedKmh: 39.9,
            expected: WindStatus.moderate,
          ),
          (
            description:
                'exactly the moderate/strong boundary (40 km/h, '
                'swim_suitability.dart\'s highWindSpeedKmh)',
            windSpeedKmh: 40,
            expected: WindStatus.strong,
          ),
          (
            description: 'far above the strong boundary (80 km/h)',
            windSpeedKmh: 80,
            expected: WindStatus.strong,
          ),
        ];

    for (final c in cases) {
      test('given ${c.description}, windStatusFor -> ${c.expected}', () {
        expect(windStatusFor(c.windSpeedKmh), c.expected);
      });
    }
  });

  group('windStatusLabel', () {
    test('given calm, windStatusLabel -> "Calm"', () {
      expect(windStatusLabel(WindStatus.calm), 'Calm');
    });

    test('given moderate, windStatusLabel -> "Moderate"', () {
      expect(windStatusLabel(WindStatus.moderate), 'Moderate');
    });

    test('given strong, windStatusLabel -> "Strong"', () {
      expect(windStatusLabel(WindStatus.strong), 'Strong');
    });
  });

  group('windStatusColor', () {
    test('every status has a distinct, opaque color', () {
      final colors = WindStatus.values.map(windStatusColor).toList();

      for (final color in colors) {
        expect(color.a, 1.0);
      }
      expect(colors.toSet(), hasLength(WindStatus.values.length));
    });
  });
}
