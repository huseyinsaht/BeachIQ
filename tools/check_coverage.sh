#!/usr/bin/env bash
# Prints per-module line coverage from coverage/lcov.info (written by
# `flutter test --coverage`, which tools/run_tests.sh always runs with) and
# fails the build when total line coverage drops below
# tools/coverage_baseline.txt.
#
# A "module" here is the same depth-two grouping tools/test_summary.dart uses
# for tests, but applied to lib/ instead: lib/data/models/beach.dart ->
# data.models, lib/logic/uv_band.dart -> logic, etc. This lets the
# per-module breakdown be compared directly against the per-module test
# summary.
#
# Excluded from coverage (generated / non-reviewable code -- there is
# currently none of this in lib/, but any future generated file, e.g.
# *.g.dart or *.freezed.dart from build_runner, should be added here so a
# vendor-generated file never drags the baseline around):
#   - lib/**/*.g.dart
#   - lib/**/*.freezed.dart
#   - lib/**/*.mocks.dart
#
# Usage (run from the repository root, after `flutter test --coverage`):
#   bash tools/check_coverage.sh
#
set -eu

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
cd "$repo_root"

lcov_file="coverage/lcov.info"
baseline_file="tools/coverage_baseline.txt"

if [ ! -f "$lcov_file" ]; then
  echo "check_coverage: $lcov_file not found. Run \`flutter test --coverage\` (or tools/run_tests.sh) first." >&2
  exit 1
fi

if [ ! -f "$baseline_file" ]; then
  echo "check_coverage: $baseline_file not found." >&2
  exit 1
fi

baseline=$(tr -d '[:space:]' <"$baseline_file")
case "$baseline" in
  ''|*[!0-9]*)
    echo "check_coverage: $baseline_file must contain a whole-number percentage, got '$baseline'." >&2
    exit 1
    ;;
esac

# Generated-file exclusions (see header comment). A file is skipped entirely
# -- it contributes to neither its module's nor the total's LF/LH -- when its
# path (relative to the repo root, as lcov records it) matches one of these
# suffixes.
is_excluded() {
  case "$1" in
    *.g.dart|*.freezed.dart|*.mocks.dart) return 0 ;;
    *) return 1 ;;
  esac
}

# Map an lcov SF: path (e.g. lib/data/models/beach.dart) to the same
# depth-two module naming tools/test_summary.dart uses for tests.
module_for_path() {
  path="$1"
  case "$path" in
    lib/*) rest=${path#lib/} ;;
    *) echo "other"; return ;;
  esac
  dir=$(dirname "$rest")
  if [ "$dir" = "." ]; then
    echo "root"
    return
  fi
  first=${dir%%/*}
  if [ "$first" = "$dir" ]; then
    echo "$first"
  else
    second=${dir#*/}
    second=${second%%/*}
    echo "$first.$second"
  fi
}

modules_file=$(mktemp)
trap 'rm -f "$modules_file"' EXIT

current_path=""
current_lf=0
current_lh=0
skip_current=0

flush_current() {
  if [ -n "$current_path" ] && [ "$skip_current" -eq 0 ]; then
    module=$(module_for_path "$current_path")
    echo "$module $current_lf $current_lh" >>"$modules_file"
  fi
}

while IFS= read -r line; do
  case "$line" in
    SF:*)
      flush_current
      current_path="${line#SF:}"
      current_lf=0
      current_lh=0
      if is_excluded "$current_path"; then
        skip_current=1
      else
        skip_current=0
      fi
      ;;
    LF:*)
      current_lf="${line#LF:}"
      ;;
    LH:*)
      current_lh="${line#LH:}"
      ;;
    end_of_record)
      flush_current
      current_path=""
      ;;
  esac
done <"$lcov_file"
flush_current

if [ ! -s "$modules_file" ]; then
  echo "check_coverage: no coverage data found in $lcov_file." >&2
  exit 1
fi

echo "=============================="
echo " Coverage by module"
echo "=============================="

total_lf=0
total_lh=0

# Aggregate per module (a module may span several SF: entries) and print a
# sorted breakdown.
awk '{ lf[$1]+=$2; lh[$1]+=$3 } END { for (m in lf) printf "%s %d %d\n", m, lf[m], lh[m] }' \
  "$modules_file" | sort >"$modules_file.agg"

while read -r module lf lh; do
  total_lf=$((total_lf + lf))
  total_lh=$((total_lh + lh))
  if [ "$lf" -gt 0 ]; then
    pct=$((lh * 100 / lf))
  else
    pct=100
  fi
  printf '> [%s] %d%% (%d/%d lines)\n' "$module" "$pct" "$lh" "$lf"
done <"$modules_file.agg"
rm -f "$modules_file.agg"

if [ "$total_lf" -gt 0 ]; then
  total_pct=$((total_lh * 100 / total_lf))
else
  total_pct=100
fi

echo "------------------------------"
printf 'Total: %d%% (%d/%d lines), baseline %d%%\n' "$total_pct" "$total_lh" "$total_lf" "$baseline"

if [ "$total_pct" -lt "$baseline" ]; then
  echo "check_coverage: total line coverage $total_pct% is below the $baseline% baseline in $baseline_file." >&2
  exit 1
fi

exit 0
