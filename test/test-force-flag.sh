#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_force_flag"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR"

echo 'force sample foo' > "$TEST_DIR/foo.txt"

pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" foo bar --force 2>&1 || true)
popd >/dev/null

# Ensure file renamed and content replaced automatically
[[ -f "$TEST_DIR/bar.txt" ]] || { echo "Force flag did not rename file"; echo "$OUT"; exit 1; }
grep -q 'bar' "$TEST_DIR/bar.txt" || { echo "Force flag did not replace content"; echo "$OUT"; exit 1; }

echo "$OUT" | grep -Fq -- "--force supplied" || { echo "Force flag message missing"; echo "$OUT"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Force flag test passed"
