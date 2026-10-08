import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/presentation/screens/compare_beaches_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/builders.dart';
import '../../helpers/pump_app.dart';

void main() {
  final beachA = aBeach(name: 'Alpha Beach', city: 'Alpha City');
  final beachB = aBeach(name: 'Beta Beach', city: 'Beta City');

  const gentleProfile = DepthProfile(
    available: true,
    samples: [
      DepthSample(distanceMeters: 0, depthMeters: 0.3),
      DepthSample(distanceMeters: 100, depthMeters: 1.0),
    ],
  );

  testWidgets(
    'given two beaches with sea conditions, renders a column per beach '
    'with the wave height and water temperature already known',
    (tester) async {
      await pumpApp(
        tester,
        CompareBeachesScreen(
          beaches: [beachA, beachB],
          seaConditions: {
            beachA: aSeaCondition(waveHeight: 0.5, seaSurfaceTemperature: 22),
            beachB: aSeaCondition(waveHeight: 1.5, seaSurfaceTemperature: 26),
          },
        ),
      );

      expect(find.text('Alpha Beach'), findsOneWidget);
      expect(find.text('Beta Beach'), findsOneWidget);
      expect(find.text('0.5 m'), findsOneWidget);
      expect(find.text('1.5 m'), findsOneWidget);
      expect(find.text('22°C'), findsOneWidget);
      expect(find.text('26°C'), findsOneWidget);
    },
  );

  testWidgets(
    'given no sea condition for a beach, shows "No data" for its wave '
    'height and water temperature instead of a guessed value',
    (tester) async {
      await pumpApp(
        tester,
        CompareBeachesScreen(
          beaches: [beachA, beachB],
          seaConditions: const {},
        ),
      );

      expect(find.text('No data'), findsWidgets);
    },
  );

  testWidgets(
    'given a weatherRepository, fetches and shows wind speed and the swim '
    'score for each beach once the fetch resolves',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompareBeachesScreen(
            beaches: [beachA, beachB],
            seaConditions: {
              beachA: aSeaCondition(waveHeight: 0.3),
              beachB: aSeaCondition(waveHeight: 0.3),
            },
            weatherRepository: FakeWeatherRepository(
              data: aWeatherCondition(windSpeed: 10, rainChancePercent: 5),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10 km/h'), findsNWidgets(2));
      expect(find.text('Good'), findsNWidgets(2));
    },
  );

  testWidgets('given a weatherRepository that fails, shows "No data" for wind '
      'instead of spinning forever', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompareBeachesScreen(
          beaches: [beachA],
          seaConditions: {beachA: aSeaCondition()},
          weatherRepository: FakeWeatherRepository(
            error: Exception('network down'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No data'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'given a bathymetryService, fetches and shows a short depth verdict '
    'label for each beach once the fetch resolves',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompareBeachesScreen(
            beaches: [beachA],
            seaConditions: {beachA: aSeaCondition()},
            bathymetryService: FakeBathymetryService(profile: gentleProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gentle'), findsOneWidget);
    },
  );

  testWidgets(
    'given no weatherRepository or bathymetryService at all, never shows '
    'a loading spinner and falls straight to "No data" for those rows',
    (tester) async {
      await pumpApp(
        tester,
        CompareBeachesScreen(
          beaches: [beachA],
          seaConditions: {beachA: aSeaCondition()},
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'given three beaches at a narrow 360dp width, lays out without any '
    'overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final beachC = aBeach(name: 'Gamma Beach', city: 'Gamma City');
      await pumpApp(
        tester,
        CompareBeachesScreen(
          beaches: [beachA, beachB, beachC],
          seaConditions: {
            beachA: aSeaCondition(),
            beachB: aSeaCondition(),
            beachC: aSeaCondition(),
          },
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
