import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/models/weather_condition.dart';
import 'package:beachiq/data/repositories/weather_repository.dart';
import 'package:beachiq/data/services/weather_api_service.dart';
import 'package:beachiq/presentation/screens/compare_beaches_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/builders.dart';
import '../../helpers/pump_app.dart';

/// A weather repository that answers by latitude, so each beach can have
/// its own conditions.
class _PerBeachWeather extends WeatherRepository {
  _PerBeachWeather(this._byLatitude) : super(WeatherApiService());

  final Map<double, WeatherCondition> _byLatitude;

  @override
  Future<WeatherCondition> getWeatherData(double lat, double lon) async =>
      _byLatitude[lat]!;
}

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
      expect(find.text('Calm seas — good time for a swim.'), findsNWidgets(2));
      // Two identical beaches: nobody is strictly ahead, so no "Best today".
      expect(find.byKey(const Key('compare-best-badge')), findsNothing);
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

  testWidgets('given a bathymetryService that fails, shows "No data" for '
      'depth instead of spinning forever', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompareBeachesScreen(
          beaches: [beachA],
          seaConditions: {beachA: aSeaCondition()},
          weatherRepository: FakeWeatherRepository(
            data: aWeatherCondition(windSpeed: 10, rainChancePercent: 5),
          ),
          bathymetryService: FakeBathymetryService(
            error: Exception('network down'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'given a depth profile with no reading at the classifier\'s anchor '
    'distance, shows "No data" for depth instead of a steepness label',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompareBeachesScreen(
            beaches: [beachA],
            seaConditions: {beachA: aSeaCondition()},
            weatherRepository: FakeWeatherRepository(
              data: aWeatherCondition(windSpeed: 10, rainChancePercent: 5),
            ),
            bathymetryService: FakeBathymetryService(
              profile: const DepthProfile(
                available: true,
                samples: [
                  DepthSample(distanceMeters: 50, depthMeters: 0.5),
                  DepthSample(distanceMeters: 150, depthMeters: 1.2),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No data'), findsOneWidget);
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

  group('card layout and "Best today"', () {
    final calmBeach = aBeach(
      name: 'Calm Beach',
      city: 'Calm City',
      latitude: 1,
    );
    final choppyBeach = aBeach(
      name: 'Choppy Beach',
      city: 'Choppy City',
      latitude: 2,
    );
    final calmerBeach = aBeach(
      name: 'Calmer Beach',
      city: 'Calmer City',
      latitude: 3,
    );

    WeatherCondition dry() =>
        aWeatherCondition(windSpeed: 8, rainChancePercent: 5, weatherCode: 0);

    Future<void> pumpCompare(
      WidgetTester tester, {
      required List<Beach> beaches,
      required Map<Beach, SeaCondition?> sea,
      required Map<double, WeatherCondition> weather,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompareBeachesScreen(
            beaches: beaches,
            seaConditions: sea,
            weatherRepository: _PerBeachWeather(weather),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows a card per beach with its name, city and its own '
        'verdict message', (tester) async {
      await pumpCompare(
        tester,
        beaches: [calmBeach, choppyBeach],
        sea: {
          calmBeach: aSeaCondition(waveHeight: 0.2),
          choppyBeach: aSeaCondition(waveHeight: 0.8),
        },
        weather: {1: dry(), 2: dry()},
      );

      expect(find.byKey(const Key('compare-card-Calm Beach')), findsOneWidget);
      expect(
        find.byKey(const Key('compare-card-Choppy Beach')),
        findsOneWidget,
      );
      expect(find.text('Calm City'), findsOneWidget);
      expect(find.text('Choppy City'), findsOneWidget);
      expect(find.text('Calm seas — good time for a swim.'), findsOneWidget);
      expect(find.text('A bit choppy — swim with care.'), findsOneWidget);
    });

    testWidgets(
      'uses the app\'s dark navy theme instead of a plain white page',
      (tester) async {
        await pumpCompare(
          tester,
          beaches: [calmBeach, choppyBeach],
          sea: {
            calmBeach: aSeaCondition(waveHeight: 0.2),
            choppyBeach: aSeaCondition(waveHeight: 0.8),
          },
          weather: {1: dry(), 2: dry()},
        );

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, const Color(0xFF0D1220));
      },
    );

    testWidgets('flags the strictly best beach "Best today" on its card only', (
      tester,
    ) async {
      await pumpCompare(
        tester,
        beaches: [choppyBeach, calmBeach],
        sea: {
          calmBeach: aSeaCondition(waveHeight: 0.2),
          choppyBeach: aSeaCondition(waveHeight: 0.8),
        },
        weather: {1: dry(), 2: dry()},
      );

      expect(find.byKey(const Key('compare-best-badge')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('compare-card-Calm Beach')),
          matching: find.byKey(const Key('compare-best-badge')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('between two good beaches the calmer one is "Best today"', (
      tester,
    ) async {
      await pumpCompare(
        tester,
        beaches: [calmBeach, calmerBeach],
        sea: {
          calmBeach: aSeaCondition(waveHeight: 0.3),
          calmerBeach: aSeaCondition(waveHeight: 0.1),
        },
        weather: {1: dry(), 3: dry()},
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('compare-card-Calmer Beach')),
          matching: find.byKey(const Key('compare-best-badge')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('flags nobody when no beach has a good verdict', (
      tester,
    ) async {
      await pumpCompare(
        tester,
        beaches: [calmBeach, choppyBeach],
        sea: {
          calmBeach: aSeaCondition(waveHeight: 0.7),
          choppyBeach: aSeaCondition(waveHeight: 0.8),
        },
        weather: {1: dry(), 2: dry()},
      );

      expect(find.byKey(const Key('compare-best-badge')), findsNothing);
    });

    testWidgets('flags nobody when a beach has no weather data', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompareBeachesScreen(
            beaches: [calmBeach, choppyBeach],
            seaConditions: {
              calmBeach: aSeaCondition(waveHeight: 0.2),
              choppyBeach: aSeaCondition(waveHeight: 0.8),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('compare-best-badge')), findsNothing);
    });

    testWidgets('an overcast, cool beach is not shown as a good swim', (
      tester,
    ) async {
      await pumpCompare(
        tester,
        beaches: [calmBeach, choppyBeach],
        sea: {
          calmBeach: aSeaCondition(waveHeight: 0.2),
          choppyBeach: aSeaCondition(waveHeight: 0.2),
        },
        weather: {
          1: dry(),
          2: aWeatherCondition(
            windSpeed: 8,
            rainChancePercent: 5,
            weatherCode: 3,
            temperature: 18,
          ),
        },
      );

      expect(
        find.text('Overcast and cool — less pleasant for a swim.'),
        findsOneWidget,
      );
      expect(find.text('Calm seas — good time for a swim.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('compare-card-Calm Beach')),
          matching: find.byKey(const Key('compare-best-badge')),
        ),
        findsOneWidget,
      );
    });
  });
}
