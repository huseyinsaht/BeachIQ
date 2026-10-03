/// Parsing and reporting logic for `tools/test_summary.dart`.
///
/// This file is deliberately free of `dart:io` file/stdin access so it can be
/// unit tested with recorded JSON-reporter fixtures (see
/// `test/tools/test_summary_test.dart`). The CLI wrapper in
/// `tools/test_summary.dart` does the actual reading from stdin/a file and
/// writing of `build/reports/junit.xml` and `build/reports/summary.md`.
library;

import 'dart:convert';

/// The outcome of a single test case, used both to compute module totals and
/// to render per-test detail (console failure block, JUnit `<testcase>`).
enum TestStatus { passed, failed, skipped }

class TestCaseResult {
  TestCaseResult({
    required this.name,
    required this.module,
    this.file,
    this.line,
    required this.status,
    this.failureMessage,
  });

  final String name;
  final String module;
  final String? file;
  final int? line;
  final TestStatus status;

  /// `toString()` of the first error/failure this test raised, if any.
  final String? failureMessage;

  String get location => file == null ? '' : '$file:${line ?? '?'}';
}

/// Aggregated results for one module (a depth-two directory under `test/`,
/// or `integration_test`/`root`/`other` — see [moduleForPath]).
class ModuleSummary {
  ModuleSummary(this.name);

  final String name;
  final List<TestCaseResult> cases = [];

  int get total => cases.length;
  int get passed => cases.where((c) => c.status == TestStatus.passed).length;
  int get failed => cases.where((c) => c.status == TestStatus.failed).length;
  int get skipped =>
      cases.where((c) => c.status == TestStatus.skipped).length;

  bool get isSuccess => failed == 0;
}

/// The full, parsed result of one `flutter test --reporter json` run.
class TestReport {
  TestReport(this.modules, {required this.runSucceeded});

  /// Module name -> its summary. Insertion order is not guaranteed to be
  /// sorted; callers that print should sort by [ModuleSummary.name].
  final Map<String, ModuleSummary> modules;

  /// The reporter's own top-level `done.success` flag (`null` if the run was
  /// killed before completing). We OR this with "any module failed" when
  /// deciding the process exit code, since a crashed run should also fail
  /// CI even if, by chance, no individual test was marked failed.
  final bool? runSucceeded;

  List<ModuleSummary> get sortedModules =>
      modules.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  bool get hasFailures =>
      runSucceeded == false || modules.values.any((m) => !m.isSuccess);

  int get totalTests => modules.values.fold(0, (sum, m) => sum + m.total);
  int get totalPassed => modules.values.fold(0, (sum, m) => sum + m.passed);
  int get totalFailed => modules.values.fold(0, (sum, m) => sum + m.failed);
  int get totalSkipped =>
      modules.values.fold(0, (sum, m) => sum + m.skipped);
}

/// Maps an absolute or relative test-file path to a module name.
///
/// A module is the directory under `test/` at depth two, e.g.
/// `test/data/models/beach_test.dart` -> `data.models`,
/// `test/logic/beach_gear_advisor_test.dart` -> `logic` (only one directory
/// level), `test/widget_test.dart` -> `root` (no directory level), and
/// anything under `integration_test/` -> `integration_test` regardless of
/// depth. Paths that don't look like they're under either directory (e.g. a
/// fixture using a made-up path) fall back to `other`.
String moduleForPath(String rawPath) {
  final normalized = rawPath.replaceAll('\\', '/');

  if (normalized.startsWith('integration_test/') ||
      normalized.contains('/integration_test/')) {
    return 'integration_test';
  }

  String? afterTest;
  const marker = '/test/';
  final markerIndex = normalized.lastIndexOf(marker);
  if (markerIndex != -1) {
    afterTest = normalized.substring(markerIndex + marker.length);
  } else if (normalized.startsWith('test/')) {
    afterTest = normalized.substring('test/'.length);
  }

  if (afterTest == null || afterTest.isEmpty) {
    return 'other';
  }

  final parts = afterTest.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    return 'other';
  }
  // Drop the filename itself, keep directory segments only.
  final dirParts = parts.sublist(0, parts.length - 1);
  if (dirParts.isEmpty) {
    return 'root';
  }
  final depth = dirParts.length >= 2 ? 2 : 1;
  return dirParts.sublist(0, depth).join('.');
}

/// Strips a `file://` prefix (used by the `url` field of some reporter
/// events) and, where possible, trims an absolute path down to the
/// `test/...` or `integration_test/...` suffix so console/JUnit output
/// doesn't leak the machine's absolute filesystem layout.
String relativeTestPath(String rawPath) {
  var path = rawPath;
  if (path.startsWith('file://')) {
    path = Uri.parse(path).toFilePath();
  }
  final normalized = path.replaceAll('\\', '/');
  for (final marker in const ['/integration_test/', '/test/']) {
    final idx = normalized.lastIndexOf(marker);
    if (idx != -1) {
      return normalized.substring(idx + 1);
    }
  }
  if (normalized.startsWith('test/') ||
      normalized.startsWith('integration_test/')) {
    return normalized;
  }
  return normalized;
}

