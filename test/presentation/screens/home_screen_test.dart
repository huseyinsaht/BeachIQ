import 'package:beachiq/presentation/screens/home_screen.dart';
import 'package:beachiq/presentation/screens/search_screen.dart';
import 'package:beachiq/presentation/widgets/cloud_backdrop.dart';
import 'package:beachiq/presentation/widgets/forecast_alert_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/builders.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('HomeScreen cloud backdrop (issue #162)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders a CloudBackdrop behind the header', (tester) async {
      await pumpApp(tester, const HomeScreen());

      expect(find.byType(CloudBackdrop), findsOneWidget);
    });

    testWidgets('the CloudBackdrop is wrapped in IgnorePointer', (
      tester,
    ) async {
      await pumpApp(tester, const HomeScreen());

      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(CloudBackdrop),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets(
      'given the backdrop stacked over the screen, opening Search via the '
      'map card overflow still works (hit-testing is not blocked anywhere '
      'on the screen)',
      (tester) async {
        await pumpApp(tester, const HomeScreen());
        expect(find.byType(CloudBackdrop), findsOneWidget);

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beaches'));
        await tester.pumpAndSettle();

        expect(find.byType(SearchScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets(
      'the backdrop is positioned top-right, behind (before, in paint '
      'order) the screen content in the Stack',
      (tester) async {
        await pumpApp(tester, const HomeScreen());

        final positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byType(CloudBackdrop),
            matching: find.byType(Positioned),
          ),
        );
        expect(positioned.top, 0);
        expect(positioned.right, 0);

        final stack = tester.widget<Stack>(
          find.ancestor(
            of: find.byType(CloudBackdrop),
            matching: find.byType(Stack),
          ),
        );
        final backdropIndex = stack.children.indexWhere(
          (child) => child is Positioned,
        );
        // SafeArea (the real content) must come after the backdrop in the
        // Stack's children so it paints on top, keeping the backdrop purely
        // decorative and underneath everything interactive.
        final safeAreaIndex = stack.children.indexWhere(
          (child) => child is SafeArea,
        );
        expect(backdropIndex, greaterThanOrEqualTo(0));
        expect(safeAreaIndex, greaterThan(backdropIndex));
      },
    );
  });

  group('HomeScreen forecast alerts (issue #169)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    final now = DateTime(2026, 1, 1, 8, 30);
    DateTime h(int hour) => DateTime(2026, 1, 1, hour);

    testWidgets(
      'given no upcoming wind/wave/rain/current transitions, build -> does '
      'not render ForecastAlertList at all (no widget, no gap)',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(9), windSpeed: 10, rainChancePercent: 5),
              aWeatherHourly(time: h(10), windSpeed: 10, rainChancePercent: 5),
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => now),
        );

        expect(find.byType(ForecastAlertList), findsNothing);
      },
    );

    testWidgets(
      'given a wind reading that crosses the high threshold, build -> '
      'shows a ForecastAlertList row with its icon, message and time '
      'window',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(time: h(9), windSpeed: 10),
              aWeatherHourly(time: h(10), windSpeed: 45), // crosses 40 km/h
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => now),
        );

        expect(find.byType(ForecastAlertList), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ForecastAlertList),
            matching: find.byIcon(Icons.air),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Wind crosses 40 km/h'),
          findsOneWidget,
        );
        expect(find.text('09:00 - 10:00'), findsOneWidget);
      },
    );

    testWidgets(
      'given both a high-severity wind crossing and a later moderate rain '
      'crossing, build -> lists the high-severity alert before the '
      'moderate one',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(
            hourly: [
              aWeatherHourly(
                time: h(9),
                windSpeed: 10,
                rainChancePercent: 10,
              ),
              aWeatherHourly(
                time: h(10),
                windSpeed: 45, // crosses the high (40) threshold
                rainChancePercent: 10,
              ),
              aWeatherHourly(
                time: h(11),
                windSpeed: 45,
                rainChancePercent: 10,
              ),
              aWeatherHourly(
                time: h(12),
                windSpeed: 45,
                rainChancePercent: 50, // crosses the moderate (40) threshold
              ),
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(weatherProvider: weatherProvider, now: () => now),
        );

        expect(find.byType(ForecastAlertList), findsOneWidget);

        final messages = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where((data) => data != null)
            .toList();
        final windIndex = messages.indexWhere(
          (m) => m!.contains('Wind crosses 40 km/h'),
        );
        final rainIndex = messages.indexWhere(
          (m) => m!.contains('Rain chance crosses 40%'),
        );
        expect(windIndex, greaterThanOrEqualTo(0));
        expect(rainIndex, greaterThanOrEqualTo(0));
        expect(
          windIndex,
          lessThan(rainIndex),
          reason: 'the high-severity wind alert must render before the '
              'moderate-severity rain alert',
        );
      },
    );

    testWidgets(
      'given marine data with a wave crossing, build -> includes the wave '
      'alert alongside the weather-driven ones',
      (tester) async {
        final weatherProvider = await aLoadedWeatherProvider(
          aWeatherCondition(hourly: [aWeatherHourly(time: h(9))]),
        );
        final marineProvider = await aLoadedMarineProvider(
          aSeaCondition(
            hourly: [
              aSeaHourly(time: h(9), waveHeight: 0.4),
              aSeaHourly(time: h(10), waveHeight: 1.3), // crosses 1.2m
            ],
          ),
        );

        await pumpApp(
          tester,
          HomeScreen(
            weatherProvider: weatherProvider,
            marineProvider: marineProvider,
            now: () => now,
          ),
        );

        expect(find.byType(ForecastAlertList), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ForecastAlertList),
            matching: find.byIcon(Icons.waves),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Waves cross'), findsOneWidget);
      },
    );
  });
}
