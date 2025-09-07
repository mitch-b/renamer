#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_include_override"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR/ignoredir"
echo 'foo value' > "$TEST_DIR/ignoredir/file.txt"
echo 'ignoredir/' > "$TEST_DIR/.renamerignore"

pushd "$TEST_DIR" >/dev/null
# First run without include: ensure content not matched
OUT1=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" foo bar -n 2>&1 || true)
grep -q 'file.txt' <<<"$OUT1" && { echo "File should be ignored but appeared without include"; exit 1; }

# Run with include override
OUT2=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" foo bar -n --include ignoredir/ 2>&1 || true)
grep -q 'file.txt' <<<"$OUT2" || { echo "File did not appear with --include override"; exit 1; }
popd >/dev/null

rm -rf "$TEST_DIR"
echo "✅ Include override test passed"
