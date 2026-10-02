import 'dart:convert';

import 'package:beachiq/data/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('MarineApiService.getSeaData', () {
    test('decodes a successful 200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'current': {
              'wave_height': 1.2,
              'sea_surface_temperature': 24.5,
              'wave_period': 6.0,
              'wave_direction': 180,
            },
          }),
          200,
        );
      });

      await http.runWithClient(() async {
        final data = await MarineApiService().getSeaData(38.3, 26.3);

        expect(data['current']['wave_height'], 1.2);
        expect(data['current']['sea_surface_temperature'], 24.5);
      }, () => mockClient);
    });

    test('throws a clear error on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      await http.runWithClient(() async {
        await expectLater(
          () => MarineApiService().getSeaData(38.3, 26.3),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('503'),
            ),
          ),
        );
      }, () => mockClient);
    });

    test('wraps a network error in a clear exception', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      await http.runWithClient(() async {
        await expectLater(
          () => MarineApiService().getSeaData(38.3, 26.3),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Network Error'),
            ),
          ),
        );
      }, () => mockClient);
    });

    test('sends the expected latitude/longitude and fields', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(json.encode({'current': {}}), 200);
      });

      await http.runWithClient(() async {
        await MarineApiService().getSeaData(38.3, 26.3);

        final uri = capturedRequest!.url;
        expect(uri.host, 'marine-api.open-meteo.com');
        expect(uri.queryParameters['latitude'], '38.3');
        expect(uri.queryParameters['longitude'], '26.3');
        const expectedFields =
            'wave_height,sea_surface_temperature,wave_period,wave_direction,'
            'ocean_current_velocity,ocean_current_direction';
        expect(uri.queryParameters['current'], expectedFields);
        expect(uri.queryParameters['hourly'], expectedFields);
      }, () => mockClient);
    });
  });
}
