#!/bin/zsh

# Uses the current user's home folder automatically.
# Put your scripts in: ~/scripts
# Example:
#   ~/scripts/copy-context.js
#   ~/scripts/run-copy-context.sh
#
# If your Node binary lives somewhere else, update NODE_BIN below.

TARGET_DIR="$1"
SCRIPT="$HOME/scripts/copy-context.js"
NODE_BIN="$HOME/.local/share/fnm/node-versions/v24.14.0/installation/bin/node"

if [ -z "$TARGET_DIR" ]; then
  echo "No folder selected"
  exit 1
fi

"$NODE_BIN" "$SCRIPT" "$TARGET_DIR" --stdout