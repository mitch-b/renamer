#!/bin/bash

# Test script to verify that .renamerignore files are automatically excluded from modifications
# This test ensures .renamerignore files are never renamed or have their content modified

set -e

echo "🧪 Testing .renamerignore exclusion..."

# Create test directory structure
TEST_DIR="test_renamerignore_exclusion_temp"
mkdir -p "$TEST_DIR"/{subdir1,subdir2}

# Create test files with "rename" in the filename and content
echo "This content contains rename text" > "$TEST_DIR/test-rename-file.txt"
echo "Another rename content" > "$TEST_DIR/subdir1/rename-me.txt"

# Create .renamerignore files with "rename" in their content
cat > "$TEST_DIR/.renamerignore" << 'EOF'
# This .renamerignore file has rename in its content
*.log
rename-logs/
EOF

cat > "$TEST_DIR/subdir1/.renamerignore" << 'EOF'
# Another .renamerignore with rename content
temp/
EOF

# Create a regular file that should be processed
echo "Regular file with rename text" > "$TEST_DIR/normalfile.txt"

cd "$TEST_DIR"

# Test the script and capture output
echo "Running renamer script..."
output=$(echo "n" | bash ../rename-find-replace.sh rename errr 2>&1)

echo "Script output:"
echo "$output"
echo ""

# Verify that .renamerignore files are NOT shown in the matching sections
matches_section=$(echo "$output" | sed -n '/Sample matching/,/Proceed with/p')

if echo "$matches_section" | grep -q "\.renamerignore"; then
    echo "❌ FAIL: .renamerignore file was not excluded from file name matches"
    echo "Matches section:"
    echo "$matches_section"
    exit 1
fi

# Check if .renamerignore appears in content matches
if echo "$output" | grep -A 10 "Sample file content matches:" | grep -q "\.renamerignore"; then
    echo "❌ FAIL: .renamerignore file was not excluded from content matches"
    exit 1
fi

# Verify that normal files with "rename" ARE shown
if ! echo "$output" | grep -q "test-rename-file.txt"; then
    echo "❌ FAIL: test-rename-file.txt should be shown but was excluded"
    exit 1
fi

if ! echo "$output" | grep -q "normalfile.txt"; then
    echo "❌ FAIL: normalfile.txt should be shown but was excluded"
    exit 1
fi

echo "✅ All tests passed! .renamerignore files are properly excluded."

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo "🎉 Test completed successfully"