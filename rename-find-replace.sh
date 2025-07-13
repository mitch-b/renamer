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


# Function to read ignore patterns from .renamerignore files
read_ignore_files() {
    local patterns=()
    local files_found=()
    
    # Define potential .renamerignore file locations in priority order
    local ignore_files=(
        ".renamerignore"                           # Current directory (project-specific)
    )
    
    # Add custom file from environment variable (defaults to /.renamerignore for easy Docker mounting)
    RENAMER_IGNORE_FILE="${RENAMER_IGNORE_FILE:-/.renamerignore}"
    if [[ -f "$RENAMER_IGNORE_FILE" ]]; then
        ignore_files+=("$RENAMER_IGNORE_FILE")
    fi
    
    # Read from all existing files
    for ignore_file in "${ignore_files[@]}"; do
        if [[ -f "$ignore_file" ]]; then
            files_found+=("$ignore_file")
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
    done
    
    # Output format: "patterns|files_found"
    printf "%s|%s" "${patterns[*]}" "${files_found[*]}"
}

# Parse arguments: positional for find/replace, optional flags
SKIP_CONTENTS=0
IGNORE_PATTERNS=()
INCLUDE_PATTERNS=()
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
        --include)
            if [[ -n "$2" && "$2" != --* ]]; then
                # Support comma-separated patterns
                IFS=',' read -ra PATTERNS <<< "$2"
                for pattern in "${PATTERNS[@]}"; do
                    # Trim whitespace
                    pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ -n "$pattern" ]]; then
                        INCLUDE_PATTERNS+=("$pattern")
                    fi
                done
                shift 2
            else
                echo "Error: --include requires a pattern argument"
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
    echo "🐳 Renamer - Docker-based find & replace tool"
    echo ""
    echo "Usage: docker run --rm -it -v \"\$PWD:/data\" ghcr.io/mitch-b/renamer <find> <replace> [options...]"
    echo ""
    echo "Options:"
    echo "  --skip-contents       Skip replacing text inside files"
    echo "  --ignore <pattern>    Ignore patterns (comma-separated or multiple flags)"
    echo "  --include <pattern>   Force include patterns (overrides ignores)"
    echo ""
    echo "Examples:"
    echo "  docker run --rm -it -v \"\$PWD:/data\" ghcr.io/mitch-b/renamer oldText newText"
    echo "  docker run --rm -it -v \"\$PWD:/data\" -v \"/path/to/.renamerignore:/.renamerignore\" ghcr.io/mitch-b/renamer oldText newText"
    echo "  docker run --rm -it -v \"\$PWD:/data\" ghcr.io/mitch-b/renamer oldText newText --ignore \"dist,build\""
    exit 1
fi
FIND="$1"
REPLACE="$2"

# Read patterns from .renamerignore files
ignore_file_result=$(read_ignore_files)
IFS='|' read -ra ignore_file_parts <<< "$ignore_file_result"
FILE_IGNORE_PATTERNS=(${ignore_file_parts[0]})
IGNORE_FILES_FOUND=(${ignore_file_parts[1]})

# Combine ignore patterns: file + command line
ALL_IGNORE_PATTERNS=("${FILE_IGNORE_PATTERNS[@]}" "${IGNORE_PATTERNS[@]}")

# Remove patterns that are explicitly included
FINAL_IGNORE_PATTERNS=()
for ignore_pattern in "${ALL_IGNORE_PATTERNS[@]}"; do
    should_ignore=1
    for include_pattern in "${INCLUDE_PATTERNS[@]}"; do
        # Simple pattern matching - if include pattern matches ignore pattern, don't ignore it
        if [[ "$ignore_pattern" == "$include_pattern" || "$ignore_pattern" == "${include_pattern%/}" || "${ignore_pattern%/}" == "$include_pattern" ]]; then
            should_ignore=0
            break
        fi
    done
    if [[ $should_ignore -eq 1 ]]; then
        FINAL_IGNORE_PATTERNS+=("$ignore_pattern")
    fi
done

# Build find exclusions array
FIND_EXCLUSIONS=()
for pattern in "${FINAL_IGNORE_PATTERNS[@]}"; do
    FIND_EXCLUSIONS+=("-not" "-path" "./${pattern}*")
done

print_header

echo -e "\e[36mCurrent directory: \e[0m$(pwd)"
echo -e "\e[36mLooking for:\e[0m '$FIND'  →  \e[36mReplacing with:\e[0m '$REPLACE'"

# Show ignore patterns with sources
if [[ ${#FINAL_IGNORE_PATTERNS[@]} -gt 0 ]]; then
    echo -e "\e[36mActive ignore patterns:\e[0m"
    if [[ ${#FILE_IGNORE_PATTERNS[@]} -gt 0 ]]; then
        echo -e "  \e[90mFrom .renamerignore files:\e[0m ${FILE_IGNORE_PATTERNS[*]}"
        for file in "${IGNORE_FILES_FOUND[@]}"; do
            echo -e "    \e[90m→ $file\e[0m"
        done
    fi
    if [[ ${#IGNORE_PATTERNS[@]} -gt 0 ]]; then
        echo -e "  \e[90mFrom --ignore flags:\e[0m ${IGNORE_PATTERNS[*]}"
    fi
    if [[ ${#INCLUDE_PATTERNS[@]} -gt 0 ]]; then
        echo -e "  \e[90mForced includes (override ignores):\e[0m ${INCLUDE_PATTERNS[*]}"
    fi
else
    echo -e "\e[36mNo ignore patterns active\e[0m"
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
