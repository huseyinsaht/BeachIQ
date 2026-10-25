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

  group('ripCurrentSafetyTip', () {
    test('given the tip, is general advice that never claims safety or '
        'predicts a rip', () {
      final tip = ripCurrentSafetyTip.toLowerCase();

      expect(RegExp(r'safe').hasMatch(tip), isFalse);
      expect(tip, contains('lifeguard'));
      expect(tip, contains('parallel to the shore'));
      expect(tip, isNot(contains('forecast')));
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
