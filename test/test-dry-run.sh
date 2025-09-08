#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_preview"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR/sub"
echo "alpha target text" > "$TEST_DIR/file-target.txt"
echo "target here" > "$TEST_DIR/sub/inner-target.txt"

pushd "$TEST_DIR" >/dev/null
# Use deprecated -n to ensure backward compatibility path prints deprecation and auto-aborts
OUTPUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" target replaced -n 2>&1 || true)
popd >/dev/null

grep -q "deprecated" <<<"$OUTPUT" || { echo "Deprecated dry-run warning missing"; echo "$OUTPUT"; exit 1; }
grep -q "Files with matching content" <<<"$OUTPUT" || { echo "Plan summary missing content list"; exit 1; }
grep -q "File renames:" <<<"$OUTPUT" || { echo "Plan summary missing file rename list"; exit 1; }
grep -q "(Preview only" <<<"$OUTPUT" || { echo "Preview-only message missing"; echo "$OUTPUT"; exit 1; }

# Ensure files unchanged
grep -q 'target' "$TEST_DIR/file-target.txt" || { echo "Content unexpectedly modified (file-target)"; exit 1; }
grep -q 'target' "$TEST_DIR/sub/inner-target.txt" || { echo "Content unexpectedly modified (inner-target)"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Preview (former dry-run) test passed"
