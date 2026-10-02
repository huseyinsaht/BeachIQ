import 'package:beachiq/logic/uv_band.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uvBandFor', () {
    final cases = <({String description, double uvIndex, UvBand expected})>[
      (description: 'the middle of low (0)', uvIndex: 0, expected: UvBand.low),
      (description: 'the middle of low (2)', uvIndex: 2, expected: UvBand.low),
      (
        description: 'just under the low/moderate boundary (2.9)',
        uvIndex: 2.9,
        expected: UvBand.low,
      ),
      (
        description: 'exactly the low/moderate boundary (3.0)',
        uvIndex: 3.0,
        expected: UvBand.moderate,
      ),
      (
        description: 'just under the moderate/high boundary (5.9)',
        uvIndex: 5.9,
        expected: UvBand.moderate,
      ),
      (
        description: 'exactly the moderate/high boundary (6.0)',
        uvIndex: 6.0,
        expected: UvBand.high,
      ),
      (
        description: 'just under the high/very-high boundary (7.9)',
        uvIndex: 7.9,
        expected: UvBand.high,
      ),
      (
        description: 'exactly the high/very-high boundary (8.0)',
        uvIndex: 8.0,
        expected: UvBand.veryHigh,
      ),
      (
        description: 'just under the very-high/extreme boundary (10.9)',
        uvIndex: 10.9,
        expected: UvBand.veryHigh,
      ),
      (
        description: 'exactly the very-high/extreme boundary (11.0)',
        uvIndex: 11.0,
        expected: UvBand.extreme,
      ),
      (
        description: 'a far-above-extreme reading (15)',
        uvIndex: 15,
        expected: UvBand.extreme,
      ),
    ];

    for (final c in cases) {
      test('given ${c.description}, uvBandFor -> ${c.expected}', () {
        expect(uvBandFor(c.uvIndex), c.expected);
      });
    }
  });

  group('uvBandLabel', () {
    test('given low, uvBandLabel -> "Low"', () {
      expect(uvBandLabel(UvBand.low), 'Low');
    });

    test('given moderate, uvBandLabel -> "Moderate"', () {
      expect(uvBandLabel(UvBand.moderate), 'Moderate');
    });

    test('given high, uvBandLabel -> "High"', () {
      expect(uvBandLabel(UvBand.high), 'High');
    });

    test('given veryHigh, uvBandLabel -> "Very high"', () {
      expect(uvBandLabel(UvBand.veryHigh), 'Very high');
    });

    test('given extreme, uvBandLabel -> "Extreme"', () {
      expect(uvBandLabel(UvBand.extreme), 'Extreme');
    });
  });

  group('uvProtectionHint', () {
    test('every band has a non-empty, distinct hint', () {
      final hints = UvBand.values.map(uvProtectionHint).toList();

      for (final hint in hints) {
        expect(hint, isNotEmpty);
      }
      expect(hints.toSet(), hasLength(UvBand.values.length));
    });
  });
}
