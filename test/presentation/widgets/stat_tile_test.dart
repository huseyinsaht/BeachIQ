import 'package:beachiq/presentation/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders icon, label and value', (tester) async {
    await tester.pumpWidget(
      wrap(
        const StatTile(
          icon: Icons.air,
          label: 'Wind',
          value: '12 km/h',
          trendDirection: StatTrendDirection.up,
          trendDelta: '2%',
        ),
      ),
    );

    expect(find.byIcon(Icons.air), findsOneWidget);
    expect(find.text('Wind'), findsOneWidget);
    expect(find.text('12 km/h'), findsOneWidget);
    expect(find.text('2%'), findsOneWidget);
  });

  testWidgets('renders an up trend indicator', (tester) async {
    await tester.pumpWidget(
      wrap(
        const StatTile(
          icon: Icons.water_drop,
          label: 'Rain chance',
          value: '20%',
          trendDirection: StatTrendDirection.up,
          trendDelta: '5%',
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
  });

  testWidgets('renders a down trend indicator', (tester) async {
    await tester.pumpWidget(
      wrap(
        const StatTile(
          icon: Icons.speed,
          label: 'Pressure',
          value: '1013 hPa',
          trendDirection: StatTrendDirection.down,
          trendDelta: '3 hPa',
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
    expect(find.text('3 hPa'), findsOneWidget);
  });

  testWidgets('exposes a single combined semantic label', (tester) async {
    await tester.pumpWidget(
      wrap(
        const StatTile(
          icon: Icons.air,
          label: 'Wind',
          value: '12 km/h',
          trendDirection: StatTrendDirection.up,
          trendDelta: '2%',
        ),
      ),
    );

    expect(find.bySemanticsLabel('Wind, 12 km/h, trend up 2%'), findsOneWidget);
  });

  testWidgets('constrains a long value to one line with ellipsis overflow', (
    tester,
  ) async {
    const longValue = '1013.25 hPa and rising fast';

    await tester.pumpWidget(
      wrap(
        const Center(
          child: SizedBox(
            width: 90,
            child: StatTile(
              icon: Icons.speed,
              label: 'Pressure',
              value: longValue,
              trendDirection: StatTrendDirection.down,
              trendDelta: '3 hPa',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final valueText = tester.widget<Text>(find.text(longValue));
    expect(valueText.maxLines, 1);
    expect(valueText.overflow, TextOverflow.ellipsis);
  });

  group('onTap', () {
    testWidgets('given no onTap, renders with no InkWell/tap target', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const StatTile(
            icon: Icons.speed,
            label: 'Pressure',
            value: '1013 hPa',
            trendDirection: StatTrendDirection.up,
            trendDelta: '1 hPa',
          ),
        ),
      );

      expect(find.byKey(const Key('stat-tile-tap-target')), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('given an onTap, wraps the tile in an InkWell and invokes '
        'it on tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          StatTile(
            icon: Icons.speed,
            label: 'Pressure',
            value: '1013 hPa',
            trendDirection: StatTrendDirection.up,
            trendDelta: '1 hPa',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byKey(const Key('stat-tile-tap-target')), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byKey(const Key('stat-tile-tap-target')));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('given an onTap, still renders icon/label/value/trend '
        'exactly like before', (tester) async {
      await tester.pumpWidget(
        wrap(
          StatTile(
            icon: Icons.speed,
            label: 'Pressure',
            value: '1013 hPa',
            trendDirection: StatTrendDirection.down,
            trendDelta: '2 hPa',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.speed), findsOneWidget);
      expect(find.text('Pressure'), findsOneWidget);
      expect(find.text('1013 hPa'), findsOneWidget);
      expect(find.text('2 hPa'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });
  });
}
