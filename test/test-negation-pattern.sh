#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="temp_test_negation"
rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR/dist"
echo 'target value' > "$TEST_DIR/dist/keep.txt"
echo 'target value' > "$TEST_DIR/dist/omit.txt"
cat > "$TEST_DIR/.renamerignore" <<EOF
dist/
!dist/keep.txt
EOF

pushd "$TEST_DIR" >/dev/null
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" target replaced 2>&1 <<<"n" || true)
popd >/dev/null

# keep.txt should appear, omit.txt should not
grep -q 'keep.txt' <<<"$OUT" || { echo "keep.txt not included via negation"; exit 1; }
grep -q 'omit.txt' <<<"$OUT" && { echo "omit.txt incorrectly included despite directory ignore"; exit 1; }

rm -rf "$TEST_DIR"
echo "✅ Negation pattern test passed"
