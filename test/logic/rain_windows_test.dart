import 'package:beachiq/logic/rain_windows.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/builders.dart';

void main() {
  group('rainChanceWindows', () {
    test('given no hourly data at all, rainChanceWindows -> no windows', () {
      expect(rainChanceWindows(const []), isEmpty);
    });

    test('given every hour below the threshold, rainChanceWindows -> no '
        'windows', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 10), rainChancePercent: 10),
        aWeatherHourly(time: DateTime(2026, 1, 1, 11), rainChancePercent: 30),
      ];

      expect(rainChanceWindows(hourly), isEmpty);
    });

    test('given one hour at or above the threshold, rainChanceWindows -> one '
        'window spanning that hour to the next', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 14), rainChancePercent: 40),
      ];

      final windows = rainChanceWindows(hourly);

      expect(windows, hasLength(1));
      expect(windows.first.start, DateTime(2026, 1, 1, 14));
      expect(windows.first.end, DateTime(2026, 1, 1, 15));
    });

    test('given several contiguous qualifying hours, rainChanceWindows -> one '
        'merged window, not several', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 14), rainChancePercent: 40),
        aWeatherHourly(time: DateTime(2026, 1, 1, 15), rainChancePercent: 60),
        aWeatherHourly(time: DateTime(2026, 1, 1, 16), rainChancePercent: 45),
      ];

      final windows = rainChanceWindows(hourly);

      expect(windows, hasLength(1));
      expect(windows.first.start, DateTime(2026, 1, 1, 14));
      expect(windows.first.end, DateTime(2026, 1, 1, 17));
    });

    test('given two separate qualifying stretches, rainChanceWindows -> two '
        'distinct windows', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 9), rainChancePercent: 50),
        aWeatherHourly(time: DateTime(2026, 1, 1, 10), rainChancePercent: 10),
        aWeatherHourly(time: DateTime(2026, 1, 1, 15), rainChancePercent: 60),
        aWeatherHourly(time: DateTime(2026, 1, 1, 16), rainChancePercent: 65),
      ];

      final windows = rainChanceWindows(hourly);

      expect(windows, hasLength(2));
      expect(windows[0].start, DateTime(2026, 1, 1, 9));
      expect(windows[0].end, DateTime(2026, 1, 1, 10));
      expect(windows[1].start, DateTime(2026, 1, 1, 15));
      expect(windows[1].end, DateTime(2026, 1, 1, 17));
    });

    test('given a null reading inside an otherwise-qualifying stretch, '
        'rainChanceWindows -> the null hour breaks the window (never treated '
        'as 0%)', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 9), rainChancePercent: 50),
        aWeatherHourly(time: DateTime(2026, 1, 1, 10), rainChancePercent: null),
        aWeatherHourly(time: DateTime(2026, 1, 1, 11), rainChancePercent: 55),
      ];

      final windows = rainChanceWindows(hourly);

      expect(windows, hasLength(2));
      expect(windows[0].end, DateTime(2026, 1, 1, 10));
      expect(windows[1].start, DateTime(2026, 1, 1, 11));
    });

    test('given a custom threshold, rainChanceWindows -> only hours at or '
        'above that threshold qualify', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 9), rainChancePercent: 50),
        aWeatherHourly(time: DateTime(2026, 1, 1, 10), rainChancePercent: 75),
      ];

      final windows = rainChanceWindows(hourly, thresholdPercent: 70);

      expect(windows, hasLength(1));
      expect(windows.first.start, DateTime(2026, 1, 1, 10));
    });

    test('exactly at the threshold counts as qualifying (inclusive)', () {
      final hourly = [
        aWeatherHourly(time: DateTime(2026, 1, 1, 9), rainChancePercent: 40),
      ];

      expect(rainChanceWindows(hourly), hasLength(1));
    });
  });

  group('rainChanceSummary', () {
    test('given no windows, rainChanceSummary -> "No rain expected '
        'today."', () {
      expect(rainChanceSummary(const []), 'No rain expected today.');
    });

    test('given one window, rainChanceSummary -> "Rain likely between X and '
        'Y."', () {
      final windows = [
        RainWindow(
          start: DateTime(2026, 1, 1, 14),
          end: DateTime(2026, 1, 1, 17),
        ),
      ];

      expect(
        rainChanceSummary(windows),
        'Rain likely between 14:00 and 17:00.',
      );
    });

    test('given two windows, rainChanceSummary -> lists both windows', () {
      final windows = [
        RainWindow(
          start: DateTime(2026, 1, 1, 9),
          end: DateTime(2026, 1, 1, 10),
        ),
        RainWindow(
          start: DateTime(2026, 1, 1, 15),
          end: DateTime(2026, 1, 1, 17),
        ),
      ];

      expect(
        rainChanceSummary(windows),
        'Rain likely between 09:00 and 10:00, and between 15:00 and '
        '17:00.',
      );
    });
  });
}
