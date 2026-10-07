import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/shallow_entry.dart';
import 'package:beachiq/logic/shallow_entry_verdict.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/screens/detail/depth_detail_screen.dart';
import 'package:beachiq/presentation/widgets/depth_cross_section.dart';
import 'package:beachiq/presentation/widgets/depth_profile_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

const DepthProfile _gentleProfile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0, depthMeters: 0.3),
    DepthSample(distanceMeters: 100, depthMeters: 1.0),
    DepthSample(distanceMeters: 200, depthMeters: 1.5),
    DepthSample(distanceMeters: 300, depthMeters: 2.0),
    DepthSample(distanceMeters: 400, depthMeters: 2.5),
  ],
);

// depth at 100m (reference distance) is 2.0, between
// gentleMaxDepthAtReferenceDistanceMeters (1.5) and
// moderateMaxDepthAtReferenceDistanceMeters (3.0) -> moderate.
const DepthProfile _moderateProfile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0, depthMeters: 0.4),
    DepthSample(distanceMeters: 100, depthMeters: 2.0),
    DepthSample(distanceMeters: 200, depthMeters: 2.8),
  ],
);

// depth at 100m is 3.2, above moderateMaxDepthAtReferenceDistanceMeters
// (3.0) -> steep.
const DepthProfile _steepProfile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0, depthMeters: 0.5),
    DepthSample(distanceMeters: 100, depthMeters: 3.2),
    DepthSample(distanceMeters: 200, depthMeters: 4.0),
  ],
);

