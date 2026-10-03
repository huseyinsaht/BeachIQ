#!/usr/bin/env bash
# Shared entry point for running BeachIQ's Flutter test suite, used by both
# CI (.github/workflows/ci.yml, job analyze-and-test) and local development.
#
# Prints a banner, runs `flutter test --coverage --concurrency=4 --reporter
# json`, pipes that JSON stream into tools/test_summary.dart which prints one
# `Test summary:` line per module (plus failure details) and writes
# build/reports/junit.xml and build/reports/summary.md, then exits non-zero
# if any module had a failure.
#
# Written in portable POSIX sh/bash (no bash-only arrays, no GNU-only flags)
# so it also runs under Git Bash on Windows. Run it from the repository root:
#
#   bash tools/run_tests.sh
#
set -eu

# Resolve the repo root without relying on `realpath`/`readlink -f` (not
# available in Git Bash on Windows): the script lives in <root>/tools/, so
# its own directory's parent is the root.
script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
cd "$repo_root"

echo "=============================="
echo " Run BeachIQ Flutter Tests"
echo "=============================="

mkdir -p build/reports

json_output="build/reports/test-events.jsonl"

# `flutter test` exits non-zero when any test fails. We still want to run
# the summary tool against whatever JSON it produced, so capture the exit
# code instead of letting `set -e` stop the script here.
test_exit_code=0
flutter test --coverage --concurrency=4 --reporter json >"$json_output" || test_exit_code=$?

summary_exit_code=0
dart run tools/test_summary.dart "$json_output" || summary_exit_code=$?

if [ "$summary_exit_code" -ne 0 ]; then
  exit "$summary_exit_code"
fi

# The summary tool parsed every test as passing, but `flutter test` itself
# still reported failure (e.g. a crash before any JSON was written) -- don't
# let that go unnoticed.
if [ "$test_exit_code" -ne 0 ]; then
  echo "flutter test exited with status $test_exit_code even though no failing test was reported; failing the build." >&2
  exit "$test_exit_code"
fi

exit 0
