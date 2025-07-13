# renamer 🔀

**Quick Start**

```bash
# bash
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText
```

```powershell
# powerShell
docker run --rm -it -v "${PWD}:/data" ghcr.io/mitch-b/renamer oldText newText
```

**With ignore patterns:**

```bash
# Ignore node_modules and dist directories
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --ignore node_modules --ignore dist
```

- Replace all `oldText` with `newText` in file/folder names and file contents, recursively.
- `-v "$PWD:/data"` mounts your current directory to `/data` in the container.
- `.git/` directories are automatically ignored to protect version control.

---

## Requirements
- Container runtime installed

---

## Features
- **Recursively renames** files and folders matching a search string
- **Replaces text** inside all files
- **Smart ignore patterns**: Automatically ignores `.git/` directories and supports custom ignore patterns
- **Preview**: Shows sample matches before making changes
- **Interactive**: Asks for confirmation before proceeding

---

## Command Line Options

```bash
rename-find-replace.sh <find> <replace> [--skip-contents] [--ignore <pattern>]...
```

**Options:**
- `--skip-contents`: Skip replacing text inside files (only rename files and folders)
- `--ignore <pattern>`: Ignore paths matching pattern (can be used multiple times)

**Default ignore patterns:** `.git/`

**Examples:**
```bash
# Basic usage
./rename-find-replace.sh oldText newText

# Skip file content replacement
./rename-find-replace.sh oldText newText --skip-contents

# Ignore node_modules and dist directories
./rename-find-replace.sh oldText newText --ignore node_modules --ignore dist

# Combine options
./rename-find-replace.sh oldText newText --skip-contents --ignore build --ignore temp
```

---

## How it Works
1. **Preview**: Shows up to 5 sample matches for files, folders, and file contents
2. **Confirm**: Prompts before making changes
3. **Replace**: Updates file contents, then renames folders and files

---

## Build Docker Image (optional)

```bash
 docker build -t mitch-b/renamer .
```

---

## Warnings & Tips
- **Backup your data!** This script makes bulk changes.
- **Test on a copy** before running on important data.
- **Case-sensitive**: The search is case-sensitive.
- **No undo**: Changes are immediate and cannot be undone automatically.
- **Special characters**: If your search/replace strings contain special characters, test carefully.

---

## License
MIT

---

## Issues / Feedback
Open an issue or PR on GitHub if you have suggestions or problems.
