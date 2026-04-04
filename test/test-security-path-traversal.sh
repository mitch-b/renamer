#!/usr/bin/env bash
# Verify that a REPLACE value containing '..' cannot move files outside the
# working directory (path traversal protection).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="$(mktemp -d temp_test_security_path_traversal.XXXXXX)"
OUTSIDE_DIR="$(mktemp -d /tmp/renamer_outside_test.XXXXXX)"

cleanup() { rm -rf "$TEST_DIR" "$OUTSIDE_DIR"; }
trap cleanup EXIT

mkdir -p "$TEST_DIR/myapp"
echo 'data' > "$TEST_DIR/myapp/config.txt"

pushd "$TEST_DIR" >/dev/null
# REPLACE is crafted so that the new path would escape via '..'
# myapp → ../../tmp/renamer_outside would point outside the working directory.
OUTSIDE_BASENAME="$(basename "$OUTSIDE_DIR")"
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" myapp "../../tmp/${OUTSIDE_BASENAME}" 2>&1 <<<"y" || true)
popd >/dev/null

# The directory 'myapp' must still exist (rename blocked).
if [[ ! -d "$TEST_DIR/myapp" ]]; then
    echo "FAIL: myapp directory was renamed despite traversal attempt"
    echo "$OUT"
    exit 1
fi

# Nothing should have been created in the outside directory.
if [[ -d "$OUTSIDE_DIR/myapp" ]] || ls "$OUTSIDE_DIR" 2>/dev/null | grep -q .; then
    echo "FAIL: files were moved outside the working directory"
    echo "Contents of $OUTSIDE_DIR: $(ls -la "$OUTSIDE_DIR")"
    echo "$OUT"
    exit 1
fi

grep -qi 'path traversal blocked' <<<"$OUT" \
    || { echo "FAIL: expected 'Path traversal blocked' warning in output"; echo "$OUT"; exit 1; }

echo "✅ Path traversal security test passed"
