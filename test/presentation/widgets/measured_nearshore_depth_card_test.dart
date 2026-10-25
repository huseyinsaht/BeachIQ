import 'package:beachiq/data/models/measured_nearshore_depth.dart';
import 'package:beachiq/logic/unit_preferences.dart';
import 'package:beachiq/presentation/widgets/measured_nearshore_depth_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MeasuredNearshoreDepth _data({String? note, String? reference}) {
  return MeasuredNearshoreDepth(
    beachName: 'Ilica Beach',
    latitude: 38.287,
    longitude: 26.373,
    radiusMeters: 150,
    measuredOn: DateTime(2026, 10, 25),
    measuredBy: 'Vaen',
    method: 'Marked rope and depth stick',
    reference: reference ?? 'Water edge at 14:00',
    note: note,
    points: const [
      MeasuredDepthPoint(distanceMeters: 1, depthCm: 20),
      MeasuredDepthPoint(distanceMeters: 5, depthCm: 80),
      MeasuredDepthPoint(distanceMeters: 10, depthCm: 135),
    ],
  );
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
  group('formatMeasuredDepth', () {
    test('given under 1 m, shows whole centimeters', () {
      expect(formatMeasuredDepth(0, UnitSystem.metric), '0 cm');
      expect(formatMeasuredDepth(45, UnitSystem.metric), '45 cm');
      expect(formatMeasuredDepth(99, UnitSystem.metric), '99 cm');
    });

    test('given 1 m or more, shows meters with two decimals', () {
      expect(formatMeasuredDepth(100, UnitSystem.metric), '1.00 m');
      expect(formatMeasuredDepth(135, UnitSystem.metric), '1.35 m');
    });

    test('given imperial, shows feet with one decimal', () {
      expect(formatMeasuredDepth(100, UnitSystem.imperial), '3.3 ft');
      expect(formatMeasuredDepth(20, UnitSystem.imperial), '0.7 ft');
    });
  });

  test('formatMeasuredDate gives "25 Oct 2026"', () {
    expect(formatMeasuredDate(DateTime(2026, 10, 25)), '25 Oct 2026');
    expect(formatMeasuredDate(DateTime(2027, 1, 3)), '3 Jan 2027');
  });

  group('MeasuredNearshoreDepthCard', () {
    testWidgets('shows the MEASURED badge, date, who and how, every reading '
        'and the caveat', (tester) async {
      await tester.pumpWidget(_wrap(MeasuredNearshoreDepthCard(data: _data())));

      expect(find.byKey(const Key('measured-depth-badge')), findsOneWidget);
      expect(find.text('MEASURED'), findsOneWidget);
      expect(
        find.text(
          'Measured on 25 Oct 2026 by Vaen. Marked rope and depth stick.',
        ),
        findsOneWidget,
      );
      for (final distance in [1, 5, 10]) {
        expect(
          find.byKey(Key('measured-depth-point-$distance')),
          findsOneWidget,
        );
      }
      expect(find.text('20 cm'), findsOneWidget);
      expect(find.text('80 cm'), findsOneWidget);
      expect(find.text('1.35 m'), findsOneWidget);
      expect(find.text('10 m'), findsOneWidget);
      expect(find.text('Distances from: Water edge at 14:00.'), findsOneWidget);
      expect(find.text(measuredDepthCaveat), findsOneWidget);
      expect(find.byKey(const Key('measured-depth-note')), findsNothing);
    });

    testWidgets('shows the optional note when present', (tester) async {
      await tester.pumpWidget(
        _wrap(MeasuredNearshoreDepthCard(data: _data(note: 'Sandy bottom.'))),
      );

      expect(find.text('Sandy bottom.'), findsOneWidget);
    });

    testWidgets('given imperial, shows feet', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MeasuredNearshoreDepthCard(
            data: _data(),
            unitSystem: UnitSystem.imperial,
          ),
        ),
      );

      expect(find.text('0.7 ft'), findsOneWidget);
      expect(find.text('33 ft'), findsOneWidget);
      expect(find.text('20 cm'), findsNothing);
    });

    testWidgets('has an accessible summary of every reading', (tester) async {
      await tester.pumpWidget(_wrap(MeasuredNearshoreDepthCard(data: _data())));

      final semantics = tester.getSemantics(
        find.byKey(const Key('measured-depth-card')),
      );
      expect(semantics.label, contains('25 Oct 2026'));
      expect(semantics.label, contains('1 m from the water: 20 cm'));
      expect(semantics.label, contains('10 m from the water: 1.35 m'));
    });

    testWidgets('has no layout overflow at 360 dp with a large text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MeasuredNearshoreDepthCard(
            data: _data(note: 'A long note about the bottom and the rocks.'),
          ),
          textScale: 2.0,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
