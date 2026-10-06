import 'package:beachiq/logic/rain_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rainChanceStatusFor', () {
    final cases =
        <
          ({
            String description,
            double? rainChancePercent,
            RainChanceStatus? expected,
          })
        >[
          (
            description: 'null (no data)',
            rainChancePercent: null,
            expected: null,
          ),
          (
            description: 'the middle of low (0%)',
            rainChancePercent: 0,
            expected: RainChanceStatus.low,
          ),
          (
            description: 'just under the low/medium boundary (39.9%)',
            rainChancePercent: 39.9,
            expected: RainChanceStatus.low,
          ),
          (
            description:
                'exactly the low/medium boundary (40%, '
                'swim_suitability.dart\'s moderateRainChancePercent)',
            rainChancePercent: 40,
            expected: RainChanceStatus.medium,
          ),
          (
            description: 'the middle of medium (55%)',
            rainChancePercent: 55,
            expected: RainChanceStatus.medium,
          ),
          (
            description: 'just under the medium/high boundary (69.9%)',
            rainChancePercent: 69.9,
            expected: RainChanceStatus.medium,
          ),
          (
            description:
                'exactly the medium/high boundary (70%, '
                'swim_suitability.dart\'s highRainChancePercent)',
            rainChancePercent: 70,
            expected: RainChanceStatus.high,
          ),
          (
            description: 'far above the high boundary (100%)',
            rainChancePercent: 100,
            expected: RainChanceStatus.high,
          ),
        ];

    for (final c in cases) {
      test('given ${c.description}, rainChanceStatusFor -> ${c.expected}', () {
        expect(rainChanceStatusFor(c.rainChancePercent), c.expected);
      });
    }
  });

  group('rainChanceStatusLabel', () {
    test('given low, rainChanceStatusLabel -> "Low"', () {
      expect(rainChanceStatusLabel(RainChanceStatus.low), 'Low');
    });

    test('given medium, rainChanceStatusLabel -> "Medium"', () {
      expect(rainChanceStatusLabel(RainChanceStatus.medium), 'Medium');
    });

    test('given high, rainChanceStatusLabel -> "High"', () {
      expect(rainChanceStatusLabel(RainChanceStatus.high), 'High');
    });
  });

  group('rainChanceStatusColor', () {
    test('every status has a distinct, opaque color', () {
      final colors = RainChanceStatus.values
          .map(rainChanceStatusColor)
          .toList();

      for (final color in colors) {
        expect(color.a, 1.0);
      }
      expect(colors.toSet(), hasLength(RainChanceStatus.values.length));
    });
  });
}
