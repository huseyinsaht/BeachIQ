import 'package:beachiq/data/models/beach_amenity.dart';
import 'package:beachiq/presentation/widgets/amenity_legend.dart';
import 'package:beachiq/presentation/widgets/amenity_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('given no present kinds, renders nothing', (tester) async {
    await tester.pumpWidget(
      wrap(
        AmenityLegend(
          presentKinds: const {},
          hiddenKinds: const {},
          onToggle: (_) {},
        ),
      ),
    );

    expect(find.byType(AmenityLegend), findsOneWidget);
    expect(find.text('Cafe'), findsNothing);
  });

  testWidgets(
    'only shows chips for kinds actually present, never the full set',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          AmenityLegend(
            presentKinds: const {AmenityKind.cafe, AmenityKind.parking},
            hiddenKinds: const {},
            onToggle: (_) {},
          ),
        ),
      );

      expect(find.text('Cafe'), findsOneWidget);
      expect(find.text('Parking'), findsOneWidget);
      expect(find.text('Toilets'), findsNothing);
      expect(find.text('Lifeguard'), findsNothing);
    },
  );

  testWidgets('tapping a chip calls onToggle with that kind', (tester) async {
    AmenityKind? toggled;
    await tester.pumpWidget(
      wrap(
        AmenityLegend(
          presentKinds: const {AmenityKind.cafe},
          hiddenKinds: const {},
          onToggle: (kind) => toggled = kind,
        ),
      ),
    );

    await tester.tap(find.text('Cafe'));

    expect(toggled, AmenityKind.cafe);
  });

  testWidgets(
    'a shown kind renders filled with its amenity color; a hidden kind '
    'renders in the outlined (not filled) style instead',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          AmenityLegend(
            presentKinds: const {AmenityKind.cafe},
            hiddenKinds: const {},
            onToggle: (_) {},
          ),
        ),
      );
      final shownDecoration =
          tester.widget<Container>(find.byType(Container).first).decoration!
              as BoxDecoration;
      expect(shownDecoration.color, amenityColor(AmenityKind.cafe));

      await tester.pumpWidget(
        wrap(
          AmenityLegend(
            presentKinds: const {AmenityKind.cafe},
            hiddenKinds: const {AmenityKind.cafe},
            onToggle: (_) {},
          ),
        ),
      );
      final hiddenDecoration =
          tester.widget<Container>(find.byType(Container).first).decoration!
              as BoxDecoration;
      expect(hiddenDecoration.color, isNot(amenityColor(AmenityKind.cafe)));
    },
  );
}
