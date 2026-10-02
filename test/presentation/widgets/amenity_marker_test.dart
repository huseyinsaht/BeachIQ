import 'package:beachiq/data/models/beach_amenity.dart';
import 'package:beachiq/presentation/widgets/amenity_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('amenityColor / amenityIcon / amenityLabel', () {
    test('every AmenityKind has a distinct color and a mapped icon/label', () {
      final colors = <Color>{};
      for (final kind in AmenityKind.values) {
        colors.add(amenityColor(kind));
        expect(amenityIcon(kind), isNotNull);
        expect(amenityLabel(kind), isNotEmpty);
      }
      // toilets/shower/changingRoom intentionally share one color (blue),
      // per the owner's palette, so distinct-color kinds number fewer than
      // AmenityKind.values.length - assert the palette groups as specified
      // instead of requiring full uniqueness.
      expect(colors, {
        amenityColor(AmenityKind.cafe),
        amenityColor(AmenityKind.toilets),
        amenityColor(AmenityKind.parking),
        amenityColor(AmenityKind.beachResort),
        amenityColor(AmenityKind.lifeguard),
      });
      expect(
        amenityColor(AmenityKind.toilets),
        amenityColor(AmenityKind.shower),
      );
      expect(
        amenityColor(AmenityKind.toilets),
        amenityColor(AmenityKind.changingRoom),
      );
    });
  });

  group('AmenityMarker', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('given a parking amenity, shows a "P" badge instead of an '
        'icon', (tester) async {
      await tester.pumpWidget(
        wrap(const AmenityMarker(kind: AmenityKind.parking)),
      );

      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('given a non-parking amenity, shows its mapped icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const AmenityMarker(kind: AmenityKind.cafe)),
      );

      expect(find.byIcon(Icons.local_cafe), findsOneWidget);
    });

    testWidgets('selected marker is visually larger than an unselected one', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const AmenityMarker(kind: AmenityKind.cafe)),
      );
      final unselectedSize = tester
          .getSize(find.byType(AnimatedContainer))
          .width;

      await tester.pumpWidget(
        wrap(const AmenityMarker(kind: AmenityKind.cafe, selected: true)),
      );
      await tester.pumpAndSettle();
      final selectedSize = tester.getSize(find.byType(AnimatedContainer)).width;

      expect(selectedSize, greaterThan(unselectedSize));
    });

    testWidgets('tapping the marker invokes onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(AmenityMarker(kind: AmenityKind.cafe, onTap: () => tapped = true)),
      );

      await tester.tap(find.byType(AmenityMarker));

      expect(tapped, isTrue);
    });

    testWidgets('given showLabel false (the default), draws no label text', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const AmenityMarker(kind: AmenityKind.cafe, name: 'Beach Cafe')),
      );

      expect(find.text('Beach Cafe'), findsNothing);
      expect(find.text('Cafe'), findsNothing);
    });

    testWidgets(
      'given showLabel true and a name, draws the name as the label',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const AmenityMarker(
              kind: AmenityKind.cafe,
              name: 'Beach Cafe',
              showLabel: true,
            ),
          ),
        );

        expect(find.text('Beach Cafe'), findsOneWidget);
      },
    );

    testWidgets(
      'given showLabel true and no name, falls back to the kind label',
      (tester) async {
        await tester.pumpWidget(
          wrap(const AmenityMarker(kind: AmenityKind.parking, showLabel: true)),
        );

        expect(find.text('Parking'), findsOneWidget);
      },
    );

    testWidgets('given selected and showLabel together, fits within '
        'amenityMarkerLabeledWidth x amenityMarkerLabeledHeight without '
        'overflowing (the box location_map_card.dart actually constrains it '
        'to)', (tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: amenityMarkerLabeledWidth,
            height: amenityMarkerLabeledHeight,
            child: const AmenityMarker(
              kind: AmenityKind.beachResort,
              name: 'Fixture Beach Club',
              selected: true,
              showLabel: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
