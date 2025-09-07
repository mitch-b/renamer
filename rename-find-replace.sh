#!/bin/bash

###############################################################################
# UI / LOGGING UTILITIES
###############################################################################

# Initialize color + symbol palette (auto–disable on non‑TTY or NO_COLOR)
init_ui() {
    if [[ -t 1 && -z "$NO_COLOR" ]]; then
        # Prefer tput if available for broader term compatibility
        if command -v tput >/dev/null 2>&1; then
            local bold=$(tput bold 2>/dev/null || true)
            local reset=$(tput sgr0 2>/dev/null || true)
            local dim="\e[2m"
            BOLD="$bold"; RESET="$reset"; DIM="$dim"
            FG_CYAN="\e[36m"; FG_MAGENTA="\e[35m"; FG_BLUE="\e[34m"; FG_GREEN="\e[32m"; FG_YELLOW="\e[33m"; FG_RED="\e[31m"; FG_GREY="\e[90m"
        else
            BOLD="\e[1m"; RESET="\e[0m"; DIM="\e[2m"
            FG_CYAN="\e[36m"; FG_MAGENTA="\e[35m"; FG_BLUE="\e[34m"; FG_GREEN="\e[32m"; FG_YELLOW="\e[33m"; FG_RED="\e[31m"; FG_GREY="\e[90m"
        fi
    else
        BOLD=""; RESET=""; DIM=""; FG_CYAN=""; FG_MAGENTA=""; FG_BLUE=""; FG_GREEN=""; FG_YELLOW=""; FG_RED=""; FG_GREY=""
    fi

    # Unicode / Emoji fallback (avoid if NO_UNICODE or non‑UTF locale)
    if [[ -n "$NO_UNICODE" || "${LC_ALL}${LC_CTYPE}${LANG}" != *"UTF"* ]]; then
        SYM_INFO="i"; SYM_WARN="!"; SYM_ERR="x"; SYM_OK="*"; SYM_RIGHT="->"; SYM_ELLIPSIS="..."; SYM_FINDREP="F/R"
    else
        SYM_INFO="ℹ"; SYM_WARN="⚠"; SYM_ERR="✖"; SYM_OK="✔"; SYM_RIGHT="→"; SYM_ELLIPSIS="…"; SYM_FINDREP="🔁"
    fi
}

