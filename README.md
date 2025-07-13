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
# Using comma-separated patterns (new, less verbose!)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --ignore "dist,build,logs"

# Using multiple flags (still supported)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --ignore node_modules --ignore dist

# Using .renamerignore file (best for projects with consistent patterns)
# Create .renamerignore in your project, then run:
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText

# Override defaults to include .git or node_modules
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --include .git

# Disable all defaults and use only custom patterns
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --no-defaults --ignore temp

# Use custom ignore file from mounted volume
docker run --rm -it -v "$PWD:/data" -v "/path/to/my-patterns.txt:/ignore.txt" -e RENAMER_IGNORE_FILE=/ignore.txt ghcr.io/mitch-b/renamer oldText newText
```

- Replace all `oldText` with `newText` in file/folder names and file contents, recursively.
- `-v "$PWD:/data"` mounts your current directory to `/data` in the container.
- `.git/` and `node_modules/` directories are automatically ignored to protect version control and dependencies.
- Support for flexible `.renamerignore` files for project-specific patterns and custom mounted ignore files.
- Override capabilities for power users who need to edit typically protected directories.

---

## Requirements
- Container runtime installed

---

## Features
- **Recursively renames** files and folders matching a search string
- **Replaces text** inside all files
- **Smart ignore patterns**: Automatically ignores `.git/` and `node_modules/` directories, supports `.renamerignore` files, and custom ignore patterns
- **Preview**: Shows sample matches before making changes
- **Interactive**: Asks for confirmation before proceeding

---

## Command Line Options

```bash
rename-find-replace.sh <find> <replace> [options...]
```

**Options:**
- `--skip-contents`: Skip replacing text inside files (only rename files and folders)
- `--ignore <pattern>`: Ignore paths matching pattern(s)
  - Supports comma-separated: `--ignore "build,dist,temp"`
  - Can be used multiple times: `--ignore build --ignore dist`
- `--include <pattern>`: Force include patterns even if ignored elsewhere
  - Useful to override defaults: `--include .git`
- `--no-defaults`: Disable built-in default ignore patterns

**Ignore pattern sources (applied in order):**
1. **Built-in defaults**: `.git/`, `node_modules/` (unless `--no-defaults`)
2. **`.renamerignore` files**:
   - `./renamerignore` (current directory/project-specific)
   - `$RENAMER_IGNORE_FILE` (custom mounted file path)
3. **`--ignore` flags**: Command-line additional patterns
4. **`--include` flags**: Override any ignores for specific patterns

**Examples:**
```bash
# Basic usage (uses built-in defaults)
./rename-find-replace.sh oldText newText

# Skip file content replacement
./rename-find-replace.sh oldText newText --skip-contents

# Add patterns via comma-separated list (less verbose!)
./rename-find-replace.sh oldText newText --ignore "dist,build,logs"

# Add patterns via multiple flags (still supported)
./rename-find-replace.sh oldText newText --ignore node_modules --ignore dist

# Include .git directory (override default)
./rename-find-replace.sh oldText newText --include .git

# Disable all defaults and only ignore specific patterns
./rename-find-replace.sh oldText newText --no-defaults --ignore node_modules

# Use custom global ignore file
RENAMER_IGNORE_FILE=/path/to/my-patterns ./rename-find-replace.sh oldText newText

# Combine options
./rename-find-replace.sh oldText newText --skip-contents --ignore "temp,cache"
```

## Docker Usage with Ignore Files

**Project-specific (.renamerignore in current directory):**
```bash
# Create .renamerignore in your project root
echo "dist" >> .renamerignore
echo "build" >> .renamerignore
echo "*.log" >> .renamerignore

# Mount your project directory (includes .renamerignore automatically)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText
```

**Custom mounted ignore file:**
```bash
# Create patterns file on your host
echo "custom_temp" > /path/to/my-global-patterns.txt
echo "build" >> /path/to/my-global-patterns.txt

# Mount the file and reference it via environment variable
docker run --rm -it \
  -v "$PWD:/data" \
  -v "/path/to/my-global-patterns.txt:/ignore.txt" \
  -e RENAMER_IGNORE_FILE=/ignore.txt \
  ghcr.io/mitch-b/renamer oldText newText
```

**Advanced Docker usage:**
```bash
# Combine project .renamerignore with custom patterns
# (project patterns take priority, custom patterns add to them)
docker run --rm -it \
  -v "$PWD:/data" \
  -v "$HOME/.config/renamer-patterns.txt:/global-ignore.txt" \
  -e RENAMER_IGNORE_FILE=/global-ignore.txt \
  ghcr.io/mitch-b/renamer oldText newText --ignore "temp,cache"
```

**Using .renamerignore files (Local Development):**

*Project-specific (.renamerignore in current directory):*
```bash
# Create .renamerignore in your project root
echo "dist" >> .renamerignore
echo "build" >> .renamerignore
echo "*.log" >> .renamerignore

# Then run without --ignore flags
./rename-find-replace.sh oldText newText
```

*Custom location (via environment variable):*
```bash
# Create patterns file anywhere
echo "custom_temp" > /path/to/my-patterns

# Use it via environment variable  
RENAMER_IGNORE_FILE=/path/to/my-patterns ./rename-find-replace.sh oldText newText
```

See `.renamerignore.example` for a comprehensive example file.

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
