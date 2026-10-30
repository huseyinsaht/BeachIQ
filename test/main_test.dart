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
      testWidgets(
        'given no marineProvider/weatherProvider are passed (the real '
        'main() call site never passes them either), build -> wires '
        'HomeScreen to real default-constructed MarineProvider/'
        'WeatherProvider instances that actually fetch through the real '
        'repository/API-service stack, not a widget-test double left '
        'unexercised',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final client = FakeHttpClient();
          // HomeScreen's initState auto-fetches the Çeşme first-run
          // default on mount (see home_screen_test.dart) — the default
          // WeatherProvider MarineApp.build() creates when none is passed
          // ends up calling exactly this.
          client.queueJson(
            host: 'api.open-meteo.com',
            json: {
              'current': {
                'temperature_2m': 24.0,
                'wind_speed_10m': 7.0,
                'weather_code': 1,
              },
            },
          );

          await http.runWithClient(() async {
            await tester.pumpWidget(
              MarineApp(tileProvider: FakeTileProvider()),
            );
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
            // MarineProvider is wired the same way, but (unlike weather)
            // never auto-fetched until a location is picked — this just
            // proves the real instance exists rather than being left null.
            expect(marineProvider.currentData, isNull);
            expect(marineProvider.error, isNull);

            expect(
              client.requests.where((r) => r.url.host == 'api.open-meteo.com'),
              isNotEmpty,
            );
          }, () => client);
        },
      );
    });
  });
}
