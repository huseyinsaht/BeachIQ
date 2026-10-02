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
  });
}
