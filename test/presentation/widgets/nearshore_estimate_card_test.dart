import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/beach_surface.dart';
import 'package:beachiq/logic/nearshore_depth_estimate.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/widgets/nearshore_estimate_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NearshoreDepthEstimate _estimate(String surface, double? depth100) {
  return NearshoreDepthEstimate.from(
    osmSurface: surface,
    profile: DepthProfile(
      available: true,
      samples: [DepthSample(distanceMeters: 100, depthMeters: depth100)],
    ),
  )!;
}

Widget _wrap(Widget child, {double textScale = 1.0}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(360, 800),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

void main() {
  group('nearshoreEstimateText', () {
    test('given a range, states the probable depth at 10 m', () {
      expect(
        nearshoreEstimateText(_estimate('sand', 3), UnitSystem.metric),
        "About 10 m from the water's edge the depth is probably about 0.3 m "
        'to 1.0 m.',
      );
    });

    test('given a possibly deep sandy beach, warns without numbers', () {
      final text = nearshoreEstimateText(
        _estimate('sand', 5),
        UnitSystem.metric,
      );

      expect(text, contains('waist-deep or more'));
      expect(text, isNot(contains(' m.')));
    });

    test('given pebbles/gravel/rock, names the surface and gives no depth', () {
      final pebbles = nearshoreEstimateText(
        _estimate('pebbles', null),
        UnitSystem.metric,
      );
      final rock = nearshoreEstimateText(
        _estimate('rock', null),
        UnitSystem.metric,
      );

      expect(pebbles, startsWith('Pebbles beaches are usually steeper'));
      expect(pebbles, contains('No depth estimate'));
      expect(rock, startsWith('Rock beaches are usually steeper'));
    });
  });

  group('NearshoreEstimateCard', () {
    testWidgets('shows the amber ESTIMATE badge, the sentence and the '
        '"not measured" caveat', (tester) async {
      await tester.pumpWidget(
        _wrap(NearshoreEstimateCard(estimate: _estimate('sand', 3))),
      );

      expect(find.byKey(const Key('nearshore-estimate-badge')), findsOneWidget);
      expect(find.text('ESTIMATE'), findsOneWidget);
      expect(find.text('MEASURED'), findsNothing);
      expect(find.text('First 10 m from the water'), findsOneWidget);
      expect(
        find.textContaining('probably about 0.3 m to 1.0 m'),
        findsOneWidget,
      );
      expect(find.text(nearshoreEstimateCaveat), findsOneWidget);
      expect(nearshoreEstimateCaveat, contains('not measured'));
      expect(nearshoreEstimateCaveat, contains('deeper'));
    });

    testWidgets('given imperial, shows feet', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NearshoreEstimateCard(
            estimate: _estimate('sand', 3),
            unitSystem: UnitSystem.imperial,
          ),
        ),
      );

      expect(find.textContaining('about 1.0 ft to 3.3 ft'), findsOneWidget);
    });

    testWidgets('has an accessible label with the estimate and the caveat', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(NearshoreEstimateCard(estimate: _estimate('sand', 3))),
      );

      final label = tester
          .getSemantics(find.byKey(const Key('nearshore-estimate-card')))
          .label;
      expect(label, contains('Estimate for the first 10 metres'));
      expect(label, contains('not measured'));
    });

    testWidgets('has no layout overflow at 360 dp with a large text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NearshoreEstimateCard(estimate: _estimate('sand', 3)),
          textScale: 2.0,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('BeachSurfaceRow names the surface and its OSM source', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const BeachSurfaceRow(surface: BeachSurface.gravel)),
    );

    expect(find.text('Beach surface: Gravel (OpenStreetMap)'), findsOneWidget);
  });
}
