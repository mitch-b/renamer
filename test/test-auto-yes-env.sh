#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_auto_yes_env"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR"
echo 'alpha content' > "$TEST_DIR/alpha-file.txt"

pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 RENAMER_AUTO_YES=1 bash "$REPO_ROOT/rename-find-replace.sh" alpha beta 2>&1 </dev/null || true)
popd >/dev/null

# Changes should have been applied automatically (no prompt needed)
[[ -f "$TEST_DIR/beta-file.txt" ]] || { echo "File was not renamed with RENAMER_AUTO_YES=1"; echo "$OUT"; exit 1; }
grep -q 'beta content' "$TEST_DIR/beta-file.txt" || { echo "Content was not replaced with RENAMER_AUTO_YES=1"; echo "$OUT"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ RENAMER_AUTO_YES env var test passed"
