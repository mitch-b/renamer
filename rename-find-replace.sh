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

# Function to parse gitignore-style patterns and build find exclusions
build_find_exclusions() {
    local patterns=("$@")
    local exclusions=()
    local negation_patterns=()
    
    # First pass: collect non-negation patterns
    for pattern in "${patterns[@]}"; do
        # Skip negation patterns for now
        if [[ "$pattern" =~ ^! ]]; then
            # Store negation patterns for second pass
            negation_patterns+=("${pattern#!}")
            continue
        fi
        
        # Handle recursive directory patterns (**/dir/)
        if [[ "$pattern" =~ ^\*\*/.*/$ ]]; then
            # Remove **/ prefix and trailing /
            local dir_name="${pattern#**/}"
            dir_name="${dir_name%/}"
            exclusions+=("-path" "*/${dir_name}/*")
            exclusions+=("-o" "-path" "*/${dir_name}")
        # Handle recursive file patterns (**/file)
        elif [[ "$pattern" =~ ^\*\*/ ]]; then
            # Remove **/ prefix
            local file_pattern="${pattern#**/}"
            exclusions+=("-path" "*/${file_pattern}")
        # Handle directory-only patterns (dir/)
        elif [[ "$pattern" =~ /$ ]]; then
            # Remove trailing /
            local dir_name="${pattern%/}"
            exclusions+=("-path" "./${dir_name}/*")
            exclusions+=("-o" "-path" "./${dir_name}")
        # Handle simple patterns
        else
            exclusions+=("-path" "./${pattern}*")
        fi
        
        # Add -o connector if this isn't the last exclusion and we have more patterns to process
        if [[ ${#exclusions[@]} -gt 0 ]]; then
            exclusions+=("-o")
        fi
    done
    
    # Remove trailing -o if it exists
    if [[ ${#exclusions[@]} -gt 0 && "${exclusions[-1]}" == "-o" ]]; then
        unset 'exclusions[-1]'
    fi
    
    # Second pass: handle negation patterns by creating include conditions  
    local include_conditions=()
    for neg_pattern in "${negation_patterns[@]}"; do
        # Handle recursive file patterns in negations (**/file)
        if [[ "$neg_pattern" =~ ^\*\*/ ]]; then
            # Remove **/ prefix
            local file_pattern="${neg_pattern#**/}"
            include_conditions+=("-path" "*/${file_pattern}")
        # Handle directory-only patterns in negations (dir/)
        elif [[ "$neg_pattern" =~ /$ ]]; then
            # Remove trailing /
            local dir_name="${neg_pattern%/}"
            include_conditions+=("-path" "./${dir_name}/*")
            include_conditions+=("-o" "-path" "./${dir_name}")
        # Handle simple patterns in negations
        else
            include_conditions+=("-path" "./${neg_pattern}*")
        fi
        
        # Add -o connector if this isn't the last condition and we have more negation patterns
        if [[ ${#include_conditions[@]} -gt 0 ]]; then
            include_conditions+=("-o")
        fi
    done
    
    # Remove trailing -o if it exists
    if [[ ${#include_conditions[@]} -gt 0 && "${include_conditions[-1]}" == "-o" ]]; then
        unset 'include_conditions[-1]'
    fi
    
    # Output format: if we have exclusions, wrap them in -not -( ... -), then add include conditions
    if [[ ${#exclusions[@]} -gt 0 ]]; then
        printf "%s\n" "-not" "-(" "${exclusions[@]}" "-)"
    fi
    
    # If we have negation patterns, output a separator and then include conditions
    if [[ ${#include_conditions[@]} -gt 0 ]]; then
        printf "NEGATION_SEPARATOR\n"
        printf "%s\n" "${include_conditions[@]}"
    fi
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
# Prevent globbing during array assignment by using proper quoting
IFS=' ' read -ra FILE_IGNORE_PATTERNS <<< "${ignore_file_parts[0]}"
IFS=' ' read -ra IGNORE_FILES_FOUND <<< "${ignore_file_parts[1]}"

# Combine ignore patterns: file + command line
ALL_IGNORE_PATTERNS=("${FILE_IGNORE_PATTERNS[@]}" "${IGNORE_PATTERNS[@]}")

# Remove patterns that are explicitly included using --include flag
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

# Build find exclusions using gitignore-style pattern parsing
FIND_EXCLUSIONS_OUTPUT=$(build_find_exclusions "${FINAL_IGNORE_PATTERNS[@]}")
FIND_EXCLUSIONS=()
NEGATION_CONDITIONS=()
reading_negations=false

while IFS= read -r line; do
    # Skip empty lines
    [[ -n "$line" ]] || continue
    
    if [[ "$line" == "NEGATION_SEPARATOR" ]]; then
        reading_negations=true
    elif [[ "$reading_negations" == true ]]; then
        NEGATION_CONDITIONS+=("$line")
    else
        FIND_EXCLUSIONS+=("$line")
    fi
done <<< "$FIND_EXCLUSIONS_OUTPUT"

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
    if [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
        echo -e "  \e[90mNegation patterns found:\e[0m Processed internally"
    fi
else
    echo -e "\e[36mNo ignore patterns active\e[0m"
fi
echo

# Helper function to safely get limited results without SIGPIPE
get_limited_matches() {
    local limit="$1"
    local type="$2"
    local pattern="$3"
    local counter=0
    
    if [[ ${#FIND_EXCLUSIONS[@]} -eq 0 && ${#NEGATION_CONDITIONS[@]} -eq 0 ]]; then
        # No exclusions at all - simple find
        if [[ "$type" == "content" ]]; then
            find . -type f -name "*" -exec grep -l "$pattern" {} \; 2>/dev/null | while read line; do
                echo "$line"
                ((counter++))
                [[ $counter -ge $limit ]] && break
            done
        else
            find . -type "$type" -name "*$pattern*" | head -n "$limit"
        fi
    elif [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
        # With negation conditions: (exclusions) OR (negations)  
        if [[ "$type" == "content" ]]; then
            find . -type f \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -exec grep -l "$pattern" {} \; 2>/dev/null | while read line; do
                echo "$line"
                ((counter++))
                [[ $counter -ge $limit ]] && break
            done
        else
            find . -type "$type" \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -name "*$pattern*" | head -n "$limit"
        fi
    else
        # Without negation conditions: just exclusions
        if [[ "$type" == "content" ]]; then
            find . -type f "${FIND_EXCLUSIONS[@]}" -exec grep -l "$pattern" {} \; 2>/dev/null | while read line; do
                echo "$line"
                ((counter++))
                [[ $counter -ge $limit ]] && break
            done
        else
            find . -type "$type" "${FIND_EXCLUSIONS[@]}" -name "*$pattern*" | head -n "$limit"
        fi
    fi
}

# Preview matches
echo -e "\e[33mSample matching file names:\e[0m"
get_limited_matches 5 "f" "$FIND"

echo -e "\n\e[33mSample matching folder names:\e[0m"
get_limited_matches 5 "d" "$FIND"

if [[ $SKIP_CONTENTS -eq 0 ]]; then
    echo -e "\n\e[33mSample file content matches:\e[0m"
    get_limited_matches 5 "content" "$FIND"
else
    echo -e "\n\e[33mSkipping file content preview (--skip-contents)\e[0m"
fi

echo
read -p "Proceed with find-and-replace? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "\n\e[31mCancelled.\e[0m"; exit 0; }


if [[ $SKIP_CONTENTS -eq 0 ]]; then
    echo -e "\n\e[32mReplacing contents...\e[0m"
    # Replace in file contents, respecting ignore patterns
    if [[ ${#FIND_EXCLUSIONS[@]} -eq 0 && ${#NEGATION_CONDITIONS[@]} -eq 0 ]]; then
        # No exclusions at all - simple find
        find . -type f -name "*" -exec grep -l "$FIND" {} \; 2>/dev/null | xargs -r sed -i "s/$FIND/$REPLACE/g"
    elif [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
        # With negation conditions: (exclusions) OR (negations)
        find . -type f \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -exec grep -l "$FIND" {} \; 2>/dev/null | xargs -r sed -i "s/$FIND/$REPLACE/g"
    else
        # Without negation conditions: just exclusions
        find . -type f "${FIND_EXCLUSIONS[@]}" -exec grep -l "$FIND" {} \; 2>/dev/null | xargs -r sed -i "s/$FIND/$REPLACE/g"
    fi
else
    echo -e "\n\e[32mSkipping file content replacement (--skip-contents)\e[0m"
fi

echo -e "\n\e[32mRenaming directories...\e[0m"
# Rename directories first (depth-first to avoid path issues)
if [[ ${#FIND_EXCLUSIONS[@]} -eq 0 && ${#NEGATION_CONDITIONS[@]} -eq 0 ]]; then
    # No exclusions at all - simple find
    find . -depth -type d -name "*$FIND*" | while read dir; do
        newdir="${dir//$FIND/$REPLACE}"
        if [[ "$dir" != "$newdir" && ! -e "$newdir" ]]; then
            mv "$dir" "$newdir"
        fi
    done
elif [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
    # With negation conditions: (exclusions) OR (negations)
    find . -depth -type d \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -name "*$FIND*" | while read dir; do
        newdir="${dir//$FIND/$REPLACE}"
        if [[ "$dir" != "$newdir" && ! -e "$newdir" ]]; then
            mv "$dir" "$newdir"
        fi
    done
else
    # Without negation conditions: just exclusions
    find . -depth -type d "${FIND_EXCLUSIONS[@]}" -name "*$FIND*" | while read dir; do
        newdir="${dir//$FIND/$REPLACE}"
        if [[ "$dir" != "$newdir" && ! -e "$newdir" ]]; then
            mv "$dir" "$newdir"
        fi
    done
fi

echo -e "\n\e[32mRenaming files...\e[0m"
# Rename files after folders are renamed
if [[ ${#FIND_EXCLUSIONS[@]} -eq 0 && ${#NEGATION_CONDITIONS[@]} -eq 0 ]]; then
    # No exclusions at all - simple find
    find . -type f -name "*$FIND*" | while read file; do
        newfile="${file//$FIND/$REPLACE}"
        if [[ "$file" != "$newfile" && ! -e "$newfile" ]]; then
            mv "$file" "$newfile"
        fi
    done
elif [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
    # With negation conditions: (exclusions) OR (negations)
    find . -type f \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -name "*$FIND*" | while read file; do
        newfile="${file//$FIND/$REPLACE}"
        if [[ "$file" != "$newfile" && ! -e "$newfile" ]]; then
            mv "$file" "$newfile"
        fi
    done
else
    # Without negation conditions: just exclusions
    find . -type f "${FIND_EXCLUSIONS[@]}" -name "*$FIND*" | while read file; do
        newfile="${file//$FIND/$REPLACE}"
        if [[ "$file" != "$newfile" && ! -e "$newfile" ]]; then
            mv "$file" "$newfile"
        fi
    done
fi

echo -e "\n\e[1;32m🎉 Done.\e[0m"
