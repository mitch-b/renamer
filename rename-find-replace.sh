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


# Parse arguments: positional for find/replace, optional --skip-contents
SKIP_CONTENTS=0
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-contents)
            SKIP_CONTENTS=1
            shift
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done
set -- "${POSITIONAL[@]}"

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <find> <replace> [--skip-contents]"
    exit 1
fi
FIND="$1"
REPLACE="$2"

print_header

echo -e "\e[36mCurrent directory: \e[0m$(pwd)"
echo -e "\e[36mLooking for:\e[0m '$FIND'  →  \e[36mReplacing with:\e[0m '$REPLACE'"
echo

# Preview matches
echo -e "\e[33mSample matching file names:\e[0m"
find . -type f -name "*$FIND*" | head -n 5

echo -e "\n\e[33mSample matching folder names:\e[0m"
find . -type d -name "*$FIND*" | head -n 5


if [[ $SKIP_CONTENTS -eq 0 ]]; then
    echo -e "\n\e[33mSample file content matches:\e[0m"
    grep -rl "$FIND" . | head -n 5
else
    echo -e "\n\e[33mSkipping file content preview (--skip-contents)\e[0m"
fi

echo
read -p "Proceed with find-and-replace? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "\n\e[31mCancelled.\e[0m"; exit 0; }


if [[ $SKIP_CONTENTS -eq 0 ]]; then
    echo -e "\n\e[32mReplacing contents...\e[0m"
    # Replace in file contents
    grep -rl "$FIND" . | xargs sed -i "s/$FIND/$REPLACE/g"
else
    echo -e "\n\e[32mSkipping file content replacement (--skip-contents)\e[0m"
fi

echo -e "\n\e[32mRenaming directories...\e[0m"
# Rename directories first (depth-first to avoid path issues)
find . -depth -type d -name "*$FIND*" | while read dir; do
    newdir="${dir//$FIND/$REPLACE}"
    if [[ "$dir" != "$newdir" && ! -e "$newdir" ]]; then
        mv "$dir" "$newdir"
    fi
done

echo -e "\n\e[32mRenaming files...\e[0m"
# Rename files after folders are renamed
find . -type f -name "*$FIND*" | while read file; do
    newfile="${file//$FIND/$REPLACE}"
    if [[ "$file" != "$newfile" && ! -e "$newfile" ]]; then
        mv "$file" "$newfile"
    fi
done

echo -e "\n\e[1;32m🎉 Done.\e[0m"
