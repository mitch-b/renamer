#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_no_matches"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR"
echo 'unrelated content' > "$TEST_DIR/unrelated.txt"

pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" ZZZNOMATCHZZZ replaced --force 2>&1 || true)
popd >/dev/null

# Nothing should be changed
[[ -f "$TEST_DIR/unrelated.txt" ]] || { echo "Unrelated file was unexpectedly removed"; echo "$OUT"; exit 1; }
grep -q 'unrelated content' "$TEST_DIR/unrelated.txt" || { echo "Content unexpectedly changed"; echo "$OUT"; exit 1; }

# Summary should reflect zero changes
grep -q 'No changes applied' <<<"$OUT" || { echo "Expected 'No changes applied' in output"; echo "$OUT"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ No-matches test passed"
