import 'dart:convert';

import 'package:beachiq/data/services/measured_depth_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _entry(
  String name,
  double lat,
  double lon, {
  num? radius,
}) {
  return {
    'beachName': name,
    'latitude': lat,
    'longitude': lon,
    'radiusMeters': ?radius,
    'measuredOn': '2026-10-25',
    'measuredBy': 'Vaen',
    'method': 'Marked rope and depth stick',
    'points': [
      {'distanceMeters': 1, 'depthCm': 20},
    ],
  };
}

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.text);
  final String? text;

  @override
  Future<ByteData> load(String key) async {
    if (text == null) throw Exception('missing asset');
    final bytes = utf8.encode(text!);
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  group('MeasuredDepthRepository', () {
    test('given no entries, finds nothing', () {
      expect(
        const MeasuredDepthRepository.empty().findFor(38.28, 26.37),
        isNull,
      );
    });

    test('given a position inside an entry radius, returns that entry', () {
      final repo = MeasuredDepthRepository.fromJsonString(
        jsonEncode({
          'beaches': [_entry('A', 38.2870, 26.3730, radius: 150)],
        }),
      );

      // ~44 m away.
      expect(repo.findFor(38.2874, 26.3730)?.beachName, 'A');
    });

    test('given a position outside every radius, returns null', () {
      final repo = MeasuredDepthRepository.fromJsonString(
        jsonEncode({
          'beaches': [_entry('A', 38.2870, 26.3730, radius: 150)],
        }),
      );

      // ~1.1 km away.
      expect(repo.findFor(38.2970, 26.3730), isNull);
    });

    test('given two overlapping entries, returns the closest one', () {
      final repo = MeasuredDepthRepository.fromJsonString(
        jsonEncode({
          'beaches': [
            _entry('Far', 38.2880, 26.3730, radius: 500),
            _entry('Near', 38.2871, 26.3730, radius: 500),
          ],
        }),
      );

      expect(repo.findFor(38.2870, 26.3730)?.beachName, 'Near');
    });

    test('given an invalid entry among valid ones, drops only that one', () {
      final repo = MeasuredDepthRepository.fromJsonString(
        jsonEncode({
          'beaches': [
            _entry('Good', 38.2870, 26.3730),
            {'beachName': 'Broken'},
          ],
        }),
      );

      expect(repo.entries.map((e) => e.beachName), ['Good']);
    });

    for (final raw in ['', 'not json', '[]', '{}', '{"beaches": "x"}']) {
      test('given malformed JSON ${jsonEncode(raw)}, yields no entries', () {
        expect(MeasuredDepthRepository.fromJsonString(raw).entries, isEmpty);
      });
    }

    test('load reads the entries from the asset bundle', () async {
      final repo = await MeasuredDepthRepository.load(
        bundle: _FakeBundle(
          jsonEncode({
            'beaches': [_entry('A', 38.2870, 26.3730)],
          }),
        ),
      );

      expect(repo.entries, hasLength(1));
    });

    test('load never throws when the asset is missing', () async {
      final repo = await MeasuredDepthRepository.load(
        bundle: _FakeBundle(null),
      );

      expect(repo.entries, isEmpty);
    });
  });
}
