import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/screens/detail/current_detail_screen.dart';
import 'package:beachiq/presentation/widgets/hourly_metric_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  group('nowHourIndex', () {
    test('given an empty list, nowHourIndex -> null', () {
      expect(nowHourIndex(const [], DateTime(2026, 1, 1, 12)), isNull);
    });

    test('given a time exactly matching an entry, nowHourIndex -> that '
        'entry', () {
      final hourly = [
        aSeaHourly(time: DateTime(2026, 1, 1, 11)),
        aSeaHourly(time: DateTime(2026, 1, 1, 12)),
        aSeaHourly(time: DateTime(2026, 1, 1, 13)),
      ];

      expect(nowHourIndex(hourly, DateTime(2026, 1, 1, 12)), 1);
    });
  });

  group('CurrentDetailScreen', () {
    testWidgets('renders the hero value from currentSpeedKmh', (tester) async {
      await tester.pumpWidget(
        wrap(
          CurrentDetailScreen(
            hourly: const [],
            currentSpeedKmh: 6,
            now: () => DateTime(2026, 1, 1, 12),
          ),
        ),
      );

      expect(find.text('6'), findsWidgets);
      expect(find.text('km/h'), findsWidgets);
    });

    testWidgets(
      'falls back to the nearest hourly entry when currentSpeedKmh is not '
      'supplied',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: [
                aSeaHourly(time: DateTime(2026, 1, 1, 12), currentVelocity: 9),
              ],
              now: () => DateTime(2026, 1, 1, 12, 30),
            ),
          ),
        );

        expect(find.text('9'), findsWidgets);
      },
    );

    testWidgets(
      'shows the coarse-data empty state when every hour has no current '
      'speed, and hides the chart',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: [
                aSeaHourly(time: DateTime(2026, 1, 1, 12)),
                aSeaHourly(time: DateTime(2026, 1, 1, 13)),
              ],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.text(noCurrentDataForLocationText), findsOneWidget);
        expect(find.byType(HourlyMetricChart), findsNothing);
      },
    );

    testWidgets(
      'given no beach geometry (seawardBearingDegrees null), build -> '
      'explains the shore relation is unknown rather than inventing one',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: const [],
              currentSpeedKmh: 8,
              currentDirectionDegrees: 90,
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.textContaining('shore relation unknown'), findsOneWidget);
        expect(find.byKey(const Key('drift-out-warning-banner')), findsNothing);
      },
    );

    testWidgets(
      'given a current flowing away from shore at or above the drift-out '
      'threshold, build -> shows the warning banner',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: const [],
              // Bearing 90 ("toward E") against a seaward normal of 90: the
              // current flows straight out to sea.
              currentSpeedKmh: driftOutWarningSpeedKmh,
              currentDirectionDegrees: 90,
              seawardBearingDegrees: 90,
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(
          find.byKey(const Key('drift-out-warning-banner')),
          findsOneWidget,
        );
        expect(find.textContaining('Flowing away from shore at'), findsWidgets);
      },
    );

    testWidgets(
      'given a current flowing away from shore but below the drift-out '
      'threshold, build -> does not show the warning banner',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: const [],
              currentSpeedKmh: driftOutWarningSpeedKmh - 0.5,
              currentDirectionDegrees: 90,
              seawardBearingDegrees: 90,
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.byKey(const Key('drift-out-warning-banner')), findsNothing);
        expect(
          find.textContaining('below the drift-out warning threshold'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'given a current flowing toward shore above the threshold, build -> '
      'does not show the warning banner',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: const [],
              currentSpeedKmh: 10,
              // Bearing 270 against a seaward normal of 90: flowing toward
              // the beach.
              currentDirectionDegrees: 270,
              seawardBearingDegrees: 90,
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.byKey(const Key('drift-out-warning-banner')), findsNothing);
        expect(find.textContaining('Flowing toward shore at'), findsOneWidget);
      },
    );

    testWidgets(
      'given a current flowing along the shore, build -> does not show the '
      'warning banner',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: const [],
              currentSpeedKmh: 10,
              currentDirectionDegrees: 0,
              seawardBearingDegrees: 90,
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(find.byKey(const Key('drift-out-warning-banner')), findsNothing);
        expect(
          find.textContaining('Flowing along the shore at'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'given speed data but no direction data, build -> explains the shore '
      "relation can't be shown rather than inventing one",
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: const [],
              currentSpeedKmh: 5,
              seawardBearingDegrees: 90,
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(
          find.textContaining('Not enough data to show the shore relation'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders a direction arrow strip with a cardinal label per hour, and '
      '"No data" for a null-direction hour',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: [
                aSeaHourly(
                  time: DateTime(2026, 1, 1, 12),
                  currentVelocity: 4,
                  currentDirection: 90,
                ),
                aSeaHourly(
                  time: DateTime(2026, 1, 1, 13),
                  currentVelocity: 5,
                  currentDirection: null,
                ),
              ],
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        expect(
          find.byKey(const Key('current-direction-strip')),
          findsOneWidget,
        );
        expect(find.text('E'), findsOneWidget);
        expect(find.text('No data'), findsOneWidget);
      },
    );

    testWidgets(
      'passes the hourly series (gaps included) and the "Now" index to the '
      'chart',
      (tester) async {
        final now = DateTime(2026, 1, 1, 14);
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: [
                aSeaHourly(time: DateTime(2026, 1, 1, 12), currentVelocity: 4),
                aSeaHourly(
                  time: DateTime(2026, 1, 1, 13),
                  currentVelocity: null,
                ),
                aSeaHourly(time: now, currentVelocity: 7),
              ],
              now: () => now,
            ),
          ),
        );

        final chart = tester.widget<HourlyMetricChart>(
          find.byType(HourlyMetricChart),
        );
        expect(chart.points.map((p) => p.value), [4.0, null, 7.0]);
        expect(chart.nowIndex, 2);
      },
    );

    testWidgets('shows min/now/max summary labels from the hourly series', (
      tester,
    ) async {
      final now = DateTime(2026, 1, 1, 15);
      await tester.pumpWidget(
        wrap(
          CurrentDetailScreen(
            hourly: [
              aSeaHourly(
                time: now.subtract(const Duration(hours: 2)),
                currentVelocity: 2,
              ),
              aSeaHourly(
                time: now.subtract(const Duration(hours: 1)),
                currentVelocity: 9,
              ),
              aSeaHourly(time: now, currentVelocity: 5),
            ],
            now: () => now,
          ),
        ),
      );

      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets(
      'converts the hero value and unit to mph in the imperial unit system',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            CurrentDetailScreen(
              hourly: const [],
              currentSpeedKmh: 10,
              unitSystem: UnitSystem.imperial,
              now: () => DateTime(2026, 1, 1, 12),
            ),
          ),
        );

        // 10 km/h = 6.21371 mph, rounds to 6.
        expect(find.text('6'), findsWidgets);
        expect(find.text('mph'), findsWidgets);
      },
    );

    testWidgets('back button returns to the previous screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CurrentDetailScreen(
                      hourly: const [],
                      currentSpeedKmh: 6,
                      now: () => DateTime(2026, 1, 1, 12),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(CurrentDetailScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(CurrentDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
