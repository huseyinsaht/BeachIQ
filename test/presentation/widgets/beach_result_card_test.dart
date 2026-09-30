import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets(
    'renders place name, subtitle and info line values as plain text',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            entryPrice: 'Free',
            waveHeight: '0.4 m',
            waterTemperature: '24°',
            shoesAdvice: 'Recommended',
            carPark: 'Nearby',
            beachClub: 'Yes',
            cafe: 'Yes',
          ),
        ),
      );

      expect(find.text('Altinkum Beach'), findsOneWidget);
      expect(find.text('Cesme, Izmir'), findsOneWidget);
      expect(find.text('27°'), findsOneWidget);
      expect(find.text('Beaches Near'), findsOneWidget);

      // Info line values render as plain text.
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('0.4 m'), findsOneWidget);
      expect(find.text('24°'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Yes'), findsNWidgets(2));

      // Not chips/pills: no Chip/RawChip/decorated-box container wraps the
      // info line text — each line is a plain Text inside a Row/Column.
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(RawChip), findsNothing);
      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);

      // No Container wraps an individual info line's value text (the only
      // Containers present are the card's own paper background and the
      // thin divider between the result row and the info lines).
      expect(
        find.ancestor(
          of: find.text('Free'),
          matching: find.byType(Container),
        ),
        findsOneWidget, // the outer card container only
      );
    },
  );

  testWidgets('renders with no info lines without crashing', (tester) async {
    await tester.pumpWidget(
      wrap(
        const BeachResultCard(
          placeName: 'Altinkum Beach',
          areaSubtitle: 'Cesme, Izmir',
          temperature: '27°',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Altinkum Beach'), findsOneWidget);
    expect(find.text('Cesme, Izmir'), findsOneWidget);
    expect(find.text('27°'), findsOneWidget);
    // No divider/section label when there are no info lines to show.
    expect(find.text('Beaches Near'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('renders a partial set of info lines without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const BeachResultCard(
          placeName: 'Altinkum Beach',
          areaSubtitle: 'Cesme, Izmir',
          temperature: '27°',
          entryPrice: 'Paid',
          cafe: 'Yes',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Beaches Near'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    // Omitted lines simply don't render.
    expect(find.text('Nearby'), findsNothing);
  });
}