log_raw() { printf '%b\n' "$*"; }
log_info() { log_raw "${FG_CYAN}${SYM_INFO}${RESET}  $*"; }
log_step() { log_raw "${FG_BLUE}${BOLD}›${RESET} $*"; }
log_warn() { log_raw "${FG_YELLOW}${SYM_WARN}${RESET} $*"; }
log_error() { log_raw "${FG_RED}${SYM_ERR}${RESET}  $*"; }
log_success() { log_raw "${FG_GREEN}${SYM_OK}${RESET}  $*"; }
log_dim() { log_raw "${DIM}$*${RESET}"; }
log_section() {
    local title="$1"; shift || true
    local line_char="─"; [[ -n "$NO_UNICODE" ]] && line_char="-"
    local cols=${COLUMNS:-80}
    local pad_line=""; while (( ${#pad_line} < cols )); do pad_line+="$line_char"; done
    log_raw "${FG_GREY}${pad_line:0:$cols}${RESET}";
    log_raw "${BOLD}${FG_MAGENTA}$title${RESET}"
}

print_header() {
    local cols=${COLUMNS:-80}
    local title="Renamer • Find & Replace Utility"
    local subtitle="Recursively renames files, folders & inline content"
    local line_char="─"; [[ -n "$NO_UNICODE" ]] && line_char="-"
    local pad_line=""; while (( ${#pad_line} < cols )); do pad_line+="$line_char"; done
    log_raw "${FG_MAGENTA}${pad_line:0:$cols}${RESET}"
    log_raw "${BOLD}${FG_MAGENTA}${SYM_FINDREP}  $title${RESET}"
    log_raw "${DIM}$subtitle${RESET}"
    log_raw "${FG_MAGENTA}${pad_line:0:$cols}${RESET}"
}

# Call initializer ASAP
init_ui


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
    
    # Automatically add .renamerignore to patterns to prevent it from being modified
    patterns+=(".renamerignore")
    
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
            exclusions+=("-path" "*/${dir_name}/*")
            exclusions+=("-o" "-path" "*/${dir_name}")
            exclusions+=("-o" "-path" "./${dir_name}/*")
            exclusions+=("-o" "-path" "./${dir_name}")
        # Handle simple patterns
        else
            # Match exact name anywhere in tree (like gitignore)
            exclusions+=("-path" "*/${pattern}")
            exclusions+=("-o" "-path" "./${pattern}")
            exclusions+=("-o" "-path" "*/${pattern}/*")
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
DRY_RUN=0
PROCESS_BINARY=0  # 0 = skip binary (default), 1 = include
IGNORE_PATTERNS=()
INCLUDE_PATTERNS=()
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|--dryrun|-n)
            DRY_RUN=1
            shift
            ;;
        --skip-contents)
            SKIP_CONTENTS=1
            shift
            ;;
        --include-binary|--no-skip-binary)
            PROCESS_BINARY=1
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
    echo "  -n, --dry-run         Show ALL planned changes (no modifications)"
    echo "  --skip-contents       Skip replacing text inside files"
    echo "  --include-binary      Process binary files (off by default)"
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

log_info "Current directory: $(pwd)"
log_info "Find: '${BOLD}$FIND${RESET}' ${SYM_RIGHT} Replace: '${BOLD}$REPLACE${RESET}'"

# Show ignore patterns with sources
if [[ ${#FINAL_IGNORE_PATTERNS[@]} -gt 0 ]]; then
    log_section "Active ignore patterns"
    if [[ ${#FILE_IGNORE_PATTERNS[@]} -gt 0 ]]; then
        log_dim "  From .renamerignore files: ${FILE_IGNORE_PATTERNS[*]}"
        for file in "${IGNORE_FILES_FOUND[@]}"; do
            log_dim "    ${SYM_RIGHT} $file"
        done
    fi
    if [[ ${#IGNORE_PATTERNS[@]} -gt 0 ]]; then
        log_dim "  From --ignore flags: ${IGNORE_PATTERNS[*]}"
    fi
    if [[ ${#INCLUDE_PATTERNS[@]} -gt 0 ]]; then
        log_dim "  Forced includes (override ignores): ${INCLUDE_PATTERNS[*]}"
    fi
    if [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
        log_dim "  Negation patterns found: processed internally"
    fi
else
    log_info "No ignore patterns active"
fi
echo

# Helper function to safely get limited results without SIGPIPE
get_limited_matches() {
    local limit="$1"
    local type="$2"
    local pattern="$3"
    local counter=0
    
    local GREP_CMD=(grep -l "$pattern")
    # Use -I to ignore binary matches when skipping binary
    if [[ $PROCESS_BINARY -eq 0 ]]; then
        GREP_CMD=(grep -Il "$pattern")
    fi
    if [[ ${#FIND_EXCLUSIONS[@]} -eq 0 && ${#NEGATION_CONDITIONS[@]} -eq 0 ]]; then
        # No exclusions at all
        if [[ "$type" == "content" ]]; then
            find . -type f -exec "${GREP_CMD[@]}" {} \; 2>/dev/null | while read -r line; do
                echo "$line"; ((counter++)); [[ $counter -ge $limit ]] && break
            done
        else
            find . -type "$type" -name "*$pattern*" | head -n "$limit"
        fi
    elif [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
        # Use exclusions with negation includes
        if [[ "$type" == "content" ]]; then
            find . -type f \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -exec "${GREP_CMD[@]}" {} \; 2>/dev/null | while read -r line; do
                echo "$line"; ((counter++)); [[ $counter -ge $limit ]] && break
            done
        else
            find . -type "$type" \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -name "*$pattern*" | head -n "$limit"
        fi
    else
        # Only exclusions (no negations)
        if [[ "$type" == "content" ]]; then
            find . -type f "${FIND_EXCLUSIONS[@]}" -exec "${GREP_CMD[@]}" {} \; 2>/dev/null | while read -r line; do
                echo "$line"; ((counter++)); [[ $counter -ge $limit ]] && break
            done
        else
            find . -type "$type" "${FIND_EXCLUSIONS[@]}" -name "*$pattern*" | head -n "$limit"
        fi
    fi
}

# Preview matches
log_section "Sample matching file names"
get_limited_matches 5 "f" "$FIND"

echo
log_section "Sample matching folder names"
get_limited_matches 5 "d" "$FIND"

if [[ $SKIP_CONTENTS -eq 0 ]]; then
    echo
    log_section "Sample file content matches"
    get_limited_matches 5 "content" "$FIND"
else
    echo
    log_warn "Skipping file content preview (--skip-contents)"
fi

echo
if [[ $DRY_RUN -eq 0 ]]; then
    read -p "Proceed with find & replace? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { log_warn "Cancelled."; exit 0; }
else
    log_warn "Dry run mode: NO changes will be made"
fi


CONTENT_REPLACED_COUNT=0
DIR_RENAMED_COUNT=0
FILE_RENAMED_COUNT=0

# Dry-run accumulators
DRY_CONTENT_FILES=()
DRY_DIRS=()
DRY_FILES=()

if [[ $SKIP_CONTENTS -eq 0 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        log_step "Scanning content (text files only)"
    else
        log_step "Replacing contents"
    fi
    # Replace in file contents, respecting ignore patterns
    local GREP_CONTENT=(grep -l "$FIND"); [[ $PROCESS_BINARY -eq 0 ]] && GREP_CONTENT=(grep -Il "$FIND")
    if [[ ${#FIND_EXCLUSIONS[@]} -eq 0 && ${#NEGATION_CONDITIONS[@]} -eq 0 ]]; then
        while IFS= read -r f; do
            if [[ $DRY_RUN -eq 1 ]]; then DRY_CONTENT_FILES+=("$f"); else sed -i "s/$FIND/$REPLACE/g" "$f" && ((CONTENT_REPLACED_COUNT++)); fi
        done < <(find . -type f -exec "${GREP_CONTENT[@]}" {} \; 2>/dev/null)
    elif [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
        while IFS= read -r f; do
            if [[ $DRY_RUN -eq 1 ]]; then DRY_CONTENT_FILES+=("$f"); else sed -i "s/$FIND/$REPLACE/g" "$f" && ((CONTENT_REPLACED_COUNT++)); fi
        done < <(find . -type f \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -exec "${GREP_CONTENT[@]}" {} \; 2>/dev/null)
    else
        while IFS= read -r f; do
            if [[ $DRY_RUN -eq 1 ]]; then DRY_CONTENT_FILES+=("$f"); else sed -i "s/$FIND/$REPLACE/g" "$f" && ((CONTENT_REPLACED_COUNT++)); fi
        done < <(find . -type f "${FIND_EXCLUSIONS[@]}" -exec "${GREP_CONTENT[@]}" {} \; 2>/dev/null)
    fi
else
    log_warn "Skipping file content replacement (--skip-contents)"
fi

log_step "Renaming directories"
# Rename directories first (depth-first to avoid path issues)
if [[ ${#FIND_EXCLUSIONS[@]} -eq 0 && ${#NEGATION_CONDITIONS[@]} -eq 0 ]]; then
    # No exclusions at all - simple find
    find . -depth -type d -name "*$FIND*" | while read dir; do
        newdir="${dir//$FIND/$REPLACE}"
        if [[ "$dir" != "$newdir" && ! -e "$newdir" ]]; then
            if [[ $DRY_RUN -eq 1 ]]; then
                DRY_DIRS+=("$dir -> $newdir")
            else
                mv "$dir" "$newdir" && ((DIR_RENAMED_COUNT++))
            fi
        fi
    done
elif [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
    # With negation conditions: (exclusions) OR (negations)
    find . -depth -type d \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -name "*$FIND*" | while read dir; do
        newdir="${dir//$FIND/$REPLACE}"
        if [[ "$dir" != "$newdir" && ! -e "$newdir" ]]; then
            if [[ $DRY_RUN -eq 1 ]]; then
                DRY_DIRS+=("$dir -> $newdir")
            else
                mv "$dir" "$newdir" && ((DIR_RENAMED_COUNT++))
            fi
        fi
    done
else
    # Without negation conditions: just exclusions
    find . -depth -type d "${FIND_EXCLUSIONS[@]}" -name "*$FIND*" | while read dir; do
        newdir="${dir//$FIND/$REPLACE}"
        if [[ "$dir" != "$newdir" && ! -e "$newdir" ]]; then
            if [[ $DRY_RUN -eq 1 ]]; then
                DRY_DIRS+=("$dir -> $newdir")
            else
                mv "$dir" "$newdir" && ((DIR_RENAMED_COUNT++))
            fi
        fi
    done
fi

log_step "Renaming files"
# Rename files after folders are renamed
if [[ ${#FIND_EXCLUSIONS[@]} -eq 0 && ${#NEGATION_CONDITIONS[@]} -eq 0 ]]; then
    # No exclusions at all - simple find
    find . -type f -name "*$FIND*" | while read file; do
        newfile="${file//$FIND/$REPLACE}"
        if [[ "$file" != "$newfile" && ! -e "$newfile" ]]; then
            if [[ $DRY_RUN -eq 1 ]]; then
                DRY_FILES+=("$file -> $newfile")
            else
                mv "$file" "$newfile" && ((FILE_RENAMED_COUNT++))
            fi
        fi
    done
elif [[ ${#NEGATION_CONDITIONS[@]} -gt 0 ]]; then
    # With negation conditions: (exclusions) OR (negations)
    find . -type f \( "${FIND_EXCLUSIONS[@]}" -o "${NEGATION_CONDITIONS[@]}" \) -name "*$FIND*" | while read file; do
        newfile="${file//$FIND/$REPLACE}"
        if [[ "$file" != "$newfile" && ! -e "$newfile" ]]; then
            if [[ $DRY_RUN -eq 1 ]]; then
                DRY_FILES+=("$file -> $newfile")
            else
                mv "$file" "$newfile" && ((FILE_RENAMED_COUNT++))
            fi
        fi
    done
else
    # Without negation conditions: just exclusions
    find . -type f "${FIND_EXCLUSIONS[@]}" -name "*$FIND*" | while read file; do
        newfile="${file//$FIND/$REPLACE}"
        if [[ "$file" != "$newfile" && ! -e "$newfile" ]]; then
            if [[ $DRY_RUN -eq 1 ]]; then
                DRY_FILES+=("$file -> $newfile")
            else
                mv "$file" "$newfile" && ((FILE_RENAMED_COUNT++))
            fi
        fi
    done
fi

echo
log_section "Summary"
if [[ $DRY_RUN -eq 1 ]]; then
    if [[ $SKIP_CONTENTS -eq 0 ]]; then
        log_info "Content replacement candidates: ${#DRY_CONTENT_FILES[@]}"
    else
        log_dim "(Content scanning skipped)"
    fi
    log_info "Directory rename candidates: ${#DRY_DIRS[@]}"
    log_info "File rename candidates:     ${#DRY_FILES[@]}"

    if [[ $SKIP_CONTENTS -eq 0 && ${#DRY_CONTENT_FILES[@]} -gt 0 ]]; then
        log_section "Files with matching content"
        for f in "${DRY_CONTENT_FILES[@]}"; do log_raw "  $f"; done
    fi
    if [[ ${#DRY_DIRS[@]} -gt 0 ]]; then
        log_section "Directory rename plan"
        for d in "${DRY_DIRS[@]}"; do log_raw "  $d"; done
    fi
    if [[ ${#DRY_FILES[@]} -gt 0 ]]; then
        log_section "File rename plan"
        for f in "${DRY_FILES[@]}"; do log_raw "  $f"; done
    fi
    log_success "Dry run complete"
else
    if [[ $SKIP_CONTENTS -eq 0 ]]; then
        log_info "Files with content replaced: ${CONTENT_REPLACED_COUNT}"
    else
        log_dim "(Content replacement skipped)"
    fi
    log_info "Directories renamed: ${DIR_RENAMED_COUNT}"
    log_info "Files renamed:       ${FILE_RENAMED_COUNT}"

    if (( DIR_RENAMED_COUNT + FILE_RENAMED_COUNT + CONTENT_REPLACED_COUNT > 0 )); then
        log_success "Done"
    else
        log_warn "No changes applied"
    fi
fi
