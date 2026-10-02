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
        HourlyForecastItem(
          timeLabel: 'Now',
          icon: Icons.wb_sunny,
          temperature: '28°',
          time: DateTime(2024, 6, 15, 12),
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
              children: [
                HourlyForecastItem(
                  timeLabel: 'Now',
                  icon: Icons.wb_sunny,
                  temperature: '28°',
                  time: DateTime(2024, 6, 15, 12),
                ),
                HourlyForecastItem(
                  timeLabel: '3PM',
                  icon: Icons.cloud,
                  temperature: '26°',
                  time: DateTime(2024, 6, 15, 12),
                ),
                HourlyForecastItem(
                  timeLabel: '4PM',
                  icon: Icons.cloud,
                  temperature: '25°',
                  time: DateTime(2024, 6, 15, 12),
                ),
                HourlyForecastItem(
                  timeLabel: '5PM',
                  icon: Icons.grain,
                  temperature: '24°',
                  time: DateTime(2024, 6, 15, 12),
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

  group('styleForWeatherIcon', () {
    test('clear (day) is sun-yellow and keeps the sun icon', () {
      final style = styleForWeatherIcon(Icons.wb_sunny, isDay: true);
      expect(style.icon, Icons.wb_sunny);
      expect(style.color, const Color(0xFFFFC94D));
      expect(style.accentIcon, isNull);
    });

    test('clear (night) switches to a moon icon', () {
      final style = styleForWeatherIcon(Icons.wb_sunny, isDay: false);
      expect(style.icon, Icons.nightlight_round);
      expect(style.accentIcon, isNull);
    });

    test('partly cloudy (day) is blue-grey and keeps the cloud icon', () {
      final style = styleForWeatherIcon(Icons.wb_cloudy, isDay: true);
      expect(style.icon, Icons.wb_cloudy);
      expect(style.color, const Color(0xFF90A4AE));
    });

    test('partly cloudy (night) switches to a night-cloud icon', () {
      final style = styleForWeatherIcon(Icons.wb_cloudy, isDay: false);
      expect(style.icon, Icons.nights_stay);
    });

    test('overcast is a darker blue-grey, day/night-independent', () {
      final day = styleForWeatherIcon(Icons.cloud, isDay: true);
      final night = styleForWeatherIcon(Icons.cloud, isDay: false);
      expect(day.icon, Icons.cloud);
      expect(day.color, const Color(0xFF78909C));
      expect(night.icon, day.icon);
      expect(night.color, day.color);
    });

    test('fog is light grey', () {
      final style = styleForWeatherIcon(Icons.foggy, isDay: true);
      expect(style.icon, Icons.foggy);
      expect(style.color, const Color(0xFFCFD8DC));
    });

    test('drizzle/rain is blue', () {
      final style = styleForWeatherIcon(Icons.grain, isDay: true);
      expect(style.icon, Icons.grain);
      expect(style.color, const Color(0xFF4FC3F7));
    });

    test('snow is light blue', () {
      final style = styleForWeatherIcon(Icons.ac_unit, isDay: true);
      expect(style.icon, Icons.ac_unit);
      expect(style.color, const Color(0xFFB3E5FC));
    });

    test('thunderstorm is violet with a yellow bolt accent', () {
      final style = styleForWeatherIcon(Icons.thunderstorm, isDay: true);
      expect(style.color, const Color(0xFF9575CD));
      expect(style.accentIcon, Icons.bolt);
      expect(style.accentColor, const Color(0xFFFDD835));
    });

    test('an unrecognized icon falls back to plain white, unchanged', () {
      final style = styleForWeatherIcon(Icons.help, isDay: true);
      expect(style.icon, Icons.help);
      expect(style.color, Colors.white);
      expect(style.accentIcon, isNull);
    });
  });

  testWidgets('shows the moon icon at night for a clear hour', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        HourlyForecastItem(
          timeLabel: '2AM',
          icon: Icons.wb_sunny,
          temperature: '18°',
          time: DateTime(2024, 6, 15, 2),
        ),
      ),
    );

    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny), findsNothing);
  });

  testWidgets('renders a small accent icon for a thunderstorm hour', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        HourlyForecastItem(
          timeLabel: 'Now',
          icon: Icons.thunderstorm,
          temperature: '22°',
          time: DateTime(2024, 6, 15, 12),
        ),
      ),
    );

    expect(find.byIcon(Icons.cloud), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
  });

  testWidgets(
    'a row mixing a daytime and a nighttime clear hour shows one sun and '
    'one moon, each per its own entry time (not the real clock)',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          Row(
            children: [
              HourlyForecastItem(
                timeLabel: '12PM',
                icon: Icons.wb_sunny,
                temperature: '28°',
                time: DateTime(2024, 6, 15, 12),
              ),
              HourlyForecastItem(
                timeLabel: '11PM',
                icon: Icons.wb_sunny,
                temperature: '18°',
                time: DateTime(2024, 6, 15, 23),
              ),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    },
  );

  testWidgets('a thunderstorm bolt accent is not clipped by the icon box', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        HourlyForecastItem(
          timeLabel: 'Now',
          icon: Icons.thunderstorm,
          temperature: '22°',
          time: DateTime(2024, 6, 15, 12),
        ),
      ),
    );

    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byType(HourlyForecastItem),
        matching: find.byType(Stack),
      ),
    );
    expect(stack.clipBehavior, Clip.none);
  });
}
