import 'package:beachiq/data/models/sea_condition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeaCondition.fromJson', () {
    test('parses all fields including sea_surface_temperature', () {
      final condition = SeaCondition.fromJson({
        'wave_height': 1.2,
        'wave_direction': 180.0,
        'wave_period': 6.5,
        'sea_surface_temperature': 21.3,
      });

      expect(condition.waveHeight, 1.2);
      expect(condition.waveDirection, 180.0);
      expect(condition.wavePeriod, 6.5);
      expect(condition.seaSurfaceTemperature, 21.3);
    });

    test('defaults missing fields to 0', () {
      final condition = SeaCondition.fromJson({});

      expect(condition.waveHeight, 0);
      expect(condition.waveDirection, 0);
      expect(condition.wavePeriod, 0);
      expect(condition.seaSurfaceTemperature, 0);
    });
  });
}
