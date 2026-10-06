import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/navigation/detail_routes.dart';
import 'package:beachiq/presentation/screens/detail/current_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/depth_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/pressure_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/rain_chance_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/uv_index_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/water_temperature_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/wave_height_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/wind_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/builders.dart';

void main() {
  group('buildDetailRoute', () {
    testWidgets(
      'given DetailMetric.pressure, builds a named MaterialPageRoute to '
      'PressureDetailScreen carrying the hourly series and current value',
      (tester) async {
        final hourly = [
          aWeatherHourly(time: DateTime(2026, 1, 1, 12), pressureHpa: 1013),
        ];

        final route = buildDetailRoute(
          DetailMetric.pressure,
          hourly: hourly,
          currentValue: 1013,
        );

        expect(route, isA<MaterialPageRoute<void>>());
        expect(route.settings.name, '/detail/pressure');

        await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
        await tester.pumpAndSettle();

        expect(find.byType(PressureDetailScreen), findsOneWidget);
        final screen = tester.widget<PressureDetailScreen>(
          find.byType(PressureDetailScreen),
        );
        expect(screen.currentPressureHpa, 1013);
        expect(screen.hourly, hasLength(1));
      },
    );

    testWidgets(
      'given DetailMetric.uvIndex, builds a named MaterialPageRoute to '
      'UvIndexDetailScreen carrying the hourly series and current value',
      (tester) async {
        final hourly = [
          aWeatherHourly(time: DateTime(2026, 1, 1, 12), uvIndex: 4.5),
        ];

        final route = buildDetailRoute(
          DetailMetric.uvIndex,
          hourly: hourly,
          currentValue: 4.5,
        );

        expect(route, isA<MaterialPageRoute<void>>());
        expect(route.settings.name, '/detail/uv-index');

        await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
        await tester.pumpAndSettle();

        expect(find.byType(UvIndexDetailScreen), findsOneWidget);
        final screen = tester.widget<UvIndexDetailScreen>(
          find.byType(UvIndexDetailScreen),
        );
        expect(screen.currentUvIndex, 4.5);
        expect(screen.hourly, hasLength(1));
      },
    );

    testWidgets(
      'given DetailMetric.waveHeight, builds a named MaterialPageRoute to '
      'WaveHeightDetailScreen carrying the marine hourly series, current '
      'value and unit system',
      (tester) async {
        final seaHourly = [
          aSeaHourly(time: DateTime(2026, 1, 1, 12), waveHeight: 0.9),
        ];

        final route = buildDetailRoute(
          DetailMetric.waveHeight,
          hourly: const [],
          seaHourly: seaHourly,
          currentValue: 0.9,
          unitSystem: UnitSystem.imperial,
        );

        expect(route, isA<MaterialPageRoute<void>>());
        expect(route.settings.name, '/detail/wave-height');

        await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
        await tester.pumpAndSettle();

        expect(find.byType(WaveHeightDetailScreen), findsOneWidget);
        final screen = tester.widget<WaveHeightDetailScreen>(
          find.byType(WaveHeightDetailScreen),
        );
        expect(screen.currentWaveHeightMeters, 0.9);
        expect(screen.hourly, hasLength(1));
        expect(screen.unitSystem, UnitSystem.imperial);
      },
    );

    testWidgets('given DetailMetric.wind, builds a named MaterialPageRoute to '
        'WindDetailScreen carrying the hourly series, current value and unit '
        'system', (tester) async {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 12), windSpeed: 18),
      ];

      final route = buildDetailRoute(
        DetailMetric.wind,
        hourly: hourly,
        currentValue: 18,
        unitSystem: UnitSystem.imperial,
      );

      expect(route, isA<MaterialPageRoute<void>>());
      expect(route.settings.name, '/detail/wind');

      await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
      await tester.pumpAndSettle();

      expect(find.byType(WindDetailScreen), findsOneWidget);
      final screen = tester.widget<WindDetailScreen>(
        find.byType(WindDetailScreen),
      );
      expect(screen.currentWindSpeedKmh, 18);
      expect(screen.hourly, hasLength(1));
      expect(screen.unitSystem, UnitSystem.imperial);
    });

    testWidgets(
      'given DetailMetric.rainChance, builds a named MaterialPageRoute to '
      'RainChanceDetailScreen carrying the hourly series and current value',
      (tester) async {
        final hourly = [
          aWeatherHourly(time: DateTime(2026, 1, 1, 12), rainChancePercent: 55),
        ];

        final route = buildDetailRoute(
          DetailMetric.rainChance,
          hourly: hourly,
          currentValue: 55,
        );

        expect(route, isA<MaterialPageRoute<void>>());
        expect(route.settings.name, '/detail/rain-chance');

        await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
        await tester.pumpAndSettle();

        expect(find.byType(RainChanceDetailScreen), findsOneWidget);
        final screen = tester.widget<RainChanceDetailScreen>(
          find.byType(RainChanceDetailScreen),
        );
        expect(screen.currentRainChancePercent, 55);
        expect(screen.hourly, hasLength(1));
      },
    );

    testWidgets(
      'given DetailMetric.waterTemperature, builds a named MaterialPageRoute '
      'to WaterTemperatureDetailScreen carrying the marine hourly series, '
      'current value and unit system',
      (tester) async {
        final seaHourly = [
          aSeaHourly(time: DateTime(2026, 1, 1, 12), seaSurfaceTemperature: 22),
        ];

        final route = buildDetailRoute(
          DetailMetric.waterTemperature,
          hourly: const [],
          seaHourly: seaHourly,
          currentValue: 22,
          unitSystem: UnitSystem.imperial,
        );

        expect(route, isA<MaterialPageRoute<void>>());
        expect(route.settings.name, '/detail/water-temperature');

        await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
        await tester.pumpAndSettle();

        expect(find.byType(WaterTemperatureDetailScreen), findsOneWidget);
        final screen = tester.widget<WaterTemperatureDetailScreen>(
          find.byType(WaterTemperatureDetailScreen),
        );
        expect(screen.currentWaterTemperatureCelsius, 22);
        expect(screen.hourly, hasLength(1));
        expect(screen.unitSystem, UnitSystem.imperial);
      },
    );

    testWidgets(
      'given DetailMetric.current, builds a named MaterialPageRoute to '
      'CurrentDetailScreen carrying the marine hourly series, current '
      'speed/direction, seaward bearing and unit system',
      (tester) async {
        final seaHourly = [
          aSeaHourly(
            time: DateTime(2026, 1, 1, 12),
            currentVelocity: 6,
            currentDirection: 135,
          ),
        ];

        final route = buildDetailRoute(
          DetailMetric.current,
          hourly: const [],
          seaHourly: seaHourly,
          currentValue: 6,
          currentDirectionValue: 135,
          seawardBearingDegrees: 90,
          unitSystem: UnitSystem.imperial,
        );

        expect(route, isA<MaterialPageRoute<void>>());
        expect(route.settings.name, '/detail/current');

        await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
        await tester.pumpAndSettle();

        expect(find.byType(CurrentDetailScreen), findsOneWidget);
        final screen = tester.widget<CurrentDetailScreen>(
          find.byType(CurrentDetailScreen),
        );
        expect(screen.currentSpeedKmh, 6);
        expect(screen.currentDirectionDegrees, 135);
        expect(screen.seawardBearingDegrees, 90);
        expect(screen.hourly, hasLength(1));
        expect(screen.unitSystem, UnitSystem.imperial);
      },
    );

    testWidgets('given DetailMetric.depth, builds a named MaterialPageRoute to '
        'DepthDetailScreen carrying the profile, beach, context-row data and '
        'unit system', (tester) async {
      const profile = DepthProfile(
        available: true,
        samples: [
          DepthSample(distanceMeters: 0, depthMeters: 0.3),
          DepthSample(distanceMeters: 100, depthMeters: 1.0),
        ],
      );
      final beach = aBeach(hasLifeguard: true);

      final route = buildDetailRoute(
        DetailMetric.depth,
        hourly: const [],
        depthProfile: profile,
        beach: beach,
        currentWaveHeightMeters: 0.6,
        currentValue: 5,
        currentDirectionValue: 120,
        seawardBearingDegrees: 90,
        unitSystem: UnitSystem.imperial,
      );

      expect(route, isA<MaterialPageRoute<void>>());
      expect(route.settings.name, '/detail/depth');

      await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
      await tester.pumpAndSettle();

      expect(find.byType(DepthDetailScreen), findsOneWidget);
      final screen = tester.widget<DepthDetailScreen>(
        find.byType(DepthDetailScreen),
      );
      expect(screen.profile, profile);
      expect(screen.beach, beach);
      expect(screen.currentWaveHeightMeters, 0.6);
      expect(screen.currentSpeedKmh, 5);
      expect(screen.currentDirectionDegrees, 120);
      expect(screen.seawardBearingDegrees, 90);
      expect(screen.unitSystem, UnitSystem.imperial);
    });

    // Today every metric has a screen (issue #181 wired up the second to
    // last; #217 wired up depth, the last one), so the loop below skips
    // all of them and registers no test. It stays so that a metric added
    // to the enum later but left unimplemented is covered here: it loops
    // over every DetailMetric value rather than naming them.
    for (final metric in DetailMetric.values) {
      if (metric == DetailMetric.pressure) continue;
      if (metric == DetailMetric.uvIndex) continue;
      if (metric == DetailMetric.waveHeight) continue;
      if (metric == DetailMetric.wind) continue;
      if (metric == DetailMetric.rainChance) continue;
      if (metric == DetailMetric.waterTemperature) continue;
      if (metric == DetailMetric.current) continue;
      if (metric == DetailMetric.depth) continue;

      test('given DetailMetric.$metric (not yet implemented), buildDetailRoute '
          '-> throws UnimplementedError', () {
        expect(
          () => buildDetailRoute(metric, hourly: const []),
          throwsA(isA<UnimplementedError>()),
        );
      });
    }

    test('DetailMetric lists exactly the 8 Home stat tiles this foundation '
        'was built to cover', () {
      expect(DetailMetric.values, hasLength(8));
      expect(DetailMetric.values, contains(DetailMetric.pressure));
      expect(DetailMetric.values, contains(DetailMetric.uvIndex));
      expect(DetailMetric.values, contains(DetailMetric.rainChance));
      expect(DetailMetric.values, contains(DetailMetric.wind));
      expect(DetailMetric.values, contains(DetailMetric.waveHeight));
      expect(DetailMetric.values, contains(DetailMetric.waterTemperature));
      expect(DetailMetric.values, contains(DetailMetric.current));
      expect(DetailMetric.values, contains(DetailMetric.depth));
    });
  });
}
