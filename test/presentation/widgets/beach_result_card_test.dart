import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/logic/beach_gear_advisor.dart';
import 'package:beachiq/presentation/widgets/beach_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets(
    'fully-populated beach: all eight fields render their real values',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            fee: BeachFee.free,
            waveHeightMeters: 0.4,
            waterTemperatureCelsius: 24,
            shoeAdvice: ShoeAdvice.notNeeded,
            hasParking: true,
            hasBeachResort: true,
            hasCafe: true,
          ),
        ),
      );

      expect(find.text('Altinkum Beach'), findsOneWidget);
      expect(find.text('Cesme, Izmir'), findsOneWidget);
      expect(find.text('27°'), findsOneWidget);
      expect(find.text('Beaches Near'), findsOneWidget);

      // Left column: entry price, wave height, water temperature.
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('0.4 m'), findsOneWidget);
      expect(find.text('24°'), findsOneWidget);

      // Right column: shoes advice, car park, beach club, cafe.
      expect(find.text('Not needed'), findsOneWidget);
      expect(find.text('Yes'), findsNWidgets(3));

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
        find.ancestor(of: find.text('Free'), matching: find.byType(Container)),
        findsOneWidget, // the outer card container only
      );
    },
  );

  testWidgets(
    'beach missing several fields renders "No data"/"Unknown" for each, '
    'never a placeholder or a crash',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            fee: BeachFee.unknown,
            waveHeightMeters: null,
            waterTemperatureCelsius: null,
            shoeAdvice: adviseOnShoes(null),
            hasParking: null,
            hasBeachResort: false,
            hasCafe: true,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Beaches Near'), findsOneWidget);

      // Missing marine/entry/amenity data renders as "No data"/"Unknown",
      // never a fabricated value, a zero, or a blank gap: fee, shoe advice
      // (from a null surface) and car park are all unknown.
      expect(find.text('Unknown'), findsNWidgets(3));
      expect(
        find.text('No data'),
        findsNWidgets(2),
      ); // wave height + water temp

      // The known fields still render their real values.
      expect(find.text('No'), findsOneWidget); // beach club: not found
      expect(find.text('Yes'), findsOneWidget); // cafe: found

      // Never a placeholder chip label.
      expect(find.byType(Chip), findsNothing);
    },
  );

  testWidgets('shoes advice is phrased as advice, not as a bare fact', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        BeachResultCard(
          placeName: 'Altinkum Beach',
          areaSubtitle: 'Cesme, Izmir',
          temperature: '27°',
          shoeAdvice: adviseOnShoes('pebbles'),
        ),
      ),
    );

    expect(find.text('Shoes advised'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        BeachResultCard(
          placeName: 'Altinkum Beach',
          areaSubtitle: 'Cesme, Izmir',
          temperature: '27°',
          fee: BeachFee.free,
          shoeAdvice: adviseOnShoes(null),
          hasParking: true,
          hasBeachResort: true,
          hasCafe: true,
        ),
      ),
    );

    // The other fields are all determinate, so the single "Unknown" is
    // unambiguously the shoe advice line.
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('no favorite icon is shown when onFavoriteToggle is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const BeachResultCard(
          placeName: 'Altinkum Beach',
          areaSubtitle: 'Cesme, Izmir',
          temperature: '27°',
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('a non-favorited beach shows an outlined heart', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        BeachResultCard(
          placeName: 'Altinkum Beach',
          areaSubtitle: 'Cesme, Izmir',
          temperature: '27°',
          onFavoriteToggle: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('a favorited beach shows a filled heart', (tester) async {
    await tester.pumpWidget(
      wrap(
        BeachResultCard(
          placeName: 'Altinkum Beach',
          areaSubtitle: 'Cesme, Izmir',
          temperature: '27°',
          isFavorite: true,
          onFavoriteToggle: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('tapping the favorite icon calls onFavoriteToggle', (
    tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      wrap(
        BeachResultCard(
          placeName: 'Altinkum Beach',
          areaSubtitle: 'Cesme, Izmir',
          temperature: '27°',
          onFavoriteToggle: () => tapCount++,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(tapCount, 1);
  });
}
