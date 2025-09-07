#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_binary_skip"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR"
printf 'BIN\x00DATA MAGICSTR\n' > "$TEST_DIR/blob.bin"
echo 'MAGICSTR text file' > "$TEST_DIR/plain.txt"

# Run replacement WITHOUT binary inclusion
pushd "$TEST_DIR" >/dev/null
NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" MAGICSTR REPLACED --skip-contents 2>&1 <<<"n" >/dev/null || true
popd >/dev/null

# No rename should happen because filenames do not contain MAGICSTR
grep -q 'MAGICSTR' "$TEST_DIR/blob.bin" || { echo "Binary file content changed unexpectedly (skip)"; exit 1; }

# Now run WITH binary inclusion and content replacement
pushd "$TEST_DIR" >/dev/null
OUTPUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" MAGICSTR REPLACED --include-binary 2>&1 <<<"y" || true)
popd >/dev/null

grep -q 'REPLACED' "$TEST_DIR/blob.bin" || { echo "Binary file not modified with --include-binary"; echo "$OUTPUT"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Binary skip/include test passed"
