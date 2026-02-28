#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_complex_folder_file_content"
rm -rf "$TEST_DIR"

# Create a nested folder structure where the folder name, file name, AND content all contain the find pattern
mkdir -p "$TEST_DIR/acme-project/acme-lib"
echo 'acme init acme' > "$TEST_DIR/acme-project/acme-file.txt"
echo 'acme lib code' > "$TEST_DIR/acme-project/acme-lib/acme-module.txt"
echo 'unrelated content' > "$TEST_DIR/acme-project/other.txt"

pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" acme widget 2>&1 <<<"y" || true)
popd >/dev/null

# Verify directory renames
[[ -d "$TEST_DIR/widget-project" ]] || { echo "Top-level directory not renamed"; echo "$OUT"; exit 1; }
[[ -d "$TEST_DIR/widget-project/widget-lib" ]] || { echo "Nested directory not renamed"; echo "$OUT"; exit 1; }

# Verify file renames (these fail without the fix because the directory was renamed first)
[[ -f "$TEST_DIR/widget-project/widget-file.txt" ]] || { echo "File in renamed dir not renamed"; echo "$OUT"; exit 1; }
[[ -f "$TEST_DIR/widget-project/widget-lib/widget-module.txt" ]] || { echo "File in nested renamed dir not renamed"; echo "$OUT"; exit 1; }

# Verify content replacement
grep -q 'widget init widget' "$TEST_DIR/widget-project/widget-file.txt" || { echo "Content not replaced in renamed file"; echo "$OUT"; exit 1; }
grep -q 'widget lib code' "$TEST_DIR/widget-project/widget-lib/widget-module.txt" || { echo "Content not replaced in nested renamed file"; echo "$OUT"; exit 1; }

# Verify unrelated file is untouched
grep -q 'unrelated content' "$TEST_DIR/widget-project/other.txt" || { echo "Unrelated file was unexpectedly modified"; echo "$OUT"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Complex folder/file/content rename test passed"
