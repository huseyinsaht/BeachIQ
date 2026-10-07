import 'package:beachiq/presentation/widgets/stat_tile.dart';
import 'package:beachiq/presentation/widgets/stat_tile_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  const threeTiles = [
    StatTile(icon: Icons.waves, label: 'Wave height', value: '0.9 m'),
    StatTile(icon: Icons.thermostat, label: 'Water temp', value: '24°C'),
    StatTile(icon: Icons.waves, label: 'Water depth', value: 'No data'),
  ];

  group('StatTileGroup', () {
    testWidgets('renders the heading icon and an uppercased label', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const StatTileGroup(
            label: 'Sea',
            icon: Icons.waves,
            tiles: threeTiles,
          ),
        ),
      );

      expect(find.byIcon(Icons.waves), findsWidgets);
      expect(find.text('SEA'), findsOneWidget);
    });

    testWidgets('renders exactly its three tiles, left to right', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const StatTileGroup(
            label: 'Sea',
            icon: Icons.waves,
            tiles: threeTiles,
          ),
        ),
      );

      expect(find.byType(StatTile), findsNWidgets(3));
      expect(find.text('Wave height'), findsOneWidget);
      expect(find.text('Water temp'), findsOneWidget);
      expect(find.text('Water depth'), findsOneWidget);

      final positions = [
        tester.getTopLeft(find.text('Wave height')).dx,
        tester.getTopLeft(find.text('Water temp')).dx,
        tester.getTopLeft(find.text('Water depth')).dx,
      ];
      expect(positions[0], lessThan(positions[1]));
      expect(positions[1], lessThan(positions[2]));
    });

    testWidgets('gives each tile an equal share of the available width', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const StatTileGroup(
            label: 'Sea',
            icon: Icons.waves,
            tiles: threeTiles,
          ),
        ),
      );

      final widths = [
        tester.getSize(find.byType(StatTile).at(0)).width,
        tester.getSize(find.byType(StatTile).at(1)).width,
        tester.getSize(find.byType(StatTile).at(2)).width,
      ];
      expect(widths[0], closeTo(widths[1], 0.5));
      expect(widths[1], closeTo(widths[2], 0.5));
    });

    testWidgets('given a tile count other than 3, build -> asserts rather than '
        'silently rendering a broken grid', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatTileGroup(
            label: 'Sea',
            icon: Icons.waves,
            tiles: [
              StatTile(icon: Icons.waves, label: 'A', value: '1'),
              StatTile(icon: Icons.waves, label: 'B', value: '2'),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
  });
}
