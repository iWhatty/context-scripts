# context-scripts

Turn a code folder into clean, LLM-ready markdown context.

`context-scripts` is a small Node-based CLI for bundling source files into a readable markdown output that can be pasted into ChatGPT or other LLMs. It also includes a macOS-friendly workflow for running the tool from Finder via Shortcuts or Quick Actions.

## Why this exists

LLMs are more useful when the input is clean, scoped, and readable.

Most code folders are not.

They are full of junk directories, generated files, oversized assets, lockfiles, and random noise that waste context space and make model output worse.

`context-scripts` exists to turn a folder of source code into a compact markdown bundle that is easier to paste into ChatGPT and easier for a model to reason about.

## Features

- Recursively scans a target folder
- Includes files by extension or named profile
- Skips common junk directories and file types
- Supports custom ignore rules with `.contextignore`
- Can print to stdout or write `context.txt`
- Supports file count and size limits
- Can summarize skipped files
- Supports Git-aware modes for tracked or changed files
- Works well with macOS Finder Quick Actions

## Repository structure

```text
context-scripts/
├── macos/
│   ├── copy-context.js
│   ├── run-copy-context.sh
│   └── ...
└── README.md
```

## Requirements

- Node.js
- macOS only if you want Finder Quick Action or Shortcuts integration

## Basic usage

Run the script directly:

```bash
node macos/copy-context.js /path/to/project --stdout
```

By default, the script writes `context.txt` into the target folder. Use `--stdout` when you want the output printed directly instead.

### Examples

Print context to stdout:

```bash
node macos/copy-context.js /path/to/project --stdout
```

Write `context.txt` into the target folder:

```bash
node macos/copy-context.js /path/to/project
```

Use custom extensions:

```bash
node macos/copy-context.js /path/to/project --ext js,ts,py,kt,java,xml --stdout
```

Use a profile:

```bash
node macos/copy-context.js /path/to/project --profile android --stdout
```

Only include Git-tracked files:

```bash
node macos/copy-context.js /path/to/project --git-tracked --stdout
```

Only include Git-changed files:

```bash
node macos/copy-context.js /path/to/project --git-changed --stdout
```

## Options

| Flag | Description |
|---|---|
| `--stdout` | Print the generated markdown bundle to stdout instead of writing `context.txt`. |
| `--profile <name>` | Use a built-in extension profile such as `default`, `web`, `android`, `python`, or `allcode`. |
| `--ext <list>` | Use a comma-separated list of extensions, for example `js,ts,py`. |
| `--git-tracked` | Only include files tracked by Git. |
| `--git-changed` | Only include files changed relative to `HEAD`. |
| `--max-file-bytes <n>` | Skip files larger than the given byte limit. |
| `--max-total-bytes <n>` | Stop adding file content once total output would exceed the given byte limit. |
| `--max-files <n>` | Stop after the given number of included files. |
| `--ignore-dir <name>` | Exclude an additional directory name. Can be passed more than once. |
| `--ignore-suffix <suffix>` | Exclude files ending with an additional suffix. Can be passed more than once. |
| `--no-skipped` | Hide the skipped-files summary section in the output. |
| `--include-hidden` | Include hidden files and directories that would otherwise be skipped. |
| `--no-contextignore` | Ignore the `.contextignore` file even if one exists. |

## Profiles

Built-in profiles:

- `default`
- `web`
- `android`
- `python`
- `allcode`

Example:

```bash
node macos/copy-context.js /path/to/project --profile web --stdout
```

## Output

The script generates a markdown bundle that includes:

- Project metadata
- A file list
- One code block per included file
- Optional skipped-file summaries
- Truncation notices if output limits are reached

## `.contextignore`

You can place a `.contextignore` file at the root of a repo to exclude extra files or folders.

Example:

```text
generated
tmp
*.snap
*.svg
package-lock.json
pnpm-lock.yaml
```

This is intentionally simpler than full `.gitignore` parsing.

## macOS setup

This section is only for the Finder Quick Action workflow.

### 1. Put the scripts somewhere stable

Keep the scripts in a non-protected folder such as:

```text
/Users/*USER_NAME*/scripts
```

Example layout:

```text
/Users/*USER_NAME*/scripts/copy-context.js
/Users/*USER_NAME*/scripts/run-copy-context.sh
```

Avoid placing target repos in protected folders like `Documents` if you plan to run the tool through Finder Quick Actions or Shortcuts. macOS privacy rules can block automated directory reads there.

### 2. Make the wrapper executable

```bash
chmod +x /Users/*USER_NAME*/scripts/run-copy-context.sh
```

### 3. Use a real Node binary path

If you use `fnm`, `nvm`, or another version manager, Shortcuts may not inherit your normal shell environment.

That means this can fail inside a Quick Action:

```bash
node copy-context.js ...
```

Use the real Node binary path instead.

Find it with:

```bash
python3 - <<'PY'
import os
print(os.path.realpath(os.popen("which node").read().strip()))
PY
```

Then set that exact path inside the wrapper.

Example:

```bash
NODE_BIN="/Users/*USER_NAME*/.local/share/fnm/node-versions/v24.14.0/installation/bin/node"
```

Ugly, but effective.

## Finder Quick Action integration

### Goal

Right-click a folder in Finder, run a Quick Action, and copy the formatted context to the clipboard.

### Shortcut flow

Create a Shortcut or Finder Quick Action with:

1. **Accepts**: folders
2. **Run Shell Script**
3. **Copy to Clipboard**
4. Optional: **Show Notification**

### Run Shell Script settings

- **Shell**: `zsh`
- **Input**: `Shortcut Input`
- **Pass input**: `as arguments`

### Shell command

```bash
/bin/zsh /Users/*USER_NAME*/scripts/run-copy-context.sh "$1"
```

The wrapper should print the final context to stdout.

Let the Shortcut’s **Copy to Clipboard** action handle the clipboard.

Do not call `pbcopy` inside the wrapper if Shortcuts is already copying shell output.

## Example wrapper script

File: `macos/run-copy-context.sh`

```bash
#!/bin/zsh

TARGET_DIR="$1"
SCRIPT="/Users/*USER_NAME*/scripts/copy-context.js"
NODE_BIN="/absolute/path/to/your/node"

if [ -z "$TARGET_DIR" ]; then
  echo "No folder selected"
  exit 1
fi

"$NODE_BIN" "$SCRIPT" "$TARGET_DIR" --stdout
```

## Troubleshooting

### The Quick Action runs, but no files are found

First check whether the folder is inside `Documents` or another protected location.

If so, move it somewhere less annoying, like:

```text
/Users/*USER_NAME*/dev
```

Also make sure the file extensions you want are included in the active profile.

### `node` works in Terminal, but not in Shortcuts

That usually means Shortcuts cannot see your shell-managed `PATH`.

Use the real Node binary path instead of relying on:

```bash
node
```

inside the Quick Action environment.

### The clipboard only gets a status message

That means your wrapper is printing something like:

```bash
echo "Code context copied to clipboard"
```

and Shortcuts is copying that message instead of the actual formatted context.

Fix it by having the wrapper print only the real context output.

## Recommended workflow

- Keep the scripts in `/Users/*USER_NAME*/scripts`
- Keep working repos somewhere like `/Users/*USER_NAME*/dev`
- Run the tool from Finder Quick Actions when you want fast clipboard output
- Use direct CLI commands when you want more control

## Roadmap

Possible upgrades:

- Ranked file ordering
- Changed-files-first mode
- Git-aware prioritization
- VS Code integration
- Raycast integration
- Open-tabs mode
- Selected-files mode
- Better token and byte budgeting

## License

MIT