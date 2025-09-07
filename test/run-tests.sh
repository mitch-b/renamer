#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

echo "== Running Renamer Test Suite =="
echo

FILTER="${1:-}"

FAILS=0
TOTAL=0

set +e  # manage test failures manually inside loop
for test_file in "$SCRIPT_DIR"/test-*.sh; do
  [[ -f "$test_file" ]] || continue
  base="$(basename "$test_file")"
  if [[ -n "$FILTER" && "$base" != *"$FILTER"* ]]; then
    continue
  fi
  ((TOTAL++))
  echo "--- $base ---"
  bash "$test_file" >"$SCRIPT_DIR/_out_${base}.log" 2>&1
  status=$?
  if [[ $status -eq 0 ]]; then
    echo "PASS: $base"
  else
    echo "FAIL: $base" >&2
    echo "---- BEGIN OUTPUT ($base) ----" >&2
    sed 's/^/| /' "$SCRIPT_DIR/_out_${base}.log" >&2 || true
    echo "---- END OUTPUT ($base) ----" >&2
    ((FAILS++))
  fi
  echo
done
set -e

echo "Total: $TOTAL  Failed: $FAILS"
if (( FAILS > 0 )); then
  exit 1
fi
echo "All tests passed."
