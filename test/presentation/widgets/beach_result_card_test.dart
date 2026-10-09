import 'package:beachiq/data/models/beach.dart';
import 'package:beachiq/data/models/depth_profile.dart';
import 'package:beachiq/logic/beach_gear_advisor.dart';
import 'package:beachiq/logic/shallow_entry_verdict.dart';
import 'package:beachiq/logic/unit_preferences.dart';
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

  testWidgets('a non-favorited beach shows an outlined heart', (tester) async {
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

  testWidgets(
    'defaults to metric, rendering wave height/water temp exactly as before',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            waveHeightMeters: 0.4,
            waterTemperatureCelsius: 24,
          ),
        ),
      );

      expect(find.text('0.4 m'), findsOneWidget);
      expect(find.text('24°'), findsOneWidget);
    },
  );

  testWidgets(
    'imperial renders wave height in feet and water temp in Fahrenheit',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            waveHeightMeters: 1,
            waterTemperatureCelsius: 25,
            unitSystem: UnitSystem.imperial,
          ),
        ),
      );

      expect(find.text('3.3 ft'), findsOneWidget);
      expect(find.text('77°F'), findsOneWidget);
      expect(find.text('0.4 m'), findsNothing);
    },
  );

  group('onTap (#214)', () {
    testWidgets('tapping the card calls onTap', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        wrap(
          BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            onTap: () => tapCount++,
          ),
        ),
      );

      await tester.tap(find.text('Altinkum Beach'));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets(
      'tapping the favorite heart calls onFavoriteToggle and does NOT call '
      'onTap',
      (tester) async {
        var tapCount = 0;
        var favoriteToggleCount = 0;
        await tester.pumpWidget(
          wrap(
            BeachResultCard(
              placeName: 'Altinkum Beach',
              areaSubtitle: 'Cesme, Izmir',
              temperature: '27°',
              onTap: () => tapCount++,
              onFavoriteToggle: () => favoriteToggleCount++,
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.favorite_border));
        await tester.pump();

        expect(favoriteToggleCount, 1);
        expect(tapCount, 0);
      },
    );

    testWidgets('no onTap means the card has no tap target of its own', (
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

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
    });
  });

  group('depth summary (#257)', () {
    const gentleProfile = DepthProfile(
      available: true,
      samples: [
        DepthSample(distanceMeters: 0, depthMeters: 0.3),
        DepthSample(distanceMeters: 100, depthMeters: 1.0),
        DepthSample(distanceMeters: 200, depthMeters: 1.5),
      ],
    );
    const steepProfile = DepthProfile(
      available: true,
      samples: [
        DepthSample(distanceMeters: 0, depthMeters: 1.0),
        DepthSample(distanceMeters: 100, depthMeters: 3.5),
        DepthSample(distanceMeters: 200, depthMeters: 6.0),
      ],
    );

    testWidgets(
      'showDepthSummary false (the default, e.g. SearchScreen results): no '
      'depth row and no behavior change at all',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const BeachResultCard(
              placeName: 'Altinkum Beach',
              areaSubtitle: 'Cesme, Izmir',
              temperature: '27°',
              depthProfile: gentleProfile,
            ),
          ),
        );

        expect(find.byIcon(Icons.waves), findsNothing);
        expect(find.textContaining('Depth'), findsNothing);
        // Only the card's own InkWell (onTap) exists -- no second one for a
        // depth row that isn't there.
        expect(find.byType(InkWell), findsOneWidget);
      },
    );

    testWidgets(
      'isDepthLoading true shows a loading placeholder, never a verdict',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const BeachResultCard(
              placeName: 'Altinkum Beach',
              areaSubtitle: 'Cesme, Izmir',
              temperature: '27°',
              showDepthSummary: true,
              isDepthLoading: true,
              depthProfile: null,
            ),
          ),
        );

        expect(find.text('Depth: checking…'), findsOneWidget);
        expect(find.text('Depth: no data'), findsNothing);
      },
    );

    testWidgets('no profile (and not loading) shows "Depth: no data", never a '
        'guessed verdict', (tester) async {
      await tester.pumpWidget(
        wrap(
          const BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            showDepthSummary: true,
          ),
        ),
      );

      expect(find.text('Depth: no data'), findsOneWidget);
    });

    testWidgets('an unavailable profile also shows "Depth: no data"', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            showDepthSummary: true,
            depthProfile: DepthProfile.unavailable(),
          ),
        ),
      );

      expect(find.text('Depth: no data'), findsOneWidget);
    });

    testWidgets('a gentle profile shows the #256 verdict wording, the stand-up '
        'distance, and the shortened caveat', (tester) async {
      await tester.pumpWidget(
        wrap(
          const BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            showDepthSummary: true,
            depthProfile: gentleProfile,
          ),
        ),
      );

      expect(
        find.text('Shallow for a long way out. Easier for non-swimmers.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Stand-up water until about 200 m · '
          '$depthApproximationCaveatShort',
        ),
        findsOneWidget,
      );
      // The full caveat is never duplicated here -- only on the detail
      // screen a tap opens.
      expect(find.textContaining('not captured'), findsNothing);
    });

    testWidgets('a steep profile shows the steep verdict in red', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            showDepthSummary: true,
            depthProfile: steepProfile,
          ),
        ),
      );

      final verdict = tester.widget<Text>(
        find.text('Drops away quickly. Not suitable for non-swimmers.'),
      );
      expect(verdict.style!.color, const Color(0xFFEF5350));
    });

    testWidgets(
      'the depth summary row itself does not overflow at a narrow (360dp) '
      'width with a large text scale',
      (tester) async {
        // Deliberately omits the other optional beach-info fields (fee,
        // wave height, shoe advice, ...): this isolates the new depth
        // summary row -- the "Beaches Near" two-column block's own
        // overflow behavior at this size is unrelated to issue #257 and
        // has its own, separate test coverage.
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
                  child: Scaffold(
                    body: BeachResultCard(
                      placeName: 'Altinkum Beach',
                      areaSubtitle: 'Cesme, Izmir',
                      temperature: '27°',
                      showDepthSummary: true,
                      depthProfile: gentleProfile,
                      onDepthTap: () {},
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('tapping the depth summary calls onDepthTap, not onTap', (
      tester,
    ) async {
      var depthTapCount = 0;
      var cardTapCount = 0;
      await tester.pumpWidget(
        wrap(
          BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            showDepthSummary: true,
            depthProfile: gentleProfile,
            onDepthTap: () => depthTapCount++,
            onTap: () => cardTapCount++,
          ),
        ),
      );

      await tester.tap(
        find.text('Shallow for a long way out. Easier for non-swimmers.'),
      );
      await tester.pump();

      expect(depthTapCount, 1);
      expect(cardTapCount, 0);
    });
  });

  group('borderRadius (#214)', () {
    testWidgets('defaults to the bottom-sheet-style top-only radius', (
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

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(32)),
      );
    });

    testWidgets('a caller can override it to a fully rounded shape', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BeachResultCard(
            placeName: 'Altinkum Beach',
            areaSubtitle: 'Cesme, Izmir',
            temperature: '27°',
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(24));
    });
  });
}
