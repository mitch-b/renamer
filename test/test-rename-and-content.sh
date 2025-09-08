#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_rename_and_content"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR"
echo 'foo body foo' > "$TEST_DIR/foo-file.txt"
echo 'nothing' > "$TEST_DIR/other.txt"

pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" foo bar 2>&1 <<<"y" || true)
popd >/dev/null

[[ -f "$TEST_DIR/bar-file.txt" ]] || { echo "Renamed file not found"; echo "$OUT"; exit 1; }
grep -q 'bar body bar' "$TEST_DIR/bar-file.txt" || { echo "Content not replaced inside file"; echo "$OUT"; exit 1; }
grep -q 'Files with content replaced' <<<"$OUT" || { echo "Summary missing content replacement line"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Rename and content test passed"
