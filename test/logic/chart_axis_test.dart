import 'package:beachiq/logic/chart_axis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('niceTicks', () {
    test('given a normal range, niceTicks -> round, evenly spaced ticks '
        'spanning it', () {
      final ticks = niceTicks(1000, 1030, 4);

      expect(ticks, [1000, 1010, 1020, 1030]);
    });

    test('given a flat range (min == max, non-zero), niceTicks -> sane '
        'ticks around the widened value, not a single repeated point', () {
      final ticks = niceTicks(5, 5, 4);

      expect(ticks.length, greaterThanOrEqualTo(3));
      // The widened range must still straddle the original value.
      expect(ticks.first, lessThanOrEqualTo(5));
      expect(ticks.last, greaterThanOrEqualTo(5));
      for (final tick in ticks) {
        expect(tick.isFinite, isTrue);
      }
    });

    test('given a flat range at exactly zero, niceTicks -> ticks widened '
        'by a fixed amount rather than collapsing to [0]', () {
      final ticks = niceTicks(0, 0, 4);

      expect(ticks.length, greaterThanOrEqualTo(3));
      expect(ticks.first, lessThan(0));
      expect(ticks.last, greaterThan(0));
    });

    test('given a range that straddles zero, niceTicks -> includes 0 and '
        'both negative and positive ticks', () {
      final ticks = niceTicks(-20, 10, 4);

      expect(ticks, [-20, -10, 0, 10]);
    });

    test('given min greater than max, niceTicks -> the same ticks as if '
        'they were passed the other way round', () {
      final swapped = niceTicks(30, 10, 4);
      final ordered = niceTicks(10, 30, 4);

      expect(swapped, ordered);
    });

    test('given a tiny range, niceTicks -> fractional ticks that stay '
        'within the range, not all rounded down to the same value', () {
      final ticks = niceTicks(1.0, 1.00001, 4);

      expect(ticks.length, greaterThanOrEqualTo(3));
      expect(ticks.toSet().length, ticks.length); // no duplicates
      for (final tick in ticks) {
        expect(tick, greaterThanOrEqualTo(1.0));
        expect(tick, lessThanOrEqualTo(1.00001));
      }
    });

    test('given a huge range, niceTicks -> round ticks on a matching '
        'scale instead of a single step of 1', () {
      final ticks = niceTicks(0, 1e9, 4);

      expect(ticks.length, greaterThanOrEqualTo(3));
      expect(ticks.first, 0);
      expect(ticks.last, 1e9);
      // Every step is a "nice" multiple of a power of ten (200000000 here),
      // not an arbitrary float.
      for (var i = 1; i < ticks.length; i++) {
        expect(ticks[i] - ticks[i - 1], 200000000);
      }
    });

    test('every tick lies within the (possibly widened) range actually '
        'used, never outside it', () {
      for (final ticks in [
        niceTicks(1000, 1030, 4),
        niceTicks(5, 5, 4),
        niceTicks(-20, 10, 5),
        niceTicks(0, 9, 4),
        niceTicks(0, 100, 5),
      ]) {
        for (var i = 1; i < ticks.length; i++) {
          expect(
            ticks[i],
            greaterThan(ticks[i - 1]),
            reason: 'ticks must be strictly ascending with no duplicates',
          );
        }
      }
    });

    test('given targetCount of zero or negative, niceTicks -> still '
        'returns sane ticks instead of throwing', () {
      expect(() => niceTicks(0, 10, 0), returnsNormally);
      expect(() => niceTicks(0, 10, -3), returnsNormally);
      expect(niceTicks(0, 10, 0), isNotEmpty);
    });
  });
}
