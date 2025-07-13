# renamer 🔀

**Docker-based find-and-replace tool for files and directories.**

## Quick Start

```bash
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText
```

## Basic Options

```bash
# Skip file contents (only rename files/folders)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --skip-contents

# Ignore additional patterns
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --ignore "dist,build"

# Mount custom ignore patterns
docker run --rm -it -v "$PWD:/data" -v "/path/to/.renamerignore:/.renamerignore" ghcr.io/mitch-b/renamer oldText newText
```

## Ignore Patterns

- **Default**: Project includes `.renamerignore` with common patterns (`.git/`, `node_modules/`, etc.)
- **Project-specific**: Create `.renamerignore` in your project directory (merges with defaults)
- **Custom**: Mount `.renamerignore` files to `/.renamerignore` in container (overrides defaults)

**Example .renamerignore:**
```
dist
build
*.log
temp
```

## Options

- `--skip-contents`: Only rename files/folders, skip content replacement
- `--ignore <pattern>`: Ignore patterns (comma-separated or multiple flags)
- `--include <pattern>`: Force include patterns (overrides ignores)

## Requirements

- Docker

## License

MIT
