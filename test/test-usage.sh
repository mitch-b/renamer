#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

# Run without arguments and expect exit code 1 and usage text
OUT=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" 2>&1 || true)
EXIT_CODE=$(NO_COLOR=1 bash "$REPO_ROOT/rename-find-replace.sh" 2>/dev/null; echo $?) || true
EXIT_CODE=$(bash -c "NO_COLOR=1 bash '$REPO_ROOT/rename-find-replace.sh'; echo \$?" 2>/dev/null | tail -1)

[[ "$EXIT_CODE" == "1" ]] || { echo "Expected exit code 1 with no args, got: $EXIT_CODE"; exit 1; }
grep -qi 'usage\|renamer\|find.*replace\|docker' <<<"$OUT" || { echo "Expected usage text in output"; echo "$OUT"; exit 1; }

echo "✅ Usage message test passed"
