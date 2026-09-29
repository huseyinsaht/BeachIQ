import 'package:beachiq/presentation/widgets/hourly_forecast_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders time label, icon and temperature', (tester) async {
    await tester.pumpWidget(
      wrap(
        const HourlyForecastItem(
          timeLabel: 'Now',
          icon: Icons.wb_sunny,
          temperature: '28°',
        ),
      ),
    );

    expect(find.text('Now'), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    expect(find.text('28°'), findsOneWidget);
  });

  testWidgets(
    'multiple items lay out horizontally without overflow in a bounded scrollable',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 200,
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                HourlyForecastItem(
                  timeLabel: 'Now',
                  icon: Icons.wb_sunny,
                  temperature: '28°',
                ),
                HourlyForecastItem(
                  timeLabel: '3PM',
                  icon: Icons.cloud,
                  temperature: '26°',
                ),
                HourlyForecastItem(
                  timeLabel: '4PM',
                  icon: Icons.cloud,
                  temperature: '25°',
                ),
                HourlyForecastItem(
                  timeLabel: '5PM',
                  icon: Icons.grain,
                  temperature: '24°',
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('5PM'), findsOneWidget);
    },
  );
}
