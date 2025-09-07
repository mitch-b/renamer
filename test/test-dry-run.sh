#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_dry_run"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR/sub"
echo "alpha target text" > "$TEST_DIR/file-target.txt"
echo "target here" > "$TEST_DIR/sub/inner-target.txt"

pushd "$TEST_DIR" >/dev/null
OUTPUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" target replaced -n 2>&1 || true)
popd >/dev/null

# Ensure dry run indicator present
grep -q "Dry run mode: NO changes will be made" <<<"$OUTPUT" || { echo "Dry run flag message missing"; exit 1; }
grep -q "Dry run complete" <<<"$OUTPUT" || { echo "Dry run completion missing"; exit 1; }

# Ensure files still contain original text
grep -q 'target' "$TEST_DIR/file-target.txt" || { echo "Content unexpectedly modified (file-target)"; exit 1; }
grep -q 'target' "$TEST_DIR/sub/inner-target.txt" || { echo "Content unexpectedly modified (inner-target)"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Dry run test passed"
