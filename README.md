# renamer 🔀

**A portable Docker-based tool for bulk find-and-replace operations on files and directories.**

## Quick Start

```bash
# bash
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText
```

```powershell
# powerShell
docker run --rm -it -v "${PWD}:/data" ghcr.io/mitch-b/renamer oldText newText
```

## Docker Usage Examples

**Basic usage:**
```bash
# Replace all instances of 'oldText' with 'newText' in file/folder names and contents
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText
```

**With ignore patterns:**
```bash
# Using comma-separated patterns (recommended for multiple patterns)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --ignore "dist,build,logs"

# Using multiple flags (alternative syntax)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --ignore node_modules --ignore dist

# Skip file content replacement (only rename files/folders)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --skip-contents
```

**Using .renamerignore files:**
```bash
# Project-specific patterns (create .renamerignore in your project directory)
echo -e "dist\nbuild\n*.log" > .renamerignore
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText

# Mount custom ignore file (easy - no environment variable needed!)
docker run --rm -it \
  -v "$PWD:/data" \
  -v "/path/to/my-patterns.txt:/.renamerignore" \
  ghcr.io/mitch-b/renamer oldText newText

# Mount custom ignore file with custom path (advanced)
docker run --rm -it \
  -v "$PWD:/data" \
  -v "/path/to/my-patterns.txt:/custom.txt" \
  -e RENAMER_IGNORE_FILE=/custom.txt \
  ghcr.io/mitch-b/renamer oldText newText
```

**Power user options:**
```bash
# Override defaults to include normally protected directories
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --include .git

# Disable all defaults and use only custom patterns
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --no-defaults --ignore temp

# Combine multiple options
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --skip-contents --ignore "temp,cache" --include .git
```

**What it does:**
- Replaces all `oldText` with `newText` in file/folder names and file contents, recursively
- `-v "$PWD:/data"` mounts your current directory to `/data` in the container  
- `.git/` and `node_modules/` directories are automatically ignored to protect version control and dependencies
- Supports flexible `.renamerignore` files for project-specific patterns and custom mounted ignore files
- Provides override capabilities for power users who need to edit typically protected directories

---

## Requirements
- Docker or compatible container runtime

---

## Features
- **🐳 Docker-based portability**: Runs consistently across all platforms with container runtime
- **🔁 Recursively renames** files and folders matching a search string
- **📝 Replaces text** inside all files
- **🛡️ Smart ignore patterns**: Automatically ignores `.git/` and `node_modules/` directories, supports `.renamerignore` files, and custom ignore patterns
- **👀 Preview**: Shows sample matches before making changes
- **✋ Interactive**: Asks for confirmation before proceeding
- **🔧 Flexible configuration**: Easy volume mounting for ignore patterns and custom settings

---

## Command Line Options

```bash
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer <find> <replace> [options...]
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
   - `./renamerignore` (current directory/project-specific, mounted via `-v "$PWD:/data"`)
   - `$RENAMER_IGNORE_FILE` (defaults to `/.renamerignore`, customizable via environment variable)
3. **`--ignore` flags**: Command-line additional patterns
4. **`--include` flags**: Override any ignores for specific patterns

## Docker Usage Patterns

### Project-Specific Ignore Patterns
Create a `.renamerignore` file in your project directory:
```bash
# Create patterns file in your project
echo -e "dist\nbuild\n*.log\ntemp" > .renamerignore

# Run with your project mounted (automatically includes .renamerignore)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText
```

### Custom Global Ignore Patterns (Simple)
Mount your patterns file to the default location:
```bash
# Create global patterns file
echo -e "dist\nbuild\ncache\n*.tmp" > /path/to/global-patterns.txt

# Mount to default path - no environment variable needed!
docker run --rm -it \
  -v "$PWD:/data" \
  -v "/path/to/global-patterns.txt:/.renamerignore" \
  ghcr.io/mitch-b/renamer oldText newText
```

### Custom Global Ignore Patterns (Advanced)
Mount your patterns file to a custom location:
```bash
# Mount to custom path with environment variable
docker run --rm -it \
  -v "$PWD:/data" \
  -v "/path/to/global-patterns.txt:/custom-ignore.txt" \
  -e RENAMER_IGNORE_FILE=/custom-ignore.txt \
  ghcr.io/mitch-b/renamer oldText newText
```

### Combining Patterns
Use multiple pattern sources together:
```bash
# Project .renamerignore + mounted global patterns + command-line patterns
docker run --rm -it \
  -v "$PWD:/data" \
  -v "$HOME/.config/renamer-patterns.txt:/.renamerignore" \
  ghcr.io/mitch-b/renamer oldText newText --ignore "temp,cache"
```
  ghcr.io/mitch-b/renamer oldText newText
```

**Advanced Docker usage:**
```bash
# Combine project .renamerignore with custom global patterns
# (project patterns take priority, global patterns add to them)
docker run --rm -it \
  -v "$PWD:/data" \
  -v "$HOME/.config/renamer-patterns.txt:/.renamerignore" \
  ghcr.io/mitch-b/renamer oldText newText --ignore "temp,cache"
```

**Using .renamerignore files (Local Development):**

See `.renamerignore.example` for a comprehensive example file.

---

## How it Works
1. **Preview**: Shows up to 5 sample matches for files, folders, and file contents
2. **Confirm**: Prompts before making changes
3. **Replace**: Updates file contents, then renames folders and files

---

## Build Docker Image (Optional)

Most users can use the pre-built image `ghcr.io/mitch-b/renamer`. Only build your own if you need custom modifications:

```bash
docker build -t mitch-b/renamer .
```

---

## Warnings & Tips
- **🐳 Use Docker**: This tool is designed to run in Docker for portability and isolation
- **💾 Backup your data!** This script makes bulk changes
- **🧪 Test on a copy** before running on important data  
- **📁 Mount correctly**: Always use `-v "$PWD:/data"` to mount your current directory
- **🔍 Case-sensitive**: The search is case-sensitive
- **⏪ No undo**: Changes are immediate and cannot be undone automatically
- **⚡ Special characters**: If your search/replace strings contain special characters, test carefully
- **🛡️ Protected by default**: `.git/` and `node_modules/` are automatically ignored for safety

---

## License
MIT

---

## Issues / Feedback
Open an issue or PR on GitHub if you have suggestions or problems.
