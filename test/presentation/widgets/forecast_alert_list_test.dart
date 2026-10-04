import 'package:beachiq/logic/forecast_alerts.dart';
import 'package:beachiq/presentation/widgets/forecast_alert_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  ForecastAlert alert({
    ForecastAlertType type = ForecastAlertType.wind,
    DateTime? start,
    DateTime? end,
    ForecastAlertSeverity severity = ForecastAlertSeverity.moderate,
    String message = 'Wind picks up.',
  }) {
    return ForecastAlert(
      type: type,
      start: start ?? DateTime(2026, 1, 1, 9),
      end: end ?? DateTime(2026, 1, 1, 10),
      severity: severity,
      message: message,
    );
  }

  group('ForecastAlertList', () {
    group('build', () {
      testWidgets(
        'given no alerts, build -> renders nothing and leaves no gap',
        (tester) async {
          await tester.pumpWidget(wrap(const ForecastAlertList(alerts: [])));

          expect(find.byType(Icon), findsNothing);
          expect(find.byType(Text), findsNothing);
          final size = tester.getSize(find.byType(ForecastAlertList));
          expect(size, Size.zero);
        },
      );

      testWidgets(
        'given one alert, build -> shows its icon, message and time window',
        (tester) async {
          final single = alert(
            type: ForecastAlertType.waves,
            start: DateTime(2026, 1, 1, 9),
            end: DateTime(2026, 1, 1, 10),
            message: 'Waves may rise between 09:00 and 10:00.',
          );

          await tester.pumpWidget(wrap(ForecastAlertList(alerts: [single])));

          expect(find.byIcon(Icons.waves), findsOneWidget);
          expect(
            find.text('Waves may rise between 09:00 and 10:00.'),
            findsOneWidget,
          );
          expect(find.text('09:00 - 10:00'), findsOneWidget);
        },
      );

      testWidgets(
        'given several alerts of mixed severity, build -> orders them most '
        'severe first',
        (tester) async {
          final low = alert(
            type: ForecastAlertType.rain,
            start: DateTime(2026, 1, 1, 9),
            end: DateTime(2026, 1, 1, 10),
            severity: ForecastAlertSeverity.moderate,
            message: 'Rain chance crosses 40% between 09:00 and 10:00.',
          );
          final high = alert(
            type: ForecastAlertType.wind,
            start: DateTime(2026, 1, 1, 11),
            end: DateTime(2026, 1, 1, 12),
            severity: ForecastAlertSeverity.high,
            message: 'Wind crosses 35 km/h between 11:00 and 12:00.',
          );

          // Deliberately passed in low-then-high (not already sorted), so
          // the test fails if ForecastAlertList ever stops re-sorting and
          // just renders the input order.
          await tester.pumpWidget(wrap(ForecastAlertList(alerts: [low, high])));

          final messages = tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .where((data) => data != null)
              .toList();

          expect(
            messages.indexOf('Wind crosses 35 km/h between 11:00 and 12:00.'),
            lessThan(
              messages.indexOf(
                'Rain chance crosses 40% between 09:00 and 10:00.',
              ),
            ),
            reason:
                'the high-severity alert must render before the '
                'moderate one',
          );
        },
      );

      testWidgets(
        'given alerts tied on severity, build -> keeps the earlier start '
        'time first',
        (tester) async {
          final later = alert(
            start: DateTime(2026, 1, 1, 14),
            end: DateTime(2026, 1, 1, 15),
            message: 'Later alert.',
          );
          final earlier = alert(
            start: DateTime(2026, 1, 1, 9),
            end: DateTime(2026, 1, 1, 10),
            message: 'Earlier alert.',
          );

          await tester.pumpWidget(
            wrap(ForecastAlertList(alerts: [later, earlier])),
          );

          final messages = tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .where((data) => data != null)
              .toList();

          expect(
            messages.indexOf('Earlier alert.'),
            lessThan(messages.indexOf('Later alert.')),
          );
        },
      );

      testWidgets(
        'given a moderate-severity alert, build -> colors its icon amber',
        (tester) async {
          final moderate = alert(severity: ForecastAlertSeverity.moderate);

          await tester.pumpWidget(wrap(ForecastAlertList(alerts: [moderate])));

          final icon = tester.widget<Icon>(find.byType(Icon));
          expect(icon.color, const Color(0xFFFFB74D));
        },
      );

      testWidgets('given a high-severity alert, build -> colors its icon red', (
        tester,
      ) async {
        final high = alert(severity: ForecastAlertSeverity.high);

        await tester.pumpWidget(wrap(ForecastAlertList(alerts: [high])));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, const Color(0xFFEF5350));
      });

      testWidgets(
        'given alerts of every type, build -> picks a distinct icon per '
        'type',
        (tester) async {
          final expected = {
            ForecastAlertType.wind: Icons.air,
            ForecastAlertType.waves: Icons.waves,
            ForecastAlertType.clouds: Icons.cloud,
            ForecastAlertType.rain: Icons.water_drop_outlined,
            ForecastAlertType.current: Icons.speed,
          };

          for (final entry in expected.entries) {
            await tester.pumpWidget(
              wrap(
                ForecastAlertList(
                  alerts: [
                    alert(
                      type: entry.key,
                      start: DateTime(2026, 1, 1, 9),
                      end: DateTime(2026, 1, 1, 10),
                    ),
                  ],
                ),
              ),
            );

            expect(find.byIcon(entry.value), findsOneWidget);
          }
        },
      );
    });
  });
}
