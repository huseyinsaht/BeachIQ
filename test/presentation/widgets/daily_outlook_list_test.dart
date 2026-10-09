import 'package:beachiq/logic/daily_outlook.dart';
import 'package:beachiq/logic/swim_suitability.dart';
import 'package:beachiq/presentation/widgets/daily_outlook_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('DailyOutlookList', () {
    testWidgets(
      'given multiple entries, renders -> one row per day, "Today" for the '
      'one matching now\'s calendar date',
      (tester) async {
        await pumpApp(
          tester,
          Material(
            child: DailyOutlookList(
              now: DateTime(2026, 7, 1),
              entries: [
                DailyOutlookEntry(
                  date: DateTime(2026, 7, 1),
                  verdict: const SwimVerdict(
                    SwimSuitabilityLevel.good,
                    'Calm seas — good time for a swim.',
                  ),
                  highTemperature: 28.0,
                  lowTemperature: 20.0,
                ),
                DailyOutlookEntry(
                  date: DateTime(2026, 7, 2),
                  verdict: const SwimVerdict(
                    SwimSuitabilityLevel.poor,
                    'Rough conditions — best to skip swimming today.',
                  ),
                  highTemperature: 27.0,
                  lowTemperature: 19.0,
                ),
              ],
              formatTemperature: (value) =>
                  value == null ? '--°' : '${value.round()}°C',
            ),
          ),
        );

        expect(find.byKey(const Key('daily-outlook-list')), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Thu'), findsOneWidget); // 2026-07-02
        expect(find.text('Calm seas — good time for a swim.'), findsOneWidget);
        expect(
          find.text('Rough conditions — best to skip swimming today.'),
          findsOneWidget,
        );
        expect(find.text('28°C'), findsOneWidget);
        expect(find.text('20°C'), findsOneWidget);
      },
    );

    testWidgets(
      'given a now that has moved past the first entry\'s date (a stale '
      'cache checked after midnight), does not mislabel it "Today"',
      (tester) async {
        await pumpApp(
          tester,
          Material(
            child: DailyOutlookList(
              now: DateTime(2026, 7, 2), // a day after entries[0].date
              entries: [
                DailyOutlookEntry(
                  date: DateTime(2026, 7, 1),
                  verdict: const SwimVerdict(
                    SwimSuitabilityLevel.good,
                    'Calm seas — good time for a swim.',
                  ),
                ),
              ],
              formatTemperature: (value) => '--°',
            ),
          ),
        );

        expect(find.text('Today'), findsNothing);
        expect(find.text('Wed'), findsOneWidget); // 2026-07-01
      },
    );

    testWidgets(
      'given a now that has rolled over to the second entry\'s date, moves '
      '"Today" to that row instead of leaving it on the first',
      (tester) async {
        await pumpApp(
          tester,
          Material(
            child: DailyOutlookList(
              now: DateTime(2026, 7, 2), // matches entries[1].date
              entries: [
                DailyOutlookEntry(
                  date: DateTime(2026, 7, 1),
                  verdict: const SwimVerdict(
                    SwimSuitabilityLevel.good,
                    'Calm seas — good time for a swim.',
                  ),
                ),
                DailyOutlookEntry(
                  date: DateTime(2026, 7, 2),
                  verdict: const SwimVerdict(
                    SwimSuitabilityLevel.poor,
                    'Rough conditions — best to skip swimming today.',
                  ),
                ),
              ],
              formatTemperature: (value) => '--°',
            ),
          ),
        );

        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Wed'), findsOneWidget); // entries[0] (2026-07-01)
      },
    );

    testWidgets('given no entries, renders -> an empty list, no error', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Material(
          child: DailyOutlookList(
            entries: const [],
            formatTemperature: (value) => '--°',
          ),
        ),
      );

      expect(find.byKey(const Key('daily-outlook-list')), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets(
      'given a day with no high/low data, renders -> the formatter\'s '
      'placeholder instead of a guessed value',
      (tester) async {
        await pumpApp(
          tester,
          Material(
            child: DailyOutlookList(
              entries: [
                DailyOutlookEntry(
                  date: DateTime(2026, 7, 1),
                  verdict: const SwimVerdict(
                    SwimSuitabilityLevel.unknown,
                    'Not enough data to judge swim conditions right now.',
                  ),
                ),
              ],
              formatTemperature: (value) => value == null ? '--°' : '$value',
            ),
          ),
        );

        expect(find.text('--°'), findsNWidgets(2));
      },
    );

    testWidgets(
      'given a long verdict message, renders -> the full text with no line '
      'cap or ellipsis (issue #289: the Forecast screen wraps instead of '
      'truncating)',
      (tester) async {
        const longMessage =
            'Rough conditions with high waves and strong wind — best to '
            'skip swimming today and stick to the shore.';
        await pumpApp(
          tester,
          Material(
            child: DailyOutlookList(
              entries: [
                DailyOutlookEntry(
                  date: DateTime(2026, 7, 1),
                  verdict: const SwimVerdict(
                    SwimSuitabilityLevel.poor,
                    longMessage,
                  ),
                ),
              ],
              formatTemperature: (value) => '--°',
            ),
          ),
        );

        final text = tester.widget<Text>(find.text(longMessage));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
      },
    );
  });
}
