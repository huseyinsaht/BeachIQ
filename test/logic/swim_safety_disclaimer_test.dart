import 'package:beachiq/logic/swim_safety_disclaimer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('swimSafetyDisclaimer', () {
    test(
      'given the disclaimer text, never claims the suggestion is "safe"',
      () {
        expect(
          RegExp(r'\bsafe\b').hasMatch(swimSafetyDisclaimer.toLowerCase()),
          isFalse,
        );
      },
    );

    test('given the disclaimer text, states it is not a guarantee', () {
      expect(swimSafetyDisclaimer.toLowerCase(), contains('not a'));
      expect(swimSafetyDisclaimer.toLowerCase(), contains('guarantee'));
    });

    test('given the disclaimer text, defers to local flags/lifeguards', () {
      expect(swimSafetyDisclaimer.toLowerCase(), contains('lifeguard'));
    });
  });

  group('swimSafetyDisclaimerTitle', () {
    test(
      'given the title, is non-empty and short enough for a sheet header',
      () {
        expect(swimSafetyDisclaimerTitle, isNotEmpty);
        expect(swimSafetyDisclaimerTitle.length, lessThan(40));
      },
    );
  });
}
