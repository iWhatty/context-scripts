#!/bin/zsh

TARGET_DIR="$1"
SCRIPT="/Users/jj/scripts/copy-context.js"
NODE_BIN="/Users/jj/.local/share/fnm/node-versions/v24.14.0/installation/bin/node"

if [ -z "$TARGET_DIR" ]; then
  echo "No folder selected"
  exit 1
fi

"$NODE_BIN" "$SCRIPT" "$TARGET_DIR" --stdout