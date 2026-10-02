import 'dart:convert';

import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('WeatherApiService.getWeatherData', () {
    test('decodes a successful 200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'current': {
              'temperature_2m': 27.5,
              'wind_speed_10m': 12.0,
              'weather_code': 1,
            },
          }),
          200,
        );
      });

      await http.runWithClient(() async {
        final data = await WeatherApiService().getWeatherData(38.3, 26.3);

        expect(data['current']['temperature_2m'], 27.5);
        expect(data['current']['wind_speed_10m'], 12.0);
      }, () => mockClient);
    });

    test('throws a clear error on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      await http.runWithClient(() async {
        await expectLater(
          () => WeatherApiService().getWeatherData(38.3, 26.3),
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
          () => WeatherApiService().getWeatherData(38.3, 26.3),
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
        await WeatherApiService().getWeatherData(38.3, 26.3);

        final uri = capturedRequest!.url;
        expect(uri.host, 'api.open-meteo.com');
        expect(uri.queryParameters['latitude'], '38.3');
        expect(uri.queryParameters['longitude'], '26.3');
        expect(
          uri.queryParameters['current'],
          'temperature_2m,wind_speed_10m,weather_code',
        );
        expect(
          uri.queryParameters['hourly'],
          'temperature_2m,weather_code,uv_index,precipitation_probability,'
          'pressure_msl,wind_speed_10m,wind_gusts_10m,cloud_cover',
        );
        expect(
          uri.queryParameters['daily'],
          'temperature_2m_max,temperature_2m_min',
        );
      }, () => mockClient);
    });
  });
}
