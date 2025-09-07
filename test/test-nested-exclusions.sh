#!/bin/bash

# Test script to verify that nested exclusions work correctly
# This test ensures files and folders in ignored directories are properly excluded

set -euo pipefail

# Resolve repo root (directory containing this script)/..
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$REPO_ROOT"

echo "🧪 Testing nested exclusions..."

# Create test directory structure
TEST_DIR="test_nested_exclusions_temp"
mkdir -p "$TEST_DIR"/{src/project/{bin,dist},node_modules,logs}

# Create test files
echo "test content" > "$TEST_DIR/src/project/bin/test.dll"
echo "test content" > "$TEST_DIR/src/project/dist/bundle.js"
echo "test content" > "$TEST_DIR/node_modules/package.json"
echo "test content" > "$TEST_DIR/logs/app.log"
echo "test content" > "$TEST_DIR/normalfile.txt"

# Create .renamerignore with directory patterns
cat > "$TEST_DIR/.renamerignore" << 'EOF'
bin/
dist/
node_modules/
*.log
EOF

cd "$TEST_DIR"

# Test the script and capture output
echo "Running renamer script..."
output=$(echo "n" | bash "$REPO_ROOT/rename-find-replace.sh" test replaced 2>&1)

echo "Script output:"
echo "$output"
echo ""

# Verify that ignored files/folders are NOT shown in the matching sections
matches_section=$(echo "$output" | sed -n '/Sample matching/,/Proceed with/p')

if echo "$matches_section" | grep -q "src/project/bin"; then
    echo "❌ FAIL: bin/ directory was not excluded"
    exit 1
fi

if echo "$matches_section" | grep -q "src/project/dist"; then
    echo "❌ FAIL: dist/ directory was not excluded"
    exit 1
fi

if echo "$matches_section" | grep -q "./node_modules"; then
    echo "❌ FAIL: node_modules/ directory was not excluded"
    exit 1
fi

if echo "$matches_section" | grep -q "app.log"; then
    echo "❌ FAIL: *.log file was not excluded"
    exit 1
fi

# Verify that non-ignored files ARE shown
if ! echo "$output" | grep -q "normalfile.txt"; then
    echo "❌ FAIL: normalfile.txt should be shown but was excluded"
    exit 1
fi

echo "✅ All tests passed! Nested exclusions work correctly."

# Cleanup
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"

echo "🎉 Test completed successfully"
