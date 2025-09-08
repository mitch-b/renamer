# renamer 🔀

**Docker-based find-and-replace tool for files and directories.**

## Quick Start

```bash
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText
```

> Note: PowerShell users, use `${PWD}:/data`


(💡 see [aliasing](#aliasing) section to make this a simple CLI shortcut)

## Core Usage & Options

```bash
# (Always shows a full plan first, then prompts to apply)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText

# Force apply without prompt:
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --force

# Skip file contents (only rename files & folders)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --skip-contents

# Ignore additional patterns (comma separated or multiple flags)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --ignore "dist,build,*.log"

# Force include something otherwise ignored
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --ignore "dist,build" --include dist/config.json

# Process binary files too (default: binaries skipped)
docker run --rm -it -v "$PWD:/data" ghcr.io/mitch-b/renamer oldText newText --include-binary

# Mount custom global ignore file
docker run --rm -it -v "$PWD:/data" -v "/path/to/.renamerignore:/.renamerignore" ghcr.io/mitch-b/renamer oldText newText
```

## Ignore Patterns

- **Default**: Project includes [`.renamerignore`](./.renamerignore) with common patterns (`.git/`, `node_modules/`, etc.)
- **Project-specific**: Create `.renamerignore` in your project directory (merges with defaults)
- **Custom**: Mount `.renamerignore` files to `/.renamerignore` in container (overrides defaults)

### Pattern Syntax

Supports **gitignore-style patterns**:

- `dist` - Simple patterns (files or directories)
- `build/` - Directory-only patterns (trailing `/`)  
- `**/logs/` - Recursive directory patterns (ignore all `logs/` directories at any depth)
- `**/*.tmp` - Recursive file patterns (ignore all `.tmp` files at any depth)
- `!important.log` - Negation patterns (include exceptions to ignored patterns)
- `!**/logs/keep.*` - Recursive negation (keep specific files even in ignored directories)

**Example .renamerignore:**
```
# Ignore all build directories
**/build/

# But keep important config files
!**/build/config.json

# Ignore log files
*.log

# But keep error logs  
!error.log
```

## CLI Flags

| Flag | Shorthand | Description |
|------|-----------|-------------|
| `--force` | — | Apply changes without interactive confirmation (non-interactive automation) |
| `--skip-contents` | — | Skip in-file text replacement (only rename file/dir names) |
| `--ignore <pat>` | — | Add ignore patterns (comma separated or repeat flag) |
| `--include <pat>` | — | Force include pattern (overrides ignore rules) |
| `--include-binary` | — | Process binary files (by default they are skipped) |

Ignored patterns come from (in merge order):
1. Project `.renamerignore` (if present)
2. Mounted `/.renamerignore` (e.g. from host via `-v /path/.renamerignore:/.renamerignore`)
3. `--ignore` flags
4. Negations (`!pattern`) always applied last
5. `--include` force-includes override all of the above

The script internally translates gitignore-style patterns into `find` expressions including support for negations and recursive `**/` forms.

## Output UX Highlights

| Feature | Description |
|---------|-------------|
| Concise colored output | Automatically adapts to your terminal (falls back gracefully when piped) |
| Progress bars | Lightweight progress display for content scanning, directory scanning, file scanning, and rename phases (TTY only) |
| Safe binary default | Binary files ignored unless `--include-binary` supplied |
| Ignore introspection | Lists active ignore sources & files that contributed patterns |
| Structured summary | End-of-run aligned metrics + per-phase counts |
| Rename plan clarity | In dry run, shows `old -> new` for every planned rename |
| Actual rename list | On real run, lists executed file renames (directories & files) |

### Example Run (plan then apply)

```
Renamer • Find & Replace Utility
Find: 'old' → Replace: 'new'
--force supplied: will apply changes without interactive confirmation.

Initial scan (quick sample of file names containing pattern)
./src/old-module.js
...

Planned changes (full)
Files with matching content: 12
    ./src/feature/useOldThing.ts
    ./README.md
    ...
Directory renames: 1
    ./src/old_lib -> ./src/new_lib
File renames: 7
    ./src/old-module.js -> ./src/new-module.js
    ./test/old-test.spec.js -> ./test/new-test.spec.js

Applying changes (progress bars...)

Summary
    Files with content replaced: 12
    Directories renamed: 1
    Files renamed:       7
    Done
```

## Behavior Notes

* Output is readable whether run interactively or piped to a log file.
* The script always performs a full scan and prints the entire plan before asking for confirmation.
* Use `--force` for CI / automation (or set `RENAMER_AUTO_YES=1` env var) to skip the prompt.
* Legacy `--dry-run` / `-n` now maps to "plan only" and is deprecated; it prints the plan and exits without prompting.
* Replacements use `sed -i 's/find/replace/g'`; regex metacharacters in the find string are treated as regex (literal-mode flag planned).
* Binary files are skipped by default; `--include-binary` opts in.
* Content replacement happens before file & directory renames for stability.

## Roadmap / Future Ideas

- Undo pack / reversible transaction log
- Interactive selection (approve/reject individual renames/content changes)
- Parallel scanning for large repos (with ordering safeguards)

## Aliasing

To make this easier to run, configure an alias:

* ### bash / zsh

    ```bash
    vim ~/.bash_aliases
    # or
    vim ~/.zshrc
    ```

    add contents:

    ```bash
    alias renamer='docker run --rm -itq --pull always -v "$PWD:/data" ghcr.io/mitch-b/renamer'
    ```

* ### powershell

    ```powershell
    notepad $PROFILE
    ```

    add contents:

    ```powershell
    function renamer { docker run --rm -itq --pull always -v "${PWD}:/data" ghcr.io/mitch-b/renamer $args }
    ```

✅ Now you can use with a shortened syntax:

```bash
renamer oldText newText
```

## License

MIT
