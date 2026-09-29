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
  });
}
