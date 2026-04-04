#!/usr/bin/env bash
# Verify that REPLACE values containing sed special characters (/, &, e-flag)
# are escaped and do NOT trigger code execution or corrupt file content.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_security_sed_injection"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR"

###############################################################################
# Case 1: REPLACE contains '/' (sed delimiter)
###############################################################################
echo 'hello world' > "$TEST_DIR/file1.txt"
pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" hello "hi/there" 2>&1 <<<"y" || true)
popd >/dev/null

grep -q 'hi/there world' "$TEST_DIR/file1.txt" \
    || { echo "FAIL: slash in REPLACE not handled correctly"; echo "Content: $(cat "$TEST_DIR/file1.txt")"; echo "$OUT"; exit 1; }

###############################################################################
# Case 2: REPLACE contains '&' (sed back-reference)
###############################################################################
echo 'foo bar' > "$TEST_DIR/file2.txt"
pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" foo "a&b" 2>&1 <<<"y" || true)
popd >/dev/null

grep -q 'a&b bar' "$TEST_DIR/file2.txt" \
    || { echo "FAIL: '&' in REPLACE was treated as back-reference, not literal"; echo "Content: $(cat "$TEST_DIR/file2.txt")"; echo "$OUT"; exit 1; }

###############################################################################
# Case 3: REPLACE crafted to inject the GNU sed 'e' flag ("/e" suffix)
# If not escaped, sed would execute the replacement as a shell command.
# We verify the file content is the literal replacement string, not command output.
###############################################################################
echo 'secret' > "$TEST_DIR/file3.txt"
pushd "$TEST_DIR" >/dev/null
# "id/e" would activate sed's execute flag if the delimiter is not escaped.
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" secret "safe/e" 2>&1 <<<"y" || true)
popd >/dev/null

grep -q 'safe/e' "$TEST_DIR/file3.txt" \
    || { echo "FAIL: 'e' flag injection not blocked; file content: $(cat "$TEST_DIR/file3.txt")"; echo "$OUT"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ sed injection security test passed"
