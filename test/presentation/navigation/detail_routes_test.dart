import 'package:beachiq/presentation/navigation/detail_routes.dart';
import 'package:beachiq/presentation/screens/detail/pressure_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/uv_index_detail_screen.dart';
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

    // Every metric besides `pressure`/`uvIndex` has no screen yet (issues
    // #179, #166, #167, #180, #181). This both documents today's state and
    // makes sure a future PR that wires one up notices this test (it will
    // start throwing `TestFailure` instead of the expected
    // `UnimplementedError`) rather than silently leaving stale coverage,
    // since it loops over every DetailMetric value rather than naming them.
    for (final metric in DetailMetric.values) {
      if (metric == DetailMetric.pressure) continue;
      if (metric == DetailMetric.uvIndex) continue;

      test('given DetailMetric.$metric (not yet implemented), buildDetailRoute '
          '-> throws UnimplementedError', () {
        expect(
          () => buildDetailRoute(metric, hourly: const []),
          throwsA(isA<UnimplementedError>()),
        );
      });
    }

    test('DetailMetric lists exactly the 7 Home stat tiles this foundation '
        'was built to cover', () {
      expect(DetailMetric.values, hasLength(7));
      expect(DetailMetric.values, contains(DetailMetric.pressure));
      expect(DetailMetric.values, contains(DetailMetric.uvIndex));
      expect(DetailMetric.values, contains(DetailMetric.rainChance));
      expect(DetailMetric.values, contains(DetailMetric.wind));
      expect(DetailMetric.values, contains(DetailMetric.waveHeight));
      expect(DetailMetric.values, contains(DetailMetric.waterTemperature));
      expect(DetailMetric.values, contains(DetailMetric.current));
    });
  });
}