class _TestMeta {
  _TestMeta({
    required this.name,
    required this.suiteID,
    this.line,
    this.url,
    this.rootLine,
    this.rootUrl,
  });

  final String name;
  final int suiteID;
  final int? line;
  final String? url;

  /// For a test defined through a macro like `testWidgets` (itself
  /// implemented on top of `test()`), `url`/`line` point at the macro's own
  /// call to `test()` inside package:flutter_test, not the call site in the
  /// user's test file. `root_url`/`root_line` give the original location in
  /// that case, and are only present when they differ from `url`/`line`
  /// (see doc/json_reporter.md in the `test` package).
  final int? rootLine;
  final String? rootUrl;
}

/// Parses a stream of JSON-reporter lines (as produced by
/// `flutter test --reporter json` / `dart test --reporter json`) into a
/// [TestReport].
///
/// Blank lines are ignored. A line that isn't valid JSON (e.g. stray
/// non-JSON output mixed into the stream) is ignored rather than throwing,
/// so a noisy stream degrades gracefully instead of crashing the summary
/// tool itself.
TestReport parseReporterEvents(Iterable<String> lines) {
  final suitePaths = <int, String>{};
  final tests = <int, _TestMeta>{};
  final firstErrorMessage = <int, String>{};
  final results = <int, String>{}; // testID -> result ("success"/"failure"/"error")
  final hidden = <int, bool>{};
  final skipped = <int, bool>{};
  bool? runSucceeded;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    Map<String, dynamic> event;
    try {
      event = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }

    switch (event['type']) {
      case 'suite':
        final suite = event['suite'] as Map<String, dynamic>;
        final path = suite['path'] as String?;
        if (path != null) {
          suitePaths[suite['id'] as int] = path;
        }
        break;

      case 'testStart':
        final test = event['test'] as Map<String, dynamic>;
        tests[test['id'] as int] = _TestMeta(
          name: test['name'] as String? ?? '',
          suiteID: test['suiteID'] as int,
          line: test['line'] as int?,
          url: test['url'] as String?,
          rootLine: test['root_line'] as int?,
          rootUrl: test['root_url'] as String?,
        );
        break;

      case 'error':
        final testID = event['testID'] as int;
        firstErrorMessage.putIfAbsent(
          testID,
          () => (event['error'] as String? ?? '').trim(),
        );
        break;

      case 'testDone':
        final testID = event['testID'] as int;
        results[testID] = event['result'] as String? ?? 'success';
        hidden[testID] = event['hidden'] as bool? ?? false;
        skipped[testID] = event['skipped'] as bool? ?? false;
        break;

      case 'done':
        runSucceeded = event['success'] as bool?;
        break;

      default:
        break;
    }
  }

  final modules = <String, ModuleSummary>{};

  for (final entry in results.entries) {
    final testID = entry.key;
    if (hidden[testID] == true) {
      // Virtual tests (suite loading, setUpAll/tearDownAll) aren't real
      // test cases and shouldn't appear in per-module counts.
      continue;
    }
    final meta = tests[testID];
    if (meta == null) continue;

    // The suite's own file is always the actual test file that was loaded,
    // so it's the one reliable source for module grouping. `url`/`line`
    // (and, for a test defined through a macro like testWidgets,
    // `root_url`/`root_line`) are more precise for *where in that file* the
    // test is defined, but for a widget test they can point inside
    // package:flutter_test instead of the user's file, so they're used only
    // for the displayed location, never for grouping.
    final suitePath = suitePaths[meta.suiteID] ?? '';
    final displayPath = meta.rootUrl ?? meta.url ?? suitePath;
    final effectiveLine = meta.rootUrl != null ? meta.rootLine : meta.line;
    final moduleName = moduleForPath(suitePath.isNotEmpty ? suitePath : displayPath);
    final module = modules.putIfAbsent(moduleName, () => ModuleSummary(moduleName));

    final result = entry.value;
    final isSkipped = skipped[testID] == true;
    final status = isSkipped
        ? TestStatus.skipped
        : (result == 'success' ? TestStatus.passed : TestStatus.failed);

    module.cases.add(TestCaseResult(
      name: meta.name,
      module: moduleName,
      file: displayPath.isEmpty ? null : relativeTestPath(displayPath),
      line: effectiveLine,
      status: status,
      failureMessage: status == TestStatus.failed ? firstErrorMessage[testID] : null,
    ));
  }

  return TestReport(modules, runSucceeded: runSucceeded);
}

