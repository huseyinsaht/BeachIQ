import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/shallow_entry.dart';
import 'package:beachiq/presentation/widgets/depth_cross_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, child: child)),
    );
  }

  group('DepthCrossSection', () {
    testWidgets('given an empty sample list, renders a "No data" '
        'placeholder instead of an empty graphic', (tester) async {
      await tester.pumpWidget(wrap(const DepthCrossSection(samples: [])));

      expect(find.text('No data'), findsOneWidget);
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthCrossSectionPainter>(),
        isEmpty,
      );
    });

    testWidgets('given real samples, passes the exact samples through to the '
        'painter, gaps (null depth) included rather than rewritten to 0', (
      tester,
    ) async {
      const samples = [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: null),
        DepthSample(distanceMeters: 200, depthMeters: 1.8),
      ];

      await tester.pumpWidget(wrap(const DepthCrossSection(samples: samples)));

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<DepthCrossSectionPainter>()
          .first;

      expect(painter.samples.map((s) => s.depthMeters), [0.3, null, 1.8]);
    });

    testWidgets(
      'places a standing-person silhouette only at real, measured sample '
      'distances -- never an invented position',
      (tester) async {
        const samples = [
          DepthSample(distanceMeters: 0, depthMeters: 0.3),
          DepthSample(distanceMeters: 100),
          DepthSample(distanceMeters: 200, depthMeters: 1.8),
        ];

        await tester.pumpWidget(
          wrap(const DepthCrossSection(samples: samples)),
        );

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthCrossSectionPainter>()
            .first;

        expect(
          painter.personSamples.map((p) => p.distanceMeters),
          containsAll(<double>[0, 200]),
        );
        expect(
          painter.personSamples.map((p) => p.distanceMeters),
          isNot(contains(100)),
        );
      },
    );

    testWidgets('caps the number of person silhouettes at maxPersonSilhouettes '
        'even with many valid samples', (tester) async {
      const samples = [
        DepthSample(distanceMeters: 0, depthMeters: 0.2),
        DepthSample(distanceMeters: 50, depthMeters: 0.4),
        DepthSample(distanceMeters: 100, depthMeters: 0.8),
        DepthSample(distanceMeters: 150, depthMeters: 1.2),
        DepthSample(distanceMeters: 200, depthMeters: 1.8),
        DepthSample(distanceMeters: 250, depthMeters: 2.4),
        DepthSample(distanceMeters: 300, depthMeters: 3.0),
      ];

      await tester.pumpWidget(wrap(const DepthCrossSection(samples: samples)));

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<DepthCrossSectionPainter>()
          .first;

      expect(
        painter.personSamples.length,
        lessThanOrEqualTo(maxPersonSilhouettes),
      );
    });

    testWidgets(
      'flags a person silhouette as over-head (submerged) once the real '
      'sample depth reaches referenceAdultHeightMeters',
      (tester) async {
        const samples = [
          DepthSample(distanceMeters: 0, depthMeters: 0.3),
          DepthSample(distanceMeters: 400, depthMeters: 3.4),
        ];

        await tester.pumpWidget(
          wrap(const DepthCrossSection(samples: samples)),
        );

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthCrossSectionPainter>()
            .first;

        final shallowPerson = painter.personSamples.firstWhere(
          (p) => p.distanceMeters == 0,
        );
        final deepPerson = painter.personSamples.firstWhere(
          (p) => p.distanceMeters == 400,
        );
        expect(shallowPerson.isOverHead, isFalse);
        expect(deepPerson.isOverHead, isTrue);
      },
    );

    testWidgets(
      'colors the water column with the three existing shallow/deep bands',
      (tester) async {
        const samples = [
          DepthSample(distanceMeters: 0, depthMeters: 0.3),
          DepthSample(distanceMeters: 400, depthMeters: 3.4),
        ];

        await tester.pumpWidget(
          wrap(const DepthCrossSection(samples: samples)),
        );

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthCrossSectionPainter>()
            .first;

        expect(painter.bandColors.standUp, isNotNull);
        expect(painter.bandColors.gettingDeep, isNotNull);
        expect(painter.bandColors.overHead, isNotNull);
        // Reuses shallow_entry_status.dart's own gentle/moderate/steep
        // palette rather than inventing a second one.
        expect(painter.bandColors.standUp, const Color(0xFF2E7D32));
        expect(painter.bandColors.overHead, const Color(0xFFEF5350));
      },
    );

    testWidgets(
      'the y-axis domain always extends past deepLimitMeters, even when '
      'every real sample is shallower than it',
      (tester) async {
        const samples = [
          DepthSample(distanceMeters: 0, depthMeters: 0.2),
          DepthSample(distanceMeters: 100, depthMeters: 0.4),
        ];

        await tester.pumpWidget(
          wrap(const DepthCrossSection(samples: samples)),
        );

        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<DepthCrossSectionPainter>()
            .first;

        expect(painter.yMax, greaterThan(deepLimitMeters));
      },
    );

    testWidgets(
      'given a semanticLabel, exposes it to assistive technology (as an '
      'image semantics node) so the graphic\'s content is not picture-only',
      (tester) async {
        const samples = [
          DepthSample(distanceMeters: 0, depthMeters: 0.3),
          DepthSample(distanceMeters: 100, depthMeters: 1.0),
        ];

        await tester.pumpWidget(
          wrap(
            const DepthCrossSection(
              samples: samples,
              semanticLabel: 'Shallow for a long way out.',
            ),
          ),
        );

        final semantics = tester.widget<Semantics>(
          find.descendant(
            of: find.byType(DepthCrossSection),
            matching: find.byType(Semantics),
          ),
        );
        expect(semantics.properties.label, 'Shallow for a long way out.');
        expect(semantics.properties.image, isTrue);
      },
    );

    testWidgets('given no semanticLabel, renders without a dedicated '
        'semantics node and without crashing', (tester) async {
      const samples = [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: 1.0),
      ];

      await tester.pumpWidget(wrap(const DepthCrossSection(samples: samples)));

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a narrow (360dp) width with a large '
        'text scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: const Scaffold(
                  body: SizedBox(
                    width: 360,
                    child: DepthCrossSection(
                      samples: [
                        DepthSample(distanceMeters: 0, depthMeters: 0.3),
                        DepthSample(distanceMeters: 100, depthMeters: 1.0),
                        DepthSample(distanceMeters: 200, depthMeters: 1.8),
                        DepthSample(distanceMeters: 300, depthMeters: 2.6),
                        DepthSample(distanceMeters: 400, depthMeters: 3.4),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
