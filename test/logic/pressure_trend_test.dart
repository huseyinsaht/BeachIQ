import 'package:beachiq/logic/pressure_trend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyPressureTrend', () {
    final cases =
        <
          ({
            String description,
            double? currentHpa,
            double? earlierHpa,
            PressureTrend? expected,
          })
        >[
          (
            description: 'clearly rising (+5 hPa)',
            currentHpa: 1018.0,
            earlierHpa: 1013.0,
            expected: PressureTrend.rising,
          ),
          (
            description: 'clearly falling (-5 hPa)',
            currentHpa: 1008.0,
            earlierHpa: 1013.0,
            expected: PressureTrend.falling,
          ),
          (
            description: 'no change at all',
            currentHpa: 1013.0,
            earlierHpa: 1013.0,
            expected: PressureTrend.steady,
          ),
          (
            description: 'near-zero change (+0.2 hPa)',
            currentHpa: 1013.2,
            earlierHpa: 1013.0,
            expected: PressureTrend.steady,
          ),
          (
            description: 'just under the rising boundary (+0.9 hPa)',
            currentHpa: 1013.9,
            earlierHpa: 1013.0,
            expected: PressureTrend.steady,
          ),
          (
            description: 'exactly the rising boundary (+1.0 hPa, inclusive)',
            currentHpa: 1014.0,
            earlierHpa: 1013.0,
            expected: PressureTrend.rising,
          ),
          (
            description: 'just over the falling boundary (-0.9 hPa)',
            currentHpa: 1012.1,
            earlierHpa: 1013.0,
            expected: PressureTrend.steady,
          ),
          (
            description: 'exactly the falling boundary (-1.0 hPa, inclusive)',
            currentHpa: 1012.0,
            earlierHpa: 1013.0,
            expected: PressureTrend.falling,
          ),
          (
            description:
                'given a null current reading, returns null (not steady)',
            currentHpa: null,
            earlierHpa: 1013.0,
            expected: null,
          ),
          (
            description:
                'given a null earlier reading, returns null (not steady)',
            currentHpa: 1013.0,
            earlierHpa: null,
            expected: null,
          ),
          (
            description: 'given both readings missing, returns null',
            currentHpa: null,
            earlierHpa: null,
            expected: null,
          ),
        ];

    for (final c in cases) {
      test(
        'given ${c.description}, classifyPressureTrend -> ${c.expected}',
        () {
          final result = classifyPressureTrend(
            currentHpa: c.currentHpa,
            earlierHpa: c.earlierHpa,
          );

          expect(result, c.expected);
        },
      );
    }
  });

  group('pressureTrendLabel', () {
    test('given rising, pressureTrendLabel -> "Rising"', () {
      expect(pressureTrendLabel(PressureTrend.rising), 'Rising');
    });

    test('given steady, pressureTrendLabel -> "Steady"', () {
      expect(pressureTrendLabel(PressureTrend.steady), 'Steady');
    });

    test('given falling, pressureTrendLabel -> "Falling"', () {
      expect(pressureTrendLabel(PressureTrend.falling), 'Falling');
    });
  });

  group('pressureTrendExplanation', () {
    test('every trend has a non-empty explanation', () {
      for (final trend in PressureTrend.values) {
        expect(pressureTrendExplanation(trend), isNotEmpty);
      }
    });
  });
}
