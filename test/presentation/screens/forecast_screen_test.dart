import 'package:beachiq/logic/daily_outlook.dart';
import 'package:beachiq/logic/forecast_alerts.dart';
import 'package:beachiq/logic/swim_suitability.dart';
import 'package:beachiq/presentation/screens/forecast_screen.dart';
import 'package:beachiq/presentation/widgets/daily_outlook_list.dart';
import 'package:beachiq/presentation/widgets/forecast_alert_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ForecastAlert> alerts = const [],
    List<DailyOutlookEntry> dailyOutlook = const [],
    DateTime Function()? now,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: ForecastScreen(
          alerts: alerts,
          dailyOutlook: dailyOutlook,
          formatTemperature: (value) =>
              value == null ? '--°' : '${value.round()}°C',
          now: now,
        ),
      ),
    );
  }

  group('ForecastScreen (issue #289)', () {
    testWidgets('shows the "Forecast" title and a back button', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Forecast'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('the back button pops the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ForecastScreen(
                        alerts: const [],
                        dailyOutlook: const [],
                        formatTemperature: (value) => '--°',
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(ForecastScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ForecastScreen), findsNothing);
    });

    group('Alerts section', () {
      testWidgets('given no alerts, shows "No alerts"', (tester) async {
        await pumpScreen(tester, alerts: const []);

        expect(find.text('No alerts'), findsOneWidget);
        expect(find.byType(ForecastAlertList), findsNothing);
      });

      testWidgets(
        'given several alerts, shows them all, most severe first, full '
        'text wrapped with no ellipsis',
        (tester) async {
          final longMessage =
              'Wind crosses 40 km/h between 11:00 and 12:00 — strong wind '
              'expected, hold onto loose items on the beach.';
          final high = alert(
            start: DateTime(2026, 1, 1, 11),
            end: DateTime(2026, 1, 1, 12),
            severity: ForecastAlertSeverity.high,
            message: longMessage,
          );
          final moderate = alert(
            type: ForecastAlertType.rain,
            start: DateTime(2026, 1, 1, 9),
            end: DateTime(2026, 1, 1, 10),
            severity: ForecastAlertSeverity.moderate,
            message: 'Rain chance crosses 40% between 09:00 and 10:00.',
          );

          await pumpScreen(tester, alerts: [moderate, high]);

          expect(find.text('No alerts'), findsNothing);
          expect(find.byType(ForecastAlertList), findsOneWidget);
          final text = tester.widget<Text>(find.text(longMessage));
          expect(text.maxLines, isNull);
          expect(text.overflow, isNot(TextOverflow.ellipsis));

          final messages = tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .where((data) => data != null)
              .toList();
          expect(
            messages.indexOf(longMessage),
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
    });

    group('7-14 day outlook section', () {
      testWidgets('shows the section label', (tester) async {
        await pumpScreen(tester);

        expect(find.text('7-14 DAY OUTLOOK'), findsOneWidget);
      });

      testWidgets(
        'given outlook entries, shows the full, wrapped verdict message '
        'and high/low temperatures',
        (tester) async {
          final longMessage =
              'Rough conditions with high waves and strong wind — best to '
              'skip swimming today and stick to the shore.';

          await pumpScreen(
            tester,
            dailyOutlook: [
              DailyOutlookEntry(
                date: DateTime(2026, 1, 1),
                verdict: SwimVerdict(SwimSuitabilityLevel.poor, longMessage),
                highTemperature: 28,
                lowTemperature: 20,
              ),
            ],
            now: () => DateTime(2026, 1, 1),
          );

          expect(find.byType(DailyOutlookList), findsOneWidget);
          final text = tester.widget<Text>(find.text(longMessage));
          expect(text.maxLines, isNull);
          expect(text.overflow, isNot(TextOverflow.ellipsis));
          expect(find.text('28°C'), findsOneWidget);
          expect(find.text('20°C'), findsOneWidget);
        },
      );

      testWidgets('given no outlook entries, renders no rows', (tester) async {
        await pumpScreen(tester, dailyOutlook: const []);

        expect(find.byKey(const Key('daily-outlook-list')), findsOneWidget);
        expect(find.byType(Divider), findsNothing);
      });
    });
  });
}
