import 'package:beachiq/data/models/measured_nearshore_depth.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _valid() => {
  'beachName': 'Ilica Beach',
  'latitude': 38.287,
  'longitude': 26.373,
  'radiusMeters': 200,
  'measuredOn': '2026-10-25',
  'measuredBy': 'Vaen',
  'method': 'Marked rope and depth stick',
  'reference': 'Water edge at 14:00',
  'note': 'Sandy bottom.',
  'points': [
    {'distanceMeters': 1, 'depthCm': 20},
    {'distanceMeters': 5, 'depthCm': 80},
    {'distanceMeters': 10, 'depthCm': 135},
  ],
};

void main() {
  group('MeasuredNearshoreDepth.tryParse', () {
    test('given a complete entry, parses every field', () {
      final entry = MeasuredNearshoreDepth.tryParse(_valid())!;

      expect(entry.beachName, 'Ilica Beach');
      expect(entry.latitude, 38.287);
      expect(entry.longitude, 26.373);
      expect(entry.radiusMeters, 200);
      expect(entry.measuredOn, DateTime(2026, 10, 25));
      expect(entry.measuredBy, 'Vaen');
      expect(entry.method, 'Marked rope and depth stick');
      expect(entry.reference, 'Water edge at 14:00');
      expect(entry.note, 'Sandy bottom.');
      expect(entry.points.map((p) => p.distanceMeters), [1, 5, 10]);
      expect(entry.points.map((p) => p.depthCm), [20, 80, 135]);
      expect(entry.points.last.depthMeters, 1.35);
    });

    test('given no radius, reference or note, uses the defaults', () {
      final json = _valid()
        ..remove('radiusMeters')
        ..remove('reference')
        ..remove('note');

      final entry = MeasuredNearshoreDepth.tryParse(json)!;

      expect(entry.radiusMeters, MeasuredNearshoreDepth.defaultRadiusMeters);
      expect(entry.reference, MeasuredNearshoreDepth.defaultReference);
      expect(entry.note, isNull);
    });

    test('given a non-map, returns null', () {
      expect(MeasuredNearshoreDepth.tryParse(null), isNull);
      expect(MeasuredNearshoreDepth.tryParse('x'), isNull);
      expect(MeasuredNearshoreDepth.tryParse([1]), isNull);
    });

    for (final key in [
      'beachName',
      'latitude',
      'longitude',
      'measuredOn',
      'measuredBy',
      'method',
      'points',
    ]) {
      test('given a missing $key, returns null', () {
        expect(MeasuredNearshoreDepth.tryParse(_valid()..remove(key)), isNull);
      });
    }

    test('given a blank method or name, returns null', () {
      expect(
        MeasuredNearshoreDepth.tryParse(_valid()..['method'] = '  '),
        isNull,
      );
      expect(
        MeasuredNearshoreDepth.tryParse(_valid()..['beachName'] = ''),
        isNull,
      );
    });

    test('given an unparseable date, returns null', () {
      expect(
        MeasuredNearshoreDepth.tryParse(_valid()..['measuredOn'] = 'yesterday'),
        isNull,
      );
    });

    test('given out-of-range coordinates, returns null', () {
      expect(
        MeasuredNearshoreDepth.tryParse(_valid()..['latitude'] = 91),
        isNull,
      );
      expect(
        MeasuredNearshoreDepth.tryParse(_valid()..['longitude'] = -181),
        isNull,
      );
    });

    test('given a radius outside 25-1000 m, returns null', () {
      expect(
        MeasuredNearshoreDepth.tryParse(_valid()..['radiusMeters'] = 10),
        isNull,
      );
      expect(
        MeasuredNearshoreDepth.tryParse(_valid()..['radiusMeters'] = 5000),
        isNull,
      );
    });

    test('given empty points, returns null', () {
      expect(
        MeasuredNearshoreDepth.tryParse(_valid()..['points'] = []),
        isNull,
      );
    });

    test('given a point farther than 10 m or at 0 m, returns null', () {
      for (final bad in [0, 11]) {
        expect(
          MeasuredNearshoreDepth.tryParse(
            _valid()
              ..['points'] = [
                {'distanceMeters': bad, 'depthCm': 50},
              ],
          ),
          isNull,
          reason: 'distance $bad',
        );
      }
    });

    test('given unordered or duplicate distances, returns null', () {
      expect(
        MeasuredNearshoreDepth.tryParse(
          _valid()
            ..['points'] = [
              {'distanceMeters': 5, 'depthCm': 80},
              {'distanceMeters': 2, 'depthCm': 40},
            ],
        ),
        isNull,
      );
      expect(
        MeasuredNearshoreDepth.tryParse(
          _valid()
            ..['points'] = [
              {'distanceMeters': 5, 'depthCm': 80},
              {'distanceMeters': 5, 'depthCm': 85},
            ],
        ),
        isNull,
      );
    });

    test('given a negative or absurd depth, or non-integers, returns null', () {
      for (final bad in [
        {'distanceMeters': 3, 'depthCm': -1},
        {'distanceMeters': 3, 'depthCm': 5000},
        {'distanceMeters': 3, 'depthCm': 12.5},
        {'distanceMeters': 3.5, 'depthCm': 50},
        {'distanceMeters': '3', 'depthCm': 50},
      ]) {
        expect(
          MeasuredNearshoreDepth.tryParse(_valid()..['points'] = [bad]),
          isNull,
          reason: '$bad',
        );
      }
    });

    test('given more than 12 points, returns null', () {
      expect(
        MeasuredNearshoreDepth.tryParse(
          _valid()
            ..['points'] = [
              for (var i = 1; i <= 13; i++)
                {'distanceMeters': i, 'depthCm': i * 10},
            ],
        ),
        isNull,
      );
    });
  });
}