String _statusLabel(ModuleSummary module) =>
    module.isSuccess ? 'SUCCESS ✅' : 'FAILURE ❌';

/// Renders the `> [module:test] Test summary: ...` console block, including
/// failure details (test name, file:line, assertion message) indented under
/// the failing module's line.
String renderConsoleSummary(TestReport report) {
  final buffer = StringBuffer();
  final modules = report.sortedModules;
  if (modules.isEmpty) {
    buffer.writeln('No tests were found in the JSON reporter stream.');
    return buffer.toString();
  }

  final labels = {for (final m in modules) m.name: '[${m.name}:test]'};
  final width = labels.values.map((l) => l.length).reduce((a, b) => a > b ? a : b);

  for (final module in modules) {
    final label = labels[module.name]!.padRight(width + 1);
    buffer.writeln(
      '> $label Test summary: ${_statusLabel(module)} '
      '(${module.total} tests, ${module.passed} passed, ${module.failed} failed, '
      '${module.skipped} skipped)',
    );

    for (final testCase in module.cases) {
      if (testCase.status != TestStatus.failed) continue;
      buffer.writeln('    ✗ ${testCase.name}');
      if (testCase.file != null) {
        buffer.writeln('      at ${testCase.location}');
      }
      final message = testCase.failureMessage;
      if (message != null && message.isNotEmpty) {
        for (final messageLine in message.split('\n')) {
          buffer.writeln('      $messageLine');
        }
      }
    }
  }

  return buffer.toString();
}

String _xmlEscape(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Renders a JUnit XML document: one `<testsuite>` per module, one
/// `<testcase>` per test, `<failure>` nodes for failed tests and
/// `<skipped/>` nodes for skipped ones.
String renderJUnitXml(TestReport report) {
  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln('<testsuites name="BeachIQ Flutter Tests" '
      'tests="${report.totalTests}" failures="${report.totalFailed}" '
      'skipped="${report.totalSkipped}">');

  for (final module in report.sortedModules) {
    buffer.writeln(
      '  <testsuite name="${_xmlEscape(module.name)}" tests="${module.total}" '
      'failures="${module.failed}" skipped="${module.skipped}" errors="0">',
    );
    for (final testCase in module.cases) {
      final hasBody = testCase.status != TestStatus.passed;
      final openTag = '    <testcase classname="${_xmlEscape(module.name)}" '
          'name="${_xmlEscape(testCase.name)}"';
      if (!hasBody) {
        buffer.writeln('$openTag/>');
        continue;
      }
      buffer.writeln('$openTag>');
      if (testCase.status == TestStatus.failed) {
        final message = testCase.failureMessage ?? '';
        final location = testCase.file != null ? ' (${testCase.location})' : '';
        buffer.writeln(
          '      <failure message="${_xmlEscape(message.split('\n').first)}$location">'
          '${_xmlEscape(message)}</failure>',
        );
      } else if (testCase.status == TestStatus.skipped) {
        buffer.writeln('      <skipped/>');
      }
      buffer.writeln('    </testcase>');
    }
    buffer.writeln('  </testsuite>');
  }

  buffer.writeln('</testsuites>');
  return buffer.toString();
}

/// Renders `build/reports/summary.md`: a markdown table mirroring the
/// console summary, plus a failure-detail section when there are any.
String renderMarkdownSummary(TestReport report) {
  final buffer = StringBuffer();
  buffer.writeln('# BeachIQ test summary');
  buffer.writeln();
  buffer.writeln('| Module | Status | Tests | Passed | Failed | Skipped |');
  buffer.writeln('|---|---|---|---|---|---|');
  for (final module in report.sortedModules) {
    final status = module.isSuccess ? '✅ SUCCESS' : '❌ FAILURE';
    buffer.writeln(
      '| ${module.name} | $status | ${module.total} | ${module.passed} | '
      '${module.failed} | ${module.skipped} |',
    );
  }
  buffer.writeln();
  buffer.writeln(
    '**Total:** ${report.totalTests} tests, ${report.totalPassed} passed, '
    '${report.totalFailed} failed, ${report.totalSkipped} skipped.',
  );

  final failingModules = report.sortedModules.where((m) => !m.isSuccess);
  if (failingModules.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## Failures');
    for (final module in failingModules) {
      buffer.writeln();
      buffer.writeln('### ${module.name}');
      for (final testCase in module.cases) {
        if (testCase.status != TestStatus.failed) continue;
        buffer.writeln();
        buffer.writeln('- **${testCase.name}** — `${testCase.location}`');
        final message = testCase.failureMessage;
        if (message != null && message.isNotEmpty) {
          buffer.writeln();
          buffer.writeln('  ```');
          for (final messageLine in message.split('\n')) {
            buffer.writeln('  $messageLine');
          }
          buffer.writeln('  ```');
        }
      }
    }
  }

  return buffer.toString();
}
