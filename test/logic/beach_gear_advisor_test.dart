import 'package:beachiq/logic/beach_gear_advisor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('adviseOnShoes', () {
    test('advises shoes for pebbles', () {
      expect(adviseOnShoes('pebbles'), ShoeAdvice.advised);
    });

    test('advises shoes for pebblestone', () {
      expect(adviseOnShoes('pebblestone'), ShoeAdvice.advised);
    });

    test('advises shoes for gravel', () {
      expect(adviseOnShoes('gravel'), ShoeAdvice.advised);
    });

    test('advises shoes for rock', () {
      expect(adviseOnShoes('rock'), ShoeAdvice.advised);
    });

    test('says shoes are not needed for sand', () {
      expect(adviseOnShoes('sand'), ShoeAdvice.notNeeded);
    });

    test('is unknown when surface is null', () {
      expect(adviseOnShoes(null), ShoeAdvice.unknown);
    });

    test('is unknown when surface is empty', () {
      expect(adviseOnShoes(''), ShoeAdvice.unknown);
    });

    test('is unknown for an unrecognized surface', () {
      expect(adviseOnShoes('grass'), ShoeAdvice.unknown);
    });

    test('is case-insensitive', () {
      expect(adviseOnShoes('Sand'), ShoeAdvice.notNeeded);
      expect(adviseOnShoes('ROCK'), ShoeAdvice.advised);
    });
  });
}
