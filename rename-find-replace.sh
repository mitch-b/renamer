#!/bin/bash

# Function to print colored ASCII header
print_header() {
    echo -e "\e[35m"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║      🔁  FIND & REPLACE RENAME UTILITY 🔁        ║"
    echo "╠══════════════════════════════════════════════════╣"
    echo "║  Renames folders, files, and contents recursively║"
    echo "║  Use with caution – preview first!               ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "\e[0m"
}


# Function to read ignore patterns from .renamerignore file
read_ignore_file() {
    local ignore_file=".renamerignore"
    local patterns=()
    
    if [[ -f "$ignore_file" ]]; then
        while IFS= read -r line; do
            # Skip empty lines and comments
            if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                # Trim whitespace
                line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ -n "$line" ]]; then
                    patterns+=("$line")
                fi
            fi
        done < "$ignore_file"
    fi
    
    echo "${patterns[@]}"
}

# Parse arguments: positional for find/replace, optional flags
SKIP_CONTENTS=0
IGNORE_PATTERNS=()
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-contents)
            SKIP_CONTENTS=1
            shift
            ;;
        --ignore)
            if [[ -n "$2" && "$2" != --* ]]; then
                # Support comma-separated patterns
                IFS=',' read -ra PATTERNS <<< "$2"
                for pattern in "${PATTERNS[@]}"; do
                    # Trim whitespace
                    pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$pattern" ]]; then
                        IGNORE_PATTERNS+=("$pattern")
                    fi
                done
                shift 2
            else
                echo "Error: --ignore requires a pattern argument"
                exit 1
            fi
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done
set -- "${POSITIONAL[@]}"

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <find> <replace> [--skip-contents] [--ignore <pattern>]..."
    echo "  --skip-contents: Skip replacing text inside files"
    echo "  --ignore <pattern>: Ignore paths matching pattern(s)"
    echo "                     Supports comma-separated: --ignore 'build,dist,temp'"
    echo "                     Can be used multiple times: --ignore build --ignore dist"
    echo ""
    echo "Ignore patterns are read from:"
    echo "  1. Built-in defaults: .git/, node_modules/"
    echo "  2. .renamerignore file (if present)"
    echo "  3. --ignore flags"
    echo ""
    echo "Example .renamerignore file:"
    echo "  # Common build artifacts"
    echo "  dist"
    echo "  build"
    echo "  target"
    echo "  *.log"
    exit 1
fi
FIND="$1"
REPLACE="$2"

# Default ignore patterns (common directories that should typically be excluded)
DEFAULT_IGNORE_PATTERNS=(".git" "node_modules")

# Read patterns from .renamerignore file
FILE_IGNORE_PATTERNS=($(read_ignore_file))

# Combine all ignore patterns: defaults + file + command line
ALL_IGNORE_PATTERNS=("${DEFAULT_IGNORE_PATTERNS[@]}" "${FILE_IGNORE_PATTERNS[@]}" "${IGNORE_PATTERNS[@]}")

# Build find exclusions array
FIND_EXCLUSIONS=()
for pattern in "${ALL_IGNORE_PATTERNS[@]}"; do
    FIND_EXCLUSIONS+=("-not" "-path" "./${pattern}*")
done

print_header

echo -e "\e[36mCurrent directory: \e[0m$(pwd)"
echo -e "\e[36mLooking for:\e[0m '$FIND'  →  \e[36mReplacing with:\e[0m '$REPLACE'"

# Show ignore patterns with sources
if [[ ${#ALL_IGNORE_PATTERNS[@]} -gt 0 ]]; then
    echo -e "\e[36mIgnore patterns:\e[0m"
    if [[ ${#DEFAULT_IGNORE_PATTERNS[@]} -gt 0 ]]; then
        echo -e "  \e[90mDefaults:\e[0m ${DEFAULT_IGNORE_PATTERNS[*]}"
    fi
    if [[ ${#FILE_IGNORE_PATTERNS[@]} -gt 0 ]]; then
        echo -e "  \e[90mFrom .renamerignore:\e[0m ${FILE_IGNORE_PATTERNS[*]}"
    fi
    if [[ ${#IGNORE_PATTERNS[@]} -gt 0 ]]; then
        echo -e "  \e[90mFrom --ignore flags:\e[0m ${IGNORE_PATTERNS[*]}"
    fi
fi
echo

# Preview matches
echo -e "\e[33mSample matching file names:\e[0m"
find . -type f "${FIND_EXCLUSIONS[@]}" -name "*$FIND*" | head -n 5

echo -e "\n\e[33mSample matching folder names:\e[0m"
find . -type d "${FIND_EXCLUSIONS[@]}" -name "*$FIND*" | head -n 5


if [[ $SKIP_CONTENTS -eq 0 ]]; then
    echo -e "\n\e[33mSample file content matches:\e[0m"
    # Use find to get files that don't match ignore patterns, then grep those
    find . -type f "${FIND_EXCLUSIONS[@]}" -exec grep -l "$FIND" {} \; | head -n 5
else
    echo -e "\n\e[33mSkipping file content preview (--skip-contents)\e[0m"
fi

echo
read -p "Proceed with find-and-replace? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "\n\e[31mCancelled.\e[0m"; exit 0; }


if [[ $SKIP_CONTENTS -eq 0 ]]; then
    echo -e "\n\e[32mReplacing contents...\e[0m"
    # Replace in file contents, respecting ignore patterns
    find . -type f "${FIND_EXCLUSIONS[@]}" -exec grep -l "$FIND" {} \; | xargs -r sed -i "s/$FIND/$REPLACE/g"
else
    echo -e "\n\e[32mSkipping file content replacement (--skip-contents)\e[0m"
fi

echo -e "\n\e[32mRenaming directories...\e[0m"
# Rename directories first (depth-first to avoid path issues)
find . -depth -type d "${FIND_EXCLUSIONS[@]}" -name "*$FIND*" | while read dir; do
    newdir="${dir//$FIND/$REPLACE}"
    if [[ "$dir" != "$newdir" && ! -e "$newdir" ]]; then
        mv "$dir" "$newdir"
    fi
done

echo -e "\n\e[32mRenaming files...\e[0m"
# Rename files after folders are renamed
find . -type f "${FIND_EXCLUSIONS[@]}" -name "*$FIND*" | while read file; do
    newfile="${file//$FIND/$REPLACE}"
    if [[ "$file" != "$newfile" && ! -e "$newfile" ]]; then
        mv "$file" "$newfile"
    fi
done

echo -e "\n\e[1;32m🎉 Done.\e[0m"
