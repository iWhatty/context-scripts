context-scripts

Fast local scripts for turning folders of source code into clean, ChatGPT-ready context.

Built for low-friction workflows like:
	•	right click a folder in macOS Finder
	•	run a Quick Action
	•	copy formatted code context to clipboard
	•	paste directly into ChatGPT

Repo: https://github.com/iWhatty/context-scripts.git

⸻

What it does

The macOS context script can:
	•	recursively scan a selected folder
	•	collect source files by extension
	•	ignore common junk folders like node_modules, .git, build, dist, etc.
	•	format output as a readable markdown bundle
	•	place file paths above each code block
	•	send the result to clipboard through a macOS Shortcut / Quick Action

Example output:

# Project Context

- Root: /Users/yourname/dev/my-project/src
- Profile: default
- Included files: 3
- Extensions: .js, .kt, .py, .ts

## File List

- parser/MainParser.kt
- parser/Tokenizer.kt
- util/DateUtils.kt

---

## File: parser/MainParser.kt

```kotlin
// code here

File: parser/Tokenizer.kt

// code here

---

## Repo structure

```text
context-scripts/
├── macos/
│   ├── copy-context.js
│   ├── run-copy-context.sh
│   └── ...
└── README.md


⸻

macOS setup

1. Put the scripts somewhere stable

Keep the scripts in a non-protected folder such as:

/Users/yourname/scripts

Avoid building this around Documents, because macOS privacy controls can block Quick Actions from reading folder contents there.

A good working layout is:

/Users/yourname/scripts/copy-context.js
/Users/yourname/scripts/run-copy-context.sh

Keep your actual code repos in something like:

/Users/yourname/dev
/Users/yourname/projects


⸻

2. Make the wrapper executable

chmod +x /Users/yourname/scripts/run-copy-context.sh


⸻

3. Use a real Node binary path

If you use a version manager like fnm, nvm, or similar, macOS Shortcuts may not inherit your normal shell environment.

That means this often fails inside a Quick Action:

node copy-context.js ...

Instead, use the real Node binary path.

Find it with:

python3 - <<'PY'
import os
print(os.path.realpath(os.popen("which node").read().strip()))
PY

Then use that exact path inside the shell wrapper.

Example:

NODE_BIN="/Users/yourname/.local/share/fnm/node-versions/v24.14.0/installation/bin/node"

Yes, this is ugly. Yes, it works.

⸻

macOS Shortcut / Finder Quick Action integration

This is the main event.

Goal

Right click a folder in Finder, run a Quick Action, and copy the formatted context to clipboard.

Shortcut flow

Create a Shortcut or Finder Quick Action with:
	1.	Accepts: folders
	2.	Run Shell Script
	3.	Copy to Clipboard
	4.	optional: Show Notification

Run Shell Script settings
	•	Shell: zsh
	•	Input: Shortcut Input
	•	Pass input: as arguments

Shell script command

/bin/zsh /Users/yourname/scripts/run-copy-context.sh "$1"

This wrapper should print the final context to stdout.

Then let the Shortcut’s Copy to Clipboard action handle the clipboard.

Do not also call pbcopy inside the wrapper if Shortcuts is already copying the shell output.

⸻

Example wrapper script

macos/run-copy-context.sh

#!/bin/zsh

TARGET_DIR="$1"
SCRIPT="/Users/yourname/scripts/copy-context.js"
NODE_BIN="/absolute/path/to/your/node"

if [ -z "$TARGET_DIR" ]; then
  echo "No folder selected"
  exit 1
fi

"$NODE_BIN" "$SCRIPT" "$TARGET_DIR" --stdout


⸻

Example Node script usage

Print to stdout

node copy-context.js /path/to/project --stdout

Write context.txt into the target folder

node copy-context.js /path/to/project

Custom extensions

node copy-context.js /path/to/project --ext js,ts,py,kt,java,xml --stdout

Profile-based scan

node copy-context.js /path/to/project --profile android --stdout


⸻

Profiles

The script supports extension profiles so you do not have to keep manually swapping file filters.

Example profiles:
	•	default
	•	web
	•	android
	•	python
	•	allcode

Example:

node copy-context.js /path/to/project --profile android --stdout


⸻

Supported features

Depending on the current script version, features may include:
	•	extension profiles
	•	recursive scanning
	•	max file size limit
	•	max total output size limit
	•	max file count
	•	skipped file summaries
	•	.contextignore
	•	git-tracked mode
	•	git-changed mode

⸻

.contextignore

You can place a .contextignore file at the root of a repo to exclude extra files or folders.

Example:

generated
tmp
*.snap
*.svg
package-lock.json
pnpm-lock.yaml

This is intentionally simpler than full .gitignore parsing.

⸻

Why not store repos in Documents?

Because macOS likes to act like your own folders are state secrets.

Finder Quick Actions and Shortcuts may receive the selected folder path correctly, but still fail to read the directory contents if the target lives inside protected folders like:
	•	Documents
	•	Desktop
	•	Downloads

You may see errors like:

EPERM: operation not permitted, scandir '/Users/yourname/Documents/...'

The easiest fix is to work from:

/Users/yourname/dev
/Users/yourname/projects

instead.

⸻

Troubleshooting

The Quick Action runs, but no files are found

First check whether the folder is inside Documents or another protected location.

If so, move the repo to something like:

/Users/yourname/dev

Also make sure the file extensions you want are actually included in the active profile.

node works in Terminal, but not in Shortcuts

That usually means Shortcuts cannot see your shell-managed PATH.

Use the real Node binary path instead of relying on:

node

inside the Quick Action shell environment.

Clipboard is only getting a status message

That means your wrapper is echoing something like:

echo "Code context copied to clipboard"

and Shortcuts is copying that output instead of the real context.

Fix: have the wrapper print the actual context only, and let Shortcuts handle the clipboard.

⸻

Recommended workflow

For best results:
	•	keep scripts in /Users/yourname/scripts
	•	keep repos in /Users/yourname/dev
	•	trigger via Finder Quick Action
	•	copy formatted context straight into ChatGPT
	•	avoid dumping giant folders unless you enjoy feeding sludge into models

⸻

Roadmap

Planned or possible upgrades:
	•	ranked file ordering
	•	changed-files-first mode
	•	git-aware prioritization
	•	VS Code integration
	•	Raycast integration
	•	open-tabs mode
	•	selected-files mode
	•	token/byte budgeting improvements

⸻

License

MIT