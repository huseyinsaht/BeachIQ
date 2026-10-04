// Tests for tools/checkstyle.sh: the checkstyle gate that fails CI on
// formatting drift or a lint violation, the same way a checkstyle run fails
// a build in Java projects (see .github/workflows/ci.yml, job
// analyze-and-test, and docs/testing.md's "Checkstyle" section).
//
// tools/checkstyle.sh accepts an optional single directory argument that
// scopes both the `dart format` and `dart analyze` checks to just that
// directory. These tests use that to point the script at tiny, hand-written
// fixtures under tools/test_fixtures/checkstyle/ instead of the whole
// project, so each failure path is exercised in isolation and these tests
// never depend on (or churn with) the rest of the repo's own lint cleanliness.
//
// This file lives under test/tools/ (not tools/) so it is picked up by a
// plain `flutter test` run like any other test, and so tools/run_tests.sh's
// module grouping reports it under its own `tools` module -- the same
// convention test/tools/test_summary_test.dart already follows.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs `bash tools/checkstyle.sh <fixture>` against a fixture directory
/// under tools/test_fixtures/checkstyle/ and returns the completed process.
///
/// `flutter test` always runs with the repository root as the working
/// directory (the same assumption test/tools/test_summary_test.dart makes
/// when it loads fixtures via a plain relative path), so no explicit
/// `workingDirectory` is needed here.
ProcessResult _runCheckstyle(String fixtureName) {
  return Process.runSync('bash', [
    'tools/checkstyle.sh',
    'tools/test_fixtures/checkstyle/$fixtureName',
  ]);
}

void main() {
  // These tests shell out to the real `dart format`/`dart analyze` (the
  // same tools CI runs), so they need a bit more time than a typical unit
  // test and are skipped if `bash` itself isn't on PATH (e.g. a sandboxed
  // non-POSIX runner).
  final hasBash = Process.runSync('bash', ['--version']).exitCode == 0;

  group('checkstyle.sh', () {
    test('given a cleanly formatted, lint-clean fixture, checkstyle.sh -> '
        'exits 0 and prints a SUCCESS summary', () {
      final result = _runCheckstyle('clean');

      expect(result.exitCode, 0, reason: result.stdout.toString());
      expect(result.stdout.toString(), contains('Checkstyle summary: SUCCESS'));
      expect(result.stdout.toString(), contains('0 violations'));
    }, skip: !hasBash);

    test('given an unformatted fixture, checkstyle.sh -> exits non-zero and '
        'reports a dart_format violation for that file', () {
      final result = _runCheckstyle('unformatted');

      expect(result.exitCode, isNot(0));
      final output = result.stdout.toString();
      expect(output, contains('Checkstyle summary: FAILURE'));
      expect(output, contains('dart_format'));
      expect(
        output,
        contains('tools/test_fixtures/checkstyle/unformatted/sample.dart'),
      );
    }, skip: !hasBash);

    test('given a formatted fixture with a lint rule violation, checkstyle.sh '
        '-> exits non-zero and reports the violated rule as file:line rule '
        'message', () {
      final result = _runCheckstyle('lint_violation');

      expect(result.exitCode, isNot(0));
      final output = result.stdout.toString();
      expect(output, contains('Checkstyle summary: FAILURE'));
      // file:line rule message
      expect(
        output,
        contains(
          'tools/test_fixtures/checkstyle/lint_violation/sample.dart:2 '
          'avoid_print',
        ),
      );
    }, skip: !hasBash);
  });
}
