import 'package:beachiq/logic/condition_alert_service.dart';
import 'package:beachiq/logic/swim_suitability.dart';
import 'package:flutter_test/flutter_test.dart';

const _good = SwimVerdict(
  SwimSuitabilityLevel.good,
  'Calm seas — good time for a swim.',
);
const _caution = SwimVerdict(
  SwimSuitabilityLevel.caution,
  'A bit choppy — swim with care.',
);
const _poor = SwimVerdict(
  SwimSuitabilityLevel.poor,
  'Rough conditions — best to skip swimming today.',
);
const _unknown = SwimVerdict(
  SwimSuitabilityLevel.unknown,
  'Not enough data to judge swim conditions right now.',
);

void main() {
  group('ConditionAlertService.shouldAlert', () {
    test('triggers when conditions improve from caution to good', () {
      const service = ConditionAlertService();

      final result = service.shouldAlert(previous: _caution, current: _good);

      expect(result, isTrue);
    });

    test('triggers when conditions improve from poor to good', () {
      const service = ConditionAlertService();

      final result = service.shouldAlert(previous: _poor, current: _good);

      expect(result, isTrue);
    });

    test('triggers when conditions improve from unknown to good', () {
      const service = ConditionAlertService();

      final result = service.shouldAlert(previous: _unknown, current: _good);

      expect(result, isTrue);
    });

    test('does not re-trigger when conditions stay good', () {
      const service = ConditionAlertService();

      final result = service.shouldAlert(previous: _good, current: _good);

      expect(result, isFalse);
    });

    test('does not trigger when conditions stay caution', () {
      const service = ConditionAlertService();

      final result = service.shouldAlert(previous: _caution, current: _caution);

      expect(result, isFalse);
    });

    test('does not trigger when conditions worsen from good to poor', () {
      const service = ConditionAlertService();

      final result = service.shouldAlert(previous: _good, current: _poor);

      expect(result, isFalse);
    });

    test('does not trigger when conditions worsen from good to caution', () {
      const service = ConditionAlertService();

      final result = service.shouldAlert(previous: _good, current: _caution);

      expect(result, isFalse);
    });

    test(
      'is suppressed by the alerts-disabled toggle even on a favorable transition',
      () {
        const service = ConditionAlertService(alertsEnabled: false);

        final result = service.shouldAlert(previous: _poor, current: _good);

        expect(result, isFalse);
      },
    );

    test('stays off when disabled regardless of verdict transition', () {
      const service = ConditionAlertService(alertsEnabled: false);

      expect(service.shouldAlert(previous: _good, current: _good), isFalse);
      expect(service.shouldAlert(previous: _caution, current: _poor), isFalse);
      expect(service.shouldAlert(previous: _unknown, current: _good), isFalse);
    });
  });
}
