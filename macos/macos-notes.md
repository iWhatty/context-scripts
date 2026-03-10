macOS Notes

A quick guide for getting the Finder Quick Action working on macOS.

What this does

This setup lets you:
	•	right click a folder in Finder
	•	run a Shortcut / Quick Action
	•	collect source files from that folder
	•	copy the formatted result to clipboard
	•	paste it directly into ChatGPT

⸻

1. Keep your code outside protected folders

Do not test this from Documents if you can avoid it.

macOS may block Quick Actions from reading folder contents in places like:
	•	Documents
	•	Desktop
	•	Downloads

Use something like:

~/dev
~/projects

Example:

/Users/yourname/dev


⸻

2. Put the scripts in a stable place

Recommended:

~/scripts

Example layout:

~/scripts/copy-context.js
~/scripts/run-copy-context.sh


⸻

3. Make the wrapper executable

Run:

chmod +x ~/scripts/run-copy-context.sh


⸻

4. Find your real Node path

Shortcuts may not see the same node command as your Terminal.

Run these in Terminal:

which node
ls -l "$(which node)"
readlink "$(which node)"
python3 - <<'PY'
import os
print(os.path.realpath(os.popen("which node").read().strip()))
PY

Use the final resolved path as NODE_BIN in your wrapper script.

Example:

NODE_BIN="$HOME/.local/share/fnm/node-versions/v24.14.0/installation/bin/node"


⸻

5. Use this wrapper script

run-copy-context.sh

#!/bin/zsh

TARGET_DIR="$1"
SCRIPT="$HOME/scripts/copy-context.js"
NODE_BIN="$HOME/.local/share/fnm/node-versions/v24.14.0/installation/bin/node"

if [ -z "$TARGET_DIR" ]; then
  echo "No folder selected"
  exit 1
fi

"$NODE_BIN" "$SCRIPT" "$TARGET_DIR" --stdout

If your Node path is different, change NODE_BIN.

⸻

6. Build the Finder Quick Action in Shortcuts

Create a Shortcut or Quick Action with:
	1.	Accepts: folders
	2.	Run Shell Script
	3.	Copy to Clipboard
	4.	optional: Show Notification

Run Shell Script settings
	•	Shell: zsh
	•	Input: Shortcut Input
	•	Pass input: as arguments

Shell command

/bin/zsh "$HOME/scripts/run-copy-context.sh" "$1"


⸻

7. Test it

Right click a folder inside ~/dev or ~/projects.

Run the Quick Action.

Then paste into a text editor or ChatGPT.

If it works, you should see something like:

# Project Context

- Root: /Users/*USER_NAME*/dev/my-project
- Included files: 3

## File List

- src/main.ts
- src/utils.ts
- scripts/build.py


⸻

Troubleshooting

Problem: node works in Terminal but not in Shortcuts

Cause: Shortcuts does not inherit your normal shell PATH.

Fix: use the real resolved Node binary path in NODE_BIN.

Problem: folder path is correct but no files are found

Cause: macOS may be blocking reads in protected folders like Documents.

Fix: move the repo to ~/dev or ~/projects.

Problem: clipboard only gets a status message

Cause: the shell script is printing echo "done" instead of the actual context.

Fix: have the wrapper print only the script output, and let Shortcuts do the clipboard copy.

⸻

Optional improvement

You can add a screenshot of the Shortcut setup to the repo so users can copy the exact configuration faster.