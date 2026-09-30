import 'package:beachiq/logic/swim_suitability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scoreSwimSuitability', () {
    test('is good for calm conditions', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.2,
        windSpeedKmh: 8,
        rainChancePercent: 5,
      );

      expect(verdict.level, SwimSuitabilityLevel.good);
      expect(verdict.message, isNotEmpty);
    });

    test('is poor for high wave height', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 1.5,
        windSpeedKmh: 8,
        rainChancePercent: 5,
      );

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('is poor for high wind speed', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.2,
        windSpeedKmh: 45,
        rainChancePercent: 5,
      );

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('is poor for high rain chance', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.2,
        windSpeedKmh: 8,
        rainChancePercent: 80,
      );

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('is caution for moderate wave height', () {
      final verdict = scoreSwimSuitability(waveHeightM: 0.8);

      expect(verdict.level, SwimSuitabilityLevel.caution);
    });

    test('is caution for moderate wind speed', () {
      final verdict = scoreSwimSuitability(windSpeedKmh: 25);

      expect(verdict.level, SwimSuitabilityLevel.caution);
    });

    test('is caution for moderate rain chance', () {
      final verdict = scoreSwimSuitability(rainChancePercent: 50);

      expect(verdict.level, SwimSuitabilityLevel.caution);
    });

    test('takes the worst level across independently fine inputs', () {
      final verdict = scoreSwimSuitability(
        waveHeightM: 0.1, // calm
        windSpeedKmh: 45, // rough
        rainChancePercent: 5, // fine
      );

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });

    test('is unknown when every input is missing', () {
      final verdict = scoreSwimSuitability();

      expect(verdict.level, SwimSuitabilityLevel.unknown);
      expect(verdict.message, isNotEmpty);
    });

    test('scores from a single available input without crashing', () {
      final verdict = scoreSwimSuitability(waveHeightM: 0.3);

      expect(verdict.level, SwimSuitabilityLevel.good);
    });

    test('boundary wave height counts as poor, not caution', () {
      final verdict = scoreSwimSuitability(waveHeightM: 1.2);

      expect(verdict.level, SwimSuitabilityLevel.poor);
    });
  });
}
