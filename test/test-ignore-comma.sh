#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_ignore_comma"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR/a" "$TEST_DIR/b" "$TEST_DIR/c"
echo 'foo text' > "$TEST_DIR/a/file-foo.txt"
echo 'foo text' > "$TEST_DIR/b/file-foo.txt"
echo 'foo text' > "$TEST_DIR/c/file-foo.txt"

pushd "$TEST_DIR" >/dev/null
# Pass two directories to ignore as comma-separated list
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" foo bar --ignore "a/,b/" 2>&1 <<<"n" || true)
popd >/dev/null

# Only c/ should appear; a/ and b/ should be ignored
grep -q 'c/file-foo.txt' <<<"$OUT" || { echo "Expected file in c/ to appear"; echo "$OUT"; exit 1; }
grep -q 'a/file-foo.txt' <<<"$OUT" && { echo "a/ appeared despite being ignored"; echo "$OUT"; exit 1; }
grep -q 'b/file-foo.txt' <<<"$OUT" && { echo "b/ appeared despite being ignored"; echo "$OUT"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Comma-separated --ignore test passed"
