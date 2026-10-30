import 'package:beachiq/logic/providers/marine_provider.dart';
import 'package:beachiq/logic/providers/weather_provider.dart';
import 'package:beachiq/main.dart';
import 'package:beachiq/presentation/screens/home_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_http_client.dart';
import 'helpers/pump_app.dart';

void main() {
  group('MarineApp', () {
    group('build', () {
      testWidgets('given no providers are passed, build -> falls back to '
          'default-constructed MarineProvider/WeatherProvider wired to the '
          'real repository/API-service stack', (tester) async {
        // main() always passes its own marineProvider/weatherProvider
        // explicitly (see lib/main.dart) — this fallback branch is only
        // reached by a caller that omits them, as every widget test
        // other than this one does by passing fakes instead. It was
        // therefore never exercised by any test.
        SharedPreferences.setMockInitialValues({});
        final client = FakeHttpClient();
        // HomeScreen's initState auto-fetches the Çeşme first-run
        // default on mount (see home_screen_test.dart) — the fallback
        // WeatherProvider ends up calling exactly this.
        client.queueJson(
          host: 'api.open-meteo.com',
          pathContains: '/forecast',
          json: {
            'current': {
              'temperature_2m': 24.0,
              'wind_speed_10m': 7.0,
              'weather_code': 1,
            },
          },
        );
        client.queueJson(
          host: 'marine-api.open-meteo.com',
          pathContains: '/marine',
          json: {
            'current': {
              'wave_height': 0.5,
              'wave_direction': 200,
              'wave_period': 5,
              'sea_surface_temperature': 24.0,
            },
          },
        );

        await http.runWithClient(() async {
          await tester.pumpWidget(MarineApp(tileProvider: FakeTileProvider()));
          await tester.pumpAndSettle();

          expect(find.byType(HomeScreen), findsOneWidget);
          expect(find.byType(FlutterMap), findsOneWidget);

          final context = tester.element(find.byType(HomeScreen));
          final weatherProvider = Provider.of<WeatherProvider>(
            context,
            listen: false,
          );
          final marineProvider = Provider.of<MarineProvider>(
            context,
            listen: false,
          );

          expect(weatherProvider.error, isNull);
          expect(weatherProvider.currentData?.temperature, 24.0);

          // MarineProvider isn't auto-fetched on mount (unlike weather),
          // so drive a fetch explicitly to prove it's wired to the real
          // MarineRepository/MarineApiService stack, not just a non-null
          // instance left otherwise unexercised.
          await marineProvider.fetchData(38.3220, 26.3260);
          expect(marineProvider.error, isNull);
          expect(marineProvider.currentData?.waveHeight, 0.5);

          expect(
            client.requests.where((r) => r.url.host == 'api.open-meteo.com'),
            isNotEmpty,
          );
          expect(
            client.requests.where(
              (r) => r.url.host == 'marine-api.open-meteo.com',
            ),
            isNotEmpty,
          );
        }, () => client);
      });
    });
  });
}
