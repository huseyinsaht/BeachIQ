import 'dart:convert';
import 'dart:typed_data';

import 'package:beachiq/data/services/seabed_map_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Minimal valid 1x1 transparent PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

void main() {
  group('SeabedMapRepository', () {
    late SharedPreferences prefs;
    late List<http.Request> requests;
    late DateTime clock;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      requests = [];
      clock = DateTime(2026, 10, 25);
    });

    SeabedMapRepository build(
      Future<http.Response> Function(http.Request) handler,
    ) {
      return SeabedMapRepository(
        MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
        prefs,
        now: () => clock,
      );
    }

    group('mapUri', () {
      test('given a beach, requests a 4 km square GetMap around it, lat/lon '
          'axis order, from the EMODnet WMS', () {
        final uri = SeabedMapRepository.mapUri(38.32, 26.30);

        expect(uri.host, 'ows.emodnet-bathymetry.eu');
        expect(uri.path, '/wms');
        expect(uri.queryParameters['request'], 'GetMap');
        expect(uri.queryParameters['version'], '1.3.0');
        expect(uri.queryParameters['crs'], 'EPSG:4326');
        expect(
          uri.queryParameters['layers'],
          'emodnet:mean_atlas_land,emodnet:contours',
        );
        expect(uri.queryParameters['format'], 'image/png');
        expect(uri.queryParameters['width'], '512');
        expect(uri.queryParameters['height'], '512');

        final bbox = uri.queryParameters['bbox']!
            .split(',')
            .map(double.parse)
            .toList();
        // minLat,minLon,maxLat,maxLon, centred on the beach.
        expect(bbox[0], lessThan(38.32));
        expect(bbox[2], greaterThan(38.32));
        expect(bbox[1], lessThan(26.30));
        expect(bbox[3], greaterThan(26.30));
        expect((bbox[0] + bbox[2]) / 2, closeTo(38.32, 1e-4));
        expect((bbox[1] + bbox[3]) / 2, closeTo(26.30, 1e-4));
        // ~4 km tall: 4000 m / 111,320 m per degree.
        expect(bbox[2] - bbox[0], closeTo(4000 / 111320, 1e-4));
        // Longitude span is wider in degrees than latitude span at 38 N.
        expect(bbox[3] - bbox[1], greaterThan(bbox[2] - bbox[0]));
      });
    });

    group('getMap', () {
      test('given a PNG reply, returns the bytes and sends the app '
          'user agent', () async {
        final repo = build((_) async => http.Response.bytes(_png, 200));

        final bytes = await repo.getMap(38.32, 26.30);

        expect(bytes, _png);
        expect(requests.single.headers['User-Agent'], contains('BeachIQ'));
      });

      test(
        'given a fresh cache hit, does not call the network again',
        () async {
          final repo = build((_) async => http.Response.bytes(_png, 200));

          await repo.getMap(38.32, 26.30);
          final second = await repo.getMap(38.32, 26.30);

          expect(second, _png);
          expect(requests, hasLength(1));
        },
      );

      test('given a cache entry older than 90 days, fetches again', () async {
        final repo = build((_) async => http.Response.bytes(_png, 200));

        await repo.getMap(38.32, 26.30);
        clock = clock.add(const Duration(days: 91));
        await repo.getMap(38.32, 26.30);

        expect(requests, hasLength(2));
      });

      test(
        'given two beaches in different places, caches them separately',
        () async {
          final repo = build((_) async => http.Response.bytes(_png, 200));

          await repo.getMap(38.32, 26.30);
          await repo.getMap(36.55, 29.12);

          expect(requests, hasLength(2));
        },
      );

      test('given an XML ServiceException with HTTP 200, returns null and '
          'does not cache it', () async {
        final repo = build(
          (_) async => http.Response('<ServiceExceptionReport/>', 200),
        );

        expect(await repo.getMap(38.32, 26.30), isNull);
        expect(await repo.getMap(38.32, 26.30), isNull);
        expect(requests, hasLength(2));
      });

      test('given a non-200 reply, returns null', () async {
        final repo = build((_) async => http.Response.bytes(_png, 502));

        expect(await repo.getMap(38.32, 26.30), isNull);
      });

      test('given a network error, returns null instead of throwing', () async {
        final repo = build((_) async => throw http.ClientException('offline'));

        expect(await repo.getMap(38.32, 26.30), isNull);
      });

      test('given a corrupt cache entry, ignores it and fetches', () async {
        SharedPreferences.setMockInitialValues({
          'seabed_map_v1:38.320_26.300': 'not json',
        });
        prefs = await SharedPreferences.getInstance();
        final repo = build((_) async => http.Response.bytes(_png, 200));

        expect(await repo.getMap(38.32, 26.30), _png);
        expect(requests, hasLength(1));
      });
    });

    group('getLegend', () {
      test('requests the GetLegendGraphic image once and caches it', () async {
        final repo = build((_) async => http.Response.bytes(_png, 200));

        expect(await repo.getLegend(), _png);
        expect(await repo.getLegend(), _png);

        expect(requests, hasLength(1));
        expect(
          requests.single.url.queryParameters['request'],
          'GetLegendGraphic',
        );
      });
    });
  });
}