// First valid sample (100m) is already deeper than shallowLimitMeters
// (1.2m) -- no shallow stand-up zone anywhere in this data.
const DepthProfile _noShallowZoneProfile = DepthProfile(
  available: true,
  samples: [
    DepthSample(distanceMeters: 0),
    DepthSample(distanceMeters: 100, depthMeters: 2.0),
    DepthSample(distanceMeters: 200, depthMeters: 2.8),
  ],
);

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  group('DepthDetailScreen', () {
    testWidgets('given an available profile, shows the hero value and the '
        'matching Gentle/Moderate/Steep category chip', (tester) async {
      await tester.pumpWidget(
        wrap(const DepthDetailScreen(profile: _gentleProfile)),
      );

      // Gentle: depth at 100m (1.0) is <= gentleMaxDepthAtReferenceDistanceMeters
      // (1.5), and the first exceedance of shallowLimitMeters (1.2) is 200m.
      expect(find.text('<= 1.2 m for 200 m'), findsOneWidget);
      expect(find.text('Gentle'), findsOneWidget);
    });

    testWidgets(
      'given no profile at all, shows "No data" and no crash (never a '
      'fabricated value)',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: DepthDetailScreen()));

        expect(tester.takeException(), isNull);
        expect(find.text('No data'), findsWidgets);
        expect(find.text('Gentle'), findsNothing);
        expect(find.text('Moderate'), findsNothing);
        expect(find.text('Steep'), findsNothing);
      },
    );

    testWidgets(
      'given an explicitly unavailable profile, shows "No data" and no '
      'crash',
      (tester) async {
        await tester.pumpWidget(
          wrap(const DepthDetailScreen(profile: DepthProfile.unavailable())),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('No data'), findsWidgets);
      },
    );

    testWidgets('given an imperial unit preference, formats the hero value '
        'in feet', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DepthDetailScreen(
            profile: _gentleProfile,
            unitSystem: UnitSystem.imperial,
          ),
        ),
      );

      expect(find.text('<= 3.9 ft for 656 ft'), findsOneWidget);
    });

    testWidgets('renders the DepthProfileChart with the profile\'s samples', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const DepthDetailScreen(profile: _gentleProfile)),
      );

      final chart = tester.widget<DepthProfileChart>(
        find.byType(DepthProfileChart),
      );
      expect(chart.samples, _gentleProfile.samples);
    });

    testWidgets('renders a DepthCrossSection with the profile\'s samples '
        'above the numeric chart (issue #256)', (tester) async {
      await tester.pumpWidget(
        wrap(const DepthDetailScreen(profile: _gentleProfile)),
      );

      final crossSection = tester.widget<DepthCrossSection>(
        find.byType(DepthCrossSection),
      );
      expect(crossSection.samples, _gentleProfile.samples);
    });

    group('issue #256 non-swimmer verdict', () {
      testWidgets('given a gentle profile, shows the gentle verdict line '
          'and the approximation caveat', (tester) async {
        await tester.pumpWidget(
          wrap(const DepthDetailScreen(profile: _gentleProfile)),
        );

        expect(
          find.text(shallowEntryVerdictLine(ShallowEntrySteepness.gentle)),
          findsOneWidget,
        );
        expect(find.text(depthApproximationCaveat), findsOneWidget);
      });

      testWidgets('given a moderate profile, shows the moderate verdict '
          'line', (tester) async {
        await tester.pumpWidget(
          wrap(const DepthDetailScreen(profile: _moderateProfile)),
        );

        expect(
          find.text(shallowEntryVerdictLine(ShallowEntrySteepness.moderate)),
          findsOneWidget,
        );
        expect(find.text(depthApproximationCaveat), findsOneWidget);
      });

      testWidgets('given a steep profile, shows the steep verdict line', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(const DepthDetailScreen(profile: _steepProfile)),
        );

        expect(
          find.text(shallowEntryVerdictLine(ShallowEntrySteepness.steep)),
          findsOneWidget,
        );
        expect(find.text(depthApproximationCaveat), findsOneWidget);
      });

      testWidgets('given no data at all, shows the unknown verdict line '
          'instead of a fabricated one', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: DepthDetailScreen()));

        expect(
          find.text(shallowEntryVerdictLine(ShallowEntrySteepness.unknown)),
          findsOneWidget,
        );
        expect(find.text(depthApproximationCaveat), findsOneWidget);
      });

      testWidgets(
        'given a profile whose first valid sample is already deeper than '
        'the shallow limit, shows the "no shallow zone" message instead of '
        'an invented stand-up distance',
        (tester) async {
          await tester.pumpWidget(
            wrap(const DepthDetailScreen(profile: _noShallowZoneProfile)),
          );

          expect(find.text(noShallowZoneMessage), findsOneWidget);
          expect(find.byKey(const Key('depth-stand-up-label')), findsNothing);
          // The deep-from label is independent of the shallow zone and
          // still shows.
          expect(
            find.byKey(const Key('depth-deep-from-label')),
            findsOneWidget,
          );
        },
      );

      testWidgets('given a gentle profile with a real shallow zone, shows the '
          'stand-up and deep-from distance labels, never the "no shallow '
          'zone" message', (tester) async {
        await tester.pumpWidget(
          wrap(const DepthDetailScreen(profile: _gentleProfile)),
        );

        expect(find.byKey(const Key('depth-stand-up-label')), findsOneWidget);
        expect(find.byKey(const Key('depth-deep-from-label')), findsOneWidget);
        expect(find.text(noShallowZoneMessage), findsNothing);
      });
    });

    testWidgets('shows the explanation text and the EMODnet attribution '
        'line', (tester) async {
      await tester.pumpWidget(
        wrap(const DepthDetailScreen(profile: _gentleProfile)),
      );

      expect(find.textContaining('approximate'), findsOneWidget);
      expect(find.textContaining('never a safety guarantee'), findsOneWidget);
      expect(find.textContaining(depthDataAttribution), findsOneWidget);
    });

    group('context row', () {
      testWidgets(
        'given no beach, no wave height and no drift warning, renders no '
        'context row at all',
        (tester) async {
          await tester.pumpWidget(
            wrap(const DepthDetailScreen(profile: _gentleProfile)),
          );

          expect(find.byKey(const Key('depth-context-row')), findsNothing);
        },
      );

      testWidgets('given a beach with a lifeguard, shows the lifeguard '
          'context item', (tester) async {
        await tester.pumpWidget(
          wrap(
            DepthDetailScreen(
              profile: _gentleProfile,
              beach: aBeach(hasLifeguard: true),
            ),
          ),
        );

        expect(
          find.byKey(const Key('depth-context-lifeguard')),
          findsOneWidget,
        );
        expect(find.textContaining('Lifeguard on duty'), findsOneWidget);
      });

      testWidgets('given a beach with no lifeguard found, shows the '
          '"no lifeguard" context item', (tester) async {
        await tester.pumpWidget(
          wrap(
            DepthDetailScreen(
              profile: _gentleProfile,
              beach: aBeach(hasLifeguard: false),
            ),
          ),
        );

        expect(find.textContaining('No lifeguard nearby'), findsOneWidget);
      });

      testWidgets(
        'given a beach with unknown lifeguard status (null), omits the '
        'lifeguard context item entirely',
        (tester) async {
          await tester.pumpWidget(
            wrap(DepthDetailScreen(profile: _gentleProfile, beach: aBeach())),
          );

          expect(
            find.byKey(const Key('depth-context-lifeguard')),
            findsNothing,
          );
        },
      );

      testWidgets('given a current wave height, shows it in the context '
          'row', (tester) async {
        await tester.pumpWidget(
          wrap(
            const DepthDetailScreen(
              profile: _gentleProfile,
              currentWaveHeightMeters: 0.8,
            ),
          ),
        );

        expect(
          find.byKey(const Key('depth-context-wave-height')),
          findsOneWidget,
        );
        expect(find.textContaining('0.8 m'), findsOneWidget);
      });

      testWidgets('given a current flowing away from shore above the drift-out '
          'threshold, shows the drift-out warning', (tester) async {
        await tester.pumpWidget(
          wrap(
            const DepthDetailScreen(
              profile: _gentleProfile,
              currentSpeedKmh: 6,
              currentDirectionDegrees: 90,
              seawardBearingDegrees: 90,
            ),
          ),
        );

        expect(
          find.byKey(const Key('depth-context-drift-warning')),
          findsOneWidget,
        );
        expect(find.textContaining('away from shore'), findsOneWidget);
      });

      testWidgets(
        'given a current flowing toward shore, never shows the drift-out '
        'warning',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              const DepthDetailScreen(
                profile: _gentleProfile,
                currentSpeedKmh: 6,
                currentDirectionDegrees: 270,
                seawardBearingDegrees: 90,
              ),
            ),
          );

          expect(
            find.byKey(const Key('depth-context-drift-warning')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'given a current flowing away from shore but below the drift-out '
        'speed threshold, never shows the drift-out warning',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              const DepthDetailScreen(
                profile: _gentleProfile,
                currentSpeedKmh: 1,
                currentDirectionDegrees: 90,
                seawardBearingDegrees: 90,
              ),
            ),
          );

          expect(
            find.byKey(const Key('depth-context-drift-warning')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'given no seawardBearingDegrees (no beach geometry), never shows '
        'the drift-out warning (never an invented relation)',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              const DepthDetailScreen(
                profile: _gentleProfile,
                currentSpeedKmh: 6,
                currentDirectionDegrees: 90,
              ),
            ),
          );

          expect(
            find.byKey(const Key('depth-context-drift-warning')),
            findsNothing,
          );
        },
      );
    });

    testWidgets('does not overflow at a narrow (360dp) width with a large '
        'text scale, with a beach/context row/warning all present', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: DepthDetailScreen(
                  profile: _gentleProfile,
                  beach: aBeach(hasLifeguard: true),
                  currentWaveHeightMeters: 0.8,
                  currentSpeedKmh: 6,
                  currentDirectionDegrees: 90,
                  seawardBearingDegrees: 90,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('back button returns to the previous screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const DepthDetailScreen(profile: _gentleProfile),
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
      expect(find.byType(DepthDetailScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(DepthDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
