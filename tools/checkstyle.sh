#!/usr/bin/env bash
# Checkstyle gate for BeachIQ: style and lint violations fail CI the same
# way a checkstyle run fails a build in Java projects. Used by both CI
# (.github/workflows/ci.yml, job analyze-and-test) and local development:
#
#   bash tools/checkstyle.sh
#
# It runs two checks against the whole project (lib/, test/, integration_test/
# and the top-level *.dart files in tools/):
#
#   1. `dart format --output=none --set-exit-if-changed` -- fails if any file
#      is not canonically formatted.
#   2. `dart analyze --fatal-infos --fatal-warnings` -- fails on any analyzer
#      issue, which now includes the extra strict rule set added to
#      analysis_options.yaml on top of flutter_lints (prefer_final_locals,
#      require_trailing_commas, avoid_print, unawaited_futures, etc).
#
# tools/test_fixtures/checkstyle/ is deliberately excluded from both the
# default format targets and analysis_options.yaml's analyzer.exclude: those
# tiny fixtures are intentionally non-compliant samples that exist only to
# exercise this script's own test (test/tools/checkstyle_test.dart), not
# production code.
#
# A single optional argument scopes both checks to one directory instead of
# the whole project -- this is how the script's own test points it at tiny
# fixtures under tools/test_fixtures/checkstyle/ to exercise the
# formatting-violation and lint-violation failure paths in isolation:
#
#   bash tools/checkstyle.sh tools/test_fixtures/checkstyle/clean
#
# Prints one line per violation as `file:line rule message`, then a final
# summary line:
#
#   Checkstyle summary: SUCCESS ✅ (N files checked, 0 violations)
#   Checkstyle summary: FAILURE ❌ (N files checked, M violations)
#
# Written in portable POSIX sh/bash (see tools/run_tests.sh for why) and run
# from the repository root regardless of the caller's cwd.
set -eu

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
cd "$repo_root"

target="${1:-}"

echo "=============================="
echo " BeachIQ Checkstyle"
echo "=============================="

violations_file=$(mktemp)
trap 'rm -f "$violations_file"' EXIT

if [ -n "$target" ]; then
  # Scoped run (used by this script's own test against tiny fixtures).
  format_target_list="$target"
  analyze_target="$target"
else
  # Whole-project default. "tools"'s *.dart files are listed individually
  # (not the directory) so dart format never descends into
  # tools/test_fixtures/ -- see header comment.
  format_target_list="lib test integration_test $(find tools -maxdepth 1 -name '*.dart')"
  analyze_target="."
fi

files_checked=$(find $format_target_list -name '*.dart' 2>/dev/null | wc -l | tr -d ' ')

# ---- 1. dart format: formatting drift -----------------------------------
format_exit=0
format_output=$(dart format --output=none --set-exit-if-changed $format_target_list 2>&1) || format_exit=$?

while IFS= read -r line; do
  case "$line" in
    "Changed "*)
      file="${line#Changed }"
      printf '%s:- dart_format File is not canonically formatted; run `dart format %s`.\n' \
        "$file" "$file" >>"$violations_file"
      ;;
  esac
done <<EOF
$format_output
EOF

# ---- 2. dart analyze: flutter_lints + the project's strict extra rules ---
# --format=machine gives a stable, pipe-delimited line per issue:
#   SEVERITY|TYPE|ERROR_CODE|FILE_PATH|LINE|COLUMN|LENGTH|ERROR_MESSAGE
analyze_exit=0
analyze_output=$(dart analyze --fatal-infos --fatal-warnings --format=machine "$analyze_target" 2>&1) || analyze_exit=$?

while IFS='|' read -r severity _type code file line _column _length message; do
  case "$severity" in
    ERROR | WARNING | INFO) ;;
    *) continue ;;
  esac
  rel_file="${file#"$repo_root"/}"
  rule=$(printf '%s' "$code" | tr '[:upper:]' '[:lower:]')
  printf '%s:%s %s %s\n' "$rel_file" "$line" "$rule" "$message" >>"$violations_file"
done <<EOF
$analyze_output
EOF

violation_count=$(wc -l <"$violations_file" | tr -d ' ')

echo
if [ "$violation_count" -eq 0 ]; then
  echo "Checkstyle summary: SUCCESS ✅ ($files_checked files checked, 0 violations)"
  exit 0
fi

echo "Checkstyle violations:"
cat "$violations_file"
echo
echo "Checkstyle summary: FAILURE ❌ ($files_checked files checked, $violation_count violations)"
exit 1
