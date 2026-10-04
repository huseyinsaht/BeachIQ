#!/usr/bin/env dart

/// Reads a `flutter test --reporter json` event stream (from stdin, or from
/// a file given as the first argument) and prints one `Test summary:` line
/// per module (see `moduleForPath` in `test_summary_lib.dart`), plus failure
/// details for any failing test.
///
/// Also writes:
///   - `build/reports/junit.xml`   (JUnit XML, one `<testsuite>` per module)
///   - `build/reports/summary.md`  (markdown table mirroring the console
///                                  output, appended to $GITHUB_STEP_SUMMARY
///                                  by CI)
///
/// Exit code is non-zero if any module had a failing test (or the reporter's
/// own `done` event reported `success: false`).
///
/// Usage:
///   flutter test --reporter json | dart run tools/test_summary.dart
///   dart run tools/test_summary.dart path/to/recorded-events.jsonl
library;

import 'dart:convert';
import 'dart:io';

import 'test_summary_lib.dart';

Future<void> main(List<String> args) async {
  final lines = <String>[];

  if (args.isNotEmpty) {
    lines.addAll(File(args.first).readAsLinesSync());
  } else {
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      lines.add(line);
    }
  }

  final report = parseReporterEvents(lines);

  stdout.write(renderConsoleSummary(report));

  final reportsDir = Directory('build/reports');
  reportsDir.createSync(recursive: true);
  File(
    '${reportsDir.path}/junit.xml',
  ).writeAsStringSync(renderJUnitXml(report));
  File(
    '${reportsDir.path}/summary.md',
  ).writeAsStringSync(renderMarkdownSummary(report));

  if (report.totalTests == 0) {
    stderr.writeln('test_summary: no tests found in the reporter stream.');
    exitCode = 1;
    return;
  }

  exitCode = report.hasFailures ? 1 : 0;
}
