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

- **Built-in**: `.git/` and `node_modules/` are automatically ignored
- **Project-specific**: Create `.renamerignore` in your project directory
- **Custom**: Mount `.renamerignore` files to `/.renamerignore` in container

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
- `--no-defaults`: Disable built-in `.git/` and `node_modules/` protection

## Requirements

- Docker

## License

MIT
