#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_abort"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR"
echo 'hello world' > "$TEST_DIR/hello.txt"

pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" hello goodbye 2>&1 <<<"n" || true)
popd >/dev/null

# File should still have original name and content
[[ -f "$TEST_DIR/hello.txt" ]] || { echo "File was renamed despite aborting"; echo "$OUT"; exit 1; }
grep -q 'hello world' "$TEST_DIR/hello.txt" || { echo "Content was modified despite aborting"; echo "$OUT"; exit 1; }
grep -q 'Aborted by user' <<<"$OUT" || { echo "Abort message missing from output"; echo "$OUT"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Abort test passed"
