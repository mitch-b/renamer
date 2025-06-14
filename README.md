# renamer 🔀

**Quick Start**

```bash
# bash
docker run --rm -it -v "$PWD:/data" mitch-b/renamer oldText newText
```

```powershell
# powerShell
docker run --rm -it -v "${PWD}:/data" mitch-b/renamer oldText newText
```

- Replace all `oldText` with `newText` in file/folder names and file contents, recursively.
- `-v "$PWD:/data"` mounts your current directory to `/data` in the container.

---

## Requirements
- Container runtime installed

---

## Features
- **Recursively renames** files and folders matching a search string
- **Replaces text** inside all files
- **Preview**: Shows sample matches before making changes
- **Interactive**: Asks for confirmation before proceeding

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
