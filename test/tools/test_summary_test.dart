// Tests for tools/test_summary_lib.dart: the parser and renderers behind
// tools/test_summary.dart. Fixtures under tools/test_fixtures/ are recorded
// (hand-written against the real `flutter test --reporter json` protocol,
// see doc/json_reporter.md in the `test` package) event streams for the
// scenarios the CI summary tool must handle correctly.
//
// This file lives under test/tools/ (not tools/) so it is picked up by a
// plain `flutter test` run like any other test, and so tools/run_tests.sh's
// module grouping reports it under its own `tools` module.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/test_summary_lib.dart';

/// Loads a fixture recorded under tools/test_fixtures/.
List<String> _loadFixture(String name) {
  final file = File('tools/test_fixtures/$name');
  return file.readAsLinesSync();
}

void main() {
  group('moduleForPath', () {
    test('given a depth-two test path, moduleForPath -> joins the first two '
        'directories with a dot', () {
      expect(
        moduleForPath('/home/me/repo/test/data/models/beach_test.dart'),
        'data.models',
      );
    });

    test('given a depth-one test path, moduleForPath -> returns that single '
        'directory', () {
      expect(
        moduleForPath('/home/me/repo/test/logic/uv_band_test.dart'),
        'logic',
      );
    });

    test('given a path with no directory under test/, moduleForPath -> '
        'returns root', () {
      expect(moduleForPath('/home/me/repo/test/widget_test.dart'), 'root');
    });

    test('given a path under integration_test/, moduleForPath -> returns '
        'integration_test regardless of nesting', () {
      expect(
        moduleForPath('/home/me/repo/integration_test/app_test.dart'),
        'integration_test',
      );
    });

    test('given a path with more than two directories under test/, '
        'moduleForPath -> keeps only the first two', () {
      expect(
        moduleForPath(
          '/home/me/repo/test/presentation/screens/detail/uv_index_detail_screen_test.dart',
        ),
        'presentation.screens',
      );
    });

    test('given a path that is neither under test/ nor integration_test/, '
        'moduleForPath -> returns other', () {
      expect(moduleForPath('/home/me/repo/lib/main.dart'), 'other');
    });

    test('given a Windows-style path, moduleForPath -> normalizes '
        'backslashes before splitting', () {
      expect(
        moduleForPath(r'C:\Users\me\repo\test\data\models\beach_test.dart'),
        'data.models',
      );
    });
  });

  group('parseReporterEvents given testWidgets-style events', () {
    // A test defined via `testWidgets` reports `url`/`line` pointing inside
    // package:flutter_test itself (the macro's own `test()` call), not the
    // user's file -- the real location is in `root_url`/`root_line`
    // instead. Module grouping must use the suite's file (always correct)
    // rather than being fooled by this into bucketing every widget test
    // under "other".
    test('parseReporterEvents -> groups by the suite file, not the '
        'misleading url field, and reports the root_url/root_line location', () {
      final events = [
        '{"suite":{"id":0,"platform":"vm","path":"/repo/test/presentation/widgets/stat_tile_test.dart"},"type":"suite","time":0}',
        '{"test":{"id":1,"name":"StatTile shows the formatted value","suiteID":0,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":175,"column":5,"url":"package:flutter_test/src/widget_tester.dart","root_line":12,"root_column":3,"root_url":"file:///repo/test/presentation/widgets/stat_tile_test.dart"},"type":"testStart","time":1}',
        '{"testID":1,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":5}',
        '{"success":true,"type":"done","time":10}',
      ];

      final report = parseReporterEvents(events);

      expect(report.modules.keys, ['presentation.widgets']);
      final testCase = report.modules['presentation.widgets']!.cases.single;
      expect(testCase.file, 'test/presentation/widgets/stat_tile_test.dart');
      expect(testCase.line, 12);
    });
  });

  group('parseReporterEvents', () {
    test('given an all-success fixture, parseReporterEvents -> reports one '
        'successful module with no failures', () {
      final report = parseReporterEvents(_loadFixture('success.jsonl'));

      expect(report.hasFailures, isFalse);
      expect(report.modules.keys, ['data.models']);
      final module = report.modules['data.models']!;
      expect(module.total, 2);
      expect(module.passed, 2);
      expect(module.failed, 0);
      expect(module.skipped, 0);
      expect(module.isSuccess, isTrue);
    });

    test('given a fixture with a failing test, parseReporterEvents -> marks '
        'the module and only that test as failed, with the assertion '
        'message attached', () {
      final report = parseReporterEvents(_loadFixture('failure.jsonl'));

      expect(report.hasFailures, isTrue);
      final module = report.modules['logic.providers']!;
      expect(module.total, 2);
      expect(module.passed, 1);
      expect(module.failed, 1);
      expect(module.isSuccess, isFalse);

      final failing = module.cases.firstWhere(
        (c) => c.status == TestStatus.failed,
      );
      expect(failing.name, contains('throws ArgumentError'));
      expect(failing.file, 'test/logic/providers/favorites_provider_test.dart');
      expect(failing.line, 28);
      expect(failing.failureMessage, contains('Expected: true'));
    });

    test('given a fixture with a skipped test, parseReporterEvents -> counts '
        'it as skipped, not failed, and the module still reports success', () {
      final report = parseReporterEvents(_loadFixture('with_skipped.jsonl'));

      expect(report.hasFailures, isFalse);
      final module = report.modules['data.services']!;
      expect(module.total, 3);
      expect(module.passed, 2);
      expect(module.failed, 0);
      expect(module.skipped, 1);
      expect(module.isSuccess, isTrue);
    });

    test('given a fixture where setUp throws a non-TestFailure error, '
        'parseReporterEvents -> treats the test as failed with the error '
        'message attached', () {
      final report = parseReporterEvents(_loadFixture('error_in_setup.jsonl'));

      expect(report.hasFailures, isTrue);
      final module = report.modules['presentation.widgets']!;
      expect(module.total, 2);
      expect(module.passed, 1);
      expect(module.failed, 1);

      final failing = module.cases.firstWhere(
        (c) => c.status == TestStatus.failed,
      );
      expect(failing.failureMessage, contains('StateError'));
    });

    test('given a reporter stream whose done event reports success: false, '
        'parseReporterEvents -> hasFailures is true even if it had to guess '
        'at per-test results', () {
      final report = parseReporterEvents(_loadFixture('failure.jsonl'));
      expect(report.runSucceeded, isFalse);
      expect(report.hasFailures, isTrue);
    });

    test('given hidden hidden hidden virtual test events (suite loading), '
        'parseReporterEvents -> excludes them from module counts', () {
      final report = parseReporterEvents(_loadFixture('success.jsonl'));
      final module = report.modules['data.models']!;
      // The fixture has 1 hidden "loading" test plus 2 real tests; only the
      // 2 real tests should be counted.
      expect(module.total, 2);
    });
  });

  group('renderConsoleSummary', () {
    test('given a successful module, renderConsoleSummary -> prints a '
        'SUCCESS line with the exact test counts', () {
      final report = parseReporterEvents(_loadFixture('success.jsonl'));
      final output = renderConsoleSummary(report);

      expect(output, contains('[data.models:test]'));
      expect(output, contains('Test summary: SUCCESS \u2705'));
      expect(output, contains('(2 tests, 2 passed, 0 failed, 0 skipped)'));
    });

    test('given a failing module, renderConsoleSummary -> prints a FAILURE '
        'line and the failure detail (name, file:line, message)', () {
      final report = parseReporterEvents(_loadFixture('failure.jsonl'));
      final output = renderConsoleSummary(report);

      expect(output, contains('[logic.providers:test]'));
      expect(output, contains('Test summary: FAILURE \u274c'));
      expect(output, contains('(2 tests, 1 passed, 1 failed, 0 skipped)'));
      expect(output, contains('throws ArgumentError'));
      expect(
        output,
        contains('test/logic/providers/favorites_provider_test.dart:28'),
      );
      expect(output, contains('Expected: true'));
    });

    test('given a module with a skipped test, renderConsoleSummary -> '
        'reports it in the skipped count without listing it as a failure', () {
      final report = parseReporterEvents(_loadFixture('with_skipped.jsonl'));
      final output = renderConsoleSummary(report);

      expect(output, contains('(3 tests, 2 passed, 0 failed, 1 skipped)'));
      expect(output, isNot(contains('\u2717')));
    });
  });

  group('renderJUnitXml', () {
    test('given a successful module, renderJUnitXml -> writes one '
        'testsuite with a passing testcase and no failure node', () {
      final report = parseReporterEvents(_loadFixture('success.jsonl'));
      final xml = renderJUnitXml(report);

      expect(xml, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(
        xml,
        contains('<testsuite name="data.models" tests="2" failures="0"'),
      );
      expect(xml, isNot(contains('<failure')));
    });

    test('given a failing module, renderJUnitXml -> writes a failure node '
        'with the assertion message for the failing testcase', () {
      final report = parseReporterEvents(_loadFixture('failure.jsonl'));
      final xml = renderJUnitXml(report);

      expect(
        xml,
        contains('<testsuite name="logic.providers" tests="2" failures="1"'),
      );
      expect(xml, contains('<failure'));
      expect(xml, contains('Expected: true'));
    });

    test('given a skipped test, renderJUnitXml -> writes a skipped node '
        'instead of a failure', () {
      final report = parseReporterEvents(_loadFixture('with_skipped.jsonl'));
      final xml = renderJUnitXml(report);

      expect(xml, contains('<skipped/>'));
    });

    test('given a test name with XML-sensitive characters, renderJUnitXml -> '
        'escapes them', () {
      final report = parseReporterEvents([
        '{"suite":{"id":0,"platform":"vm","path":"/repo/test/logic/foo_test.dart"},"type":"suite","time":0}',
        '{"test":{"id":1,"name":"given a <tag> & \\"quote\\", run -> works","suiteID":0,"groupIDs":[],"metadata":{"skip":false,"skipReason":null},"line":1,"column":1,"url":"file:///repo/test/logic/foo_test.dart"},"type":"testStart","time":1}',
        '{"testID":1,"result":"success","skipped":false,"hidden":false,"type":"testDone","time":2}',
        '{"success":true,"type":"done","time":3}',
      ]);
      final xml = renderJUnitXml(report);

      expect(xml, contains('&lt;tag&gt;'));
      expect(xml, contains('&amp;'));
      expect(xml, contains('&quot;quote&quot;'));
    });
  });

  group('renderMarkdownSummary', () {
    test('given mixed results across fixtures, renderMarkdownSummary -> '
        'includes a table row per module and a Failures section only for '
        'failing modules', () {
      final success = parseReporterEvents(_loadFixture('success.jsonl'));
      final failure = parseReporterEvents(_loadFixture('failure.jsonl'));

      final successMd = renderMarkdownSummary(success);
      expect(
        successMd,
        contains('| data.models | ✅ SUCCESS | 2 | 2 | 0 | 0 |'),
      );
      expect(successMd, isNot(contains('## Failures')));

      final failureMd = renderMarkdownSummary(failure);
      expect(
        failureMd,
        contains('| logic.providers | ❌ FAILURE | 2 | 1 | 1 | 0 |'),
      );
      expect(failureMd, contains('## Failures'));
      expect(failureMd, contains('throws ArgumentError'));
    });
  });
}
