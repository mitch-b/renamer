#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_ignore_cli"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR/a" "$TEST_DIR/b"
echo 'foo zzz' > "$TEST_DIR/a/file-foo.txt"
echo 'foo yyy' > "$TEST_DIR/b/file-foo.txt"

pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" foo bar -n --ignore a/ 2>&1 || true)
popd >/dev/null

grep -q 'b/file-foo.txt' <<<"$OUT" || { echo "Expected file in b/ missing"; exit 1; }
grep -q 'a/file-foo.txt' <<<"$OUT" && { echo "Ignored directory a/ appeared"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ CLI ignore flag test passed"
