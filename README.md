# context-scripts

Fast local scripts for turning source folders into clean, LLM-ready context.

`context-scripts` is built for a simple workflow on macOS:

1. Right-click a folder in Finder
2. Run a Quick Action
3. Copy formatted code context to the clipboard
4. Paste it into ChatGPT or another LLM

## What it does

The macOS script can:

- Recursively scan a selected folder
- Collect source files by extension or profile
- Skip common junk folders like `.git`, `node_modules`, `dist`, and `build`
- Format output as a readable markdown bundle
- Print the result to stdout or write it to a file
- Plug into macOS Shortcuts and Finder Quick Actions

## Repository structure

```text
context-scripts/
├── macos/
│   ├── copy-context.js
│   ├── run-copy-context.sh
│   └── ...
└── README.md
```

## macOS setup

### 1. Put the scripts somewhere stable

Keep the scripts in a non-protected folder such as:

```text
/Users/*USER_NAME*/scripts
```

A simple layout:

```text
/Users/*USER_NAME*/scripts/copy-context.js
/Users/*USER_NAME*/scripts/run-copy-context.sh
```

Avoid building this around `Documents` if you plan to trigger it from Finder Quick Actions or Shortcuts. macOS privacy controls can block automated directory reads there.

### 2. Make the wrapper executable

```bash
chmod +x /Users/*USER_NAME*/scripts/run-copy-context.sh
```

### 3. Use a real Node binary path

If you use `fnm`, `nvm`, or another version manager, Shortcuts may not inherit your normal shell environment.

So this can fail inside a Quick Action:

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

Then set that exact path inside the shell wrapper.

Example:

```bash
NODE_BIN="/Users/*USER_NAME*/.local/share/fnm/node-versions/v24.14.0/installation/bin/node"
```

Ugly, but reliable.

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

Do **not** also call `pbcopy` inside the wrapper if Shortcuts is already copying the shell output.

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

## Usage

### Print to stdout

```bash
node copy-context.js /path/to/project --stdout
```

### Write `context.txt` into the target folder

```bash
node copy-context.js /path/to/project
```

### Use custom extensions

```bash
node copy-context.js /path/to/project --ext js,ts,py,kt,java,xml --stdout
```

### Use a profile

```bash
node copy-context.js /path/to/project --profile android --stdout
```

## Profiles

The script supports extension profiles so you do not have to keep swapping file filters by hand.

Example profiles:

- `default`
- `web`
- `android`
- `python`
- `allcode`

Example:

```bash
node copy-context.js /path/to/project --profile android --stdout
```

## Supported features

Depending on the current script version, features may include:

- Extension profiles
- Recursive scanning
- Max file size limit
- Max total output size limit
- Max file count
- Skipped file summaries
- `.contextignore`
- Git-tracked mode
- Git-changed mode

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

## Troubleshooting

### The Quick Action runs, but no files are found

First, check whether the folder is inside `Documents` or another protected location.

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

- Keep scripts in `/Users/*USER_NAME*/scripts`
- Keep repos somewhere like `/Users/*USER_NAME*/dev`
- Trigger the script from a Finder Quick Action
- Paste the output directly into ChatGPT
- Do not dump giant trash folders into a model unless you enjoy bad results

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