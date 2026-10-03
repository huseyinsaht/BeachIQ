import 'dart:math' as math;

import 'package:beachiq/data/models/sea_condition.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/screens/detail/current_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/water_temperature_detail_screen.dart';
import 'package:beachiq/presentation/screens/detail/wave_height_detail_screen.dart';
import 'package:beachiq/presentation/widgets/sea_conditions_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/builders.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  /// Reads the clockwise-from-north rotation (in degrees) a `Transform`
  /// found under [key] is applying, by decoding its rotation matrix rather
  /// than assuming any particular internal representation.
  double rotationDegreesUnder(WidgetTester tester, Key key) {
    final transform = tester.widget<Transform>(
      find.descendant(of: find.byKey(key), matching: find.byType(Transform)),
    );
    final m = transform.transform;
    final radians = math.atan2(m.entry(1, 0), m.entry(0, 0));
    return radians * 180 / math.pi;
  }

  /// Normalizes [degrees] the same way `atan2` normalizes an angle decoded
  /// from a rotation matrix (into `(-180, 180]`), so a manually-computed
  /// expected rotation can be compared against [rotationDegreesUnder]
  /// without a representation mismatch (e.g. 180° vs -180°).
  double normalizedDegrees(double degrees) {
    final radians = degrees * math.pi / 180;
    return math.atan2(math.sin(radians), math.cos(radians)) * 180 / math.pi;
  }

  group('SeaConditionsRow', () {
    testWidgets('given no data (not loaded yet), build -> renders nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const SeaConditionsRow(data: null, unitSystem: UnitSystem.metric)),
      );

      expect(find.text('Sea'), findsNothing);
      expect(find.byType(SeaConditionsRow), findsOneWidget);
    });

    testWidgets(
      'given all fields present, build -> shows wave height, water temp, '
      'wave direction, current speed and current direction',
      (tester) async {
        final data = aSeaCondition(
          waveHeight: 1.2,
          seaSurfaceTemperature: 24.0,
          waveDirection: 315,
          currentVelocity: 8.0,
          currentDirection: 135,
        );

        await tester.pumpWidget(
          wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
        );

        expect(find.text('1.2 m'), findsOneWidget);
        expect(find.text('24°C'), findsOneWidget);
        expect(find.text('from NW'), findsOneWidget);
        expect(find.text('8 km/h'), findsOneWidget);
        expect(find.text('toward SE'), findsOneWidget);
      },
    );

    testWidgets(
      'given every field null, build -> shows "No data" for every tile, '
      'never a fabricated 0',
      (tester) async {
        final data = SeaCondition(
          waveHeight: null,
          waveDirection: null,
          seaSurfaceTemperature: null,
          currentVelocity: null,
          currentDirection: null,
        );

        await tester.pumpWidget(
          wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
        );

        expect(find.text('No data'), findsNWidgets(5));
        expect(find.textContaining('0'), findsNothing);
      },
    );

    testWidgets(
      'given a partial-null sea condition, build -> missing fields show '
      '"No data", present fields keep their value',
      (tester) async {
        final data = SeaCondition(
          waveHeight: 0.6,
          waveDirection: null,
          seaSurfaceTemperature: 23.0,
          currentVelocity: null,
          currentDirection: 200,
        );

        await tester.pumpWidget(
          wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
        );

        expect(find.text('0.6 m'), findsOneWidget);
        expect(find.text('23°C'), findsOneWidget);
        expect(find.text('toward S'), findsOneWidget);
        // Wave direction and current speed are null here.
        expect(find.text('No data'), findsNWidgets(2));
      },
    );

    testWidgets(
      'given imperial units, build -> formats wave height, water temp and '
      'current speed via the imperial formatters',
      (tester) async {
        final data = aSeaCondition(
          waveHeight: 1.0,
          seaSurfaceTemperature: 20.0,
          currentVelocity: 10.0,
        );

        await tester.pumpWidget(
          wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.imperial)),
        );

        expect(
          find.text(formatWaveHeight(1.0, UnitSystem.imperial)),
          findsOneWidget,
        );
        expect(
          find.text(formatTemperature(20.0, UnitSystem.imperial)),
          findsOneWidget,
        );
        expect(
          find.text(formatWindSpeed(10.0, UnitSystem.imperial)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the wave height tile opens WaveHeightDetailScreen with the '
      'marine hourly series and current value, and back returns to the '
      'previous screen',
      (tester) async {
        final data = aSeaCondition(
          waveHeight: 0.9,
          hourly: [aSeaHourly(time: DateTime(2026, 1, 1, 12), waveHeight: 0.9)],
        );

        await tester.pumpWidget(
          wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
        );

        expect(find.byType(WaveHeightDetailScreen), findsNothing);

        await tester.tap(find.byKey(const Key('wave-height-tile')));
        await tester.pumpAndSettle();

        expect(find.byType(WaveHeightDetailScreen), findsOneWidget);
        final screen = tester.widget<WaveHeightDetailScreen>(
          find.byType(WaveHeightDetailScreen),
        );
        expect(screen.currentWaveHeightMeters, 0.9);
        expect(screen.hourly, hasLength(1));

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        expect(find.byType(WaveHeightDetailScreen), findsNothing);
        expect(find.byType(SeaConditionsRow), findsOneWidget);
      },
    );

    testWidgets('tapping the water temperature tile opens '
        'WaterTemperatureDetailScreen with the marine hourly series and '
        'current value, and back returns to the previous screen', (
      tester,
    ) async {
      final data = aSeaCondition(
        seaSurfaceTemperature: 22.0,
        hourly: [
          aSeaHourly(
            time: DateTime(2026, 1, 1, 12),
            seaSurfaceTemperature: 22.0,
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
      );

      expect(find.byType(WaterTemperatureDetailScreen), findsNothing);

      await tester.tap(find.byKey(const Key('water-temperature-tile')));
      await tester.pumpAndSettle();

      expect(find.byType(WaterTemperatureDetailScreen), findsOneWidget);
      final screen = tester.widget<WaterTemperatureDetailScreen>(
        find.byType(WaterTemperatureDetailScreen),
      );
      expect(screen.currentWaterTemperatureCelsius, 22.0);
      expect(screen.hourly, hasLength(1));

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(WaterTemperatureDetailScreen), findsNothing);
      expect(find.byType(SeaConditionsRow), findsOneWidget);
    });

    testWidgets(
      'tapping the current speed tile opens CurrentDetailScreen with the '
      'marine hourly series, current speed/direction and seaward bearing, '
      'and back returns to the previous screen',
      (tester) async {
        final data = aSeaCondition(
          currentVelocity: 7.0,
          currentDirection: 90,
          hourly: [
            aSeaHourly(
              time: DateTime(2026, 1, 1, 12),
              currentVelocity: 7.0,
              currentDirection: 90,
            ),
          ],
        );

        await tester.pumpWidget(
          wrap(
            SeaConditionsRow(
              data: data,
              unitSystem: UnitSystem.metric,
              seawardBearingDegrees: 90,
            ),
          ),
        );

        expect(find.byType(CurrentDetailScreen), findsNothing);

        await tester.tap(find.byKey(const Key('current-speed-tile')));
        await tester.pumpAndSettle();

        expect(find.byType(CurrentDetailScreen), findsOneWidget);
        final screen = tester.widget<CurrentDetailScreen>(
          find.byType(CurrentDetailScreen),
        );
        expect(screen.currentSpeedKmh, 7.0);
        expect(screen.currentDirectionDegrees, 90);
        expect(screen.seawardBearingDegrees, 90);
        expect(screen.hourly, hasLength(1));

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        expect(find.byType(CurrentDetailScreen), findsNothing);
        expect(find.byType(SeaConditionsRow), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the current direction tile opens the same CurrentDetailScreen '
      'as the current speed tile',
      (tester) async {
        final data = aSeaCondition(currentVelocity: 3.0, currentDirection: 45);

        await tester.pumpWidget(
          wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
        );

        expect(find.byType(CurrentDetailScreen), findsNothing);

        await tester.tap(find.byKey(const Key('current-direction-tile')));
        await tester.pumpAndSettle();

        expect(find.byType(CurrentDetailScreen), findsOneWidget);
        final screen = tester.widget<CurrentDetailScreen>(
          find.byType(CurrentDetailScreen),
        );
        expect(screen.currentSpeedKmh, 3.0);
        expect(screen.currentDirectionDegrees, 45);
      },
    );

    group('direction conventions', () {
      final cases = {
        0.0: 'N',
        90.0: 'E',
        180.0: 'S',
        270.0: 'W',
        350.0: 'N', // wrap-around
      };

      for (final entry in cases.entries) {
        final bearing = entry.key;
        final cardinal = entry.value;

        testWidgets(
          'wave direction $bearing° -> "from $cardinal", arrow points '
          'opposite the "coming from" bearing',
          (tester) async {
            final data = SeaCondition(waveDirection: bearing);

            await tester.pumpWidget(
              wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
            );

            expect(find.text('from $cardinal'), findsOneWidget);
            final rotation = rotationDegreesUnder(
              tester,
              const Key('wave-direction-tile'),
            );
            expect(rotation, closeTo(normalizedDegrees(bearing + 180), 0.01));
          },
        );

        testWidgets(
          'current direction $bearing° -> "toward $cardinal", arrow points '
          'straight at the "flowing toward" bearing',
          (tester) async {
            final data = SeaCondition(currentDirection: bearing);

            await tester.pumpWidget(
              wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
            );

            expect(find.text('toward $cardinal'), findsOneWidget);
            final rotation = rotationDegreesUnder(
              tester,
              const Key('current-direction-tile'),
            );
            expect(rotation, closeTo(normalizedDegrees(bearing), 0.01));
          },
        );
      }
    });

    testWidgets('given a null direction, build -> shows "No data" and does not '
        'rotate the arrow', (tester) async {
      final data = SeaCondition(waveDirection: null, currentDirection: null);

      await tester.pumpWidget(
        wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
      );

      expect(
        rotationDegreesUnder(tester, const Key('wave-direction-tile')),
        closeTo(0, 0.01),
      );
      expect(
        rotationDegreesUnder(tester, const Key('current-direction-tile')),
        closeTo(0, 0.01),
      );
    });

    group('shore relation', () {
      testWidgets('given no seawardBearingDegrees (no beach geometry for this '
          'location), build -> shows cardinal direction only, never an '
          'invented shore relation', (tester) async {
        final data = SeaCondition(currentDirection: 90, waveDirection: 270);

        await tester.pumpWidget(
          wrap(SeaConditionsRow(data: data, unitSystem: UnitSystem.metric)),
        );

        expect(find.text('toward E'), findsOneWidget);
        expect(find.textContaining('towards shore'), findsNothing);
        expect(find.textContaining('away from shore'), findsNothing);
        expect(find.textContaining('along shore'), findsNothing);
      });

      testWidgets(
        'given a seawardBearingDegrees and a current flowing straight out '
        'to sea, build -> flags the current-direction tile as away from '
        'shore',
        (tester) async {
          // Current bearing 90° ("toward E") with a seaward normal of 90°:
          // the current is flowing straight out to sea.
          final data = SeaCondition(currentDirection: 90);

          await tester.pumpWidget(
            wrap(
              SeaConditionsRow(
                data: data,
                unitSystem: UnitSystem.metric,
                seawardBearingDegrees: 90,
              ),
            ),
          );

          expect(find.text('toward E'), findsOneWidget);
          expect(find.text('(away from shore — stay close!)'), findsOneWidget);
        },
      );

      testWidgets(
        'given the away-from-shore label (the longest, and the one safety '
        'warning this row shows), build -> it wraps instead of being '
        'truncated at the tile width',
        (tester) async {
          final data = SeaCondition(currentDirection: 90);

          await tester.pumpWidget(
            wrap(
              SeaConditionsRow(
                data: data,
                unitSystem: UnitSystem.metric,
                seawardBearingDegrees: 90,
              ),
            ),
          );

          final paragraph = tester.renderObject<RenderParagraph>(
            find.text('(away from shore — stay close!)'),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason:
                'the away-from-shore safety warning must fully render, not '
                'be clipped by TextOverflow.ellipsis',
          );
        },
      );

      testWidgets(
        'given a seawardBearingDegrees and a current flowing straight in '
        'from sea, build -> labels the current-direction tile as toward '
        'shore',
        (tester) async {
          // Current bearing 270° with a seaward normal of 90°: the current
          // flows straight toward the beach.
          final data = SeaCondition(currentDirection: 270);

          await tester.pumpWidget(
            wrap(
              SeaConditionsRow(
                data: data,
                unitSystem: UnitSystem.metric,
                seawardBearingDegrees: 90,
              ),
            ),
          );

          expect(find.text('(towards shore)'), findsOneWidget);
        },
      );

      testWidgets(
        'given a seawardBearingDegrees and a current flowing parallel to '
        'the shore, build -> labels the current-direction tile as along '
        'shore',
        (tester) async {
          final data = SeaCondition(currentDirection: 0);

          await tester.pumpWidget(
            wrap(
              SeaConditionsRow(
                data: data,
                unitSystem: UnitSystem.metric,
                seawardBearingDegrees: 90,
              ),
            ),
          );

          expect(find.text('(along shore)'), findsOneWidget);
        },
      );

      testWidgets(
        'given a seawardBearingDegrees, build -> also labels the secondary '
        'wave-direction tile',
        (tester) async {
          // Wave bearing 90° ("coming from" E, i.e. heading W) against a
          // seaward normal of 90°: the wave travels landward -> toward
          // shore.
          final data = SeaCondition(waveDirection: 90);

          await tester.pumpWidget(
            wrap(
              SeaConditionsRow(
                data: data,
                unitSystem: UnitSystem.metric,
                seawardBearingDegrees: 90,
              ),
            ),
          );

          expect(find.text('(towards shore)'), findsOneWidget);
        },
      );
    });
  });
}
