#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_skip_contents"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR"
echo 'alpha bravo charlie' > "$TEST_DIR/original.txt"

pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" alpha beta --skip-contents <<<"y" 2>&1 || true)
popd >/dev/null

grep -q 'alpha bravo' "$TEST_DIR/original.txt" || { echo "Content changed despite --skip-contents"; exit 1; }
[[ -f "$TEST_DIR/original.txt" ]] || { echo "File unexpectedly renamed"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Skip contents test passed"
