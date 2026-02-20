#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="${HOME}/.local/bin"
TARGET_SEARCH="$TARGET_DIR/search"
TARGET_FUNCS="$TARGET_DIR/grepfunctions.sh"
TARGET_CONFIG_DIR="$TARGET_DIR/config"
TARGET_CONFIG_FILE="$TARGET_CONFIG_DIR/search-profiles.conf"
SHELL_RC="${HOME}/.zshrc"

if [ ! -f "$SHELL_RC" ]; then
  SHELL_RC="${HOME}/.bashrc"
fi

remove_file_if_exists() {
  local path="$1"
  if [ -f "$path" ]; then
    rm -f "$path"
    echo "Removed: $path"
  else
    echo "Already absent: $path"
  fi
}

remove_line_if_present() {
  local file="$1"
  local exact_line="$2"
  [ -f "$file" ] || return 0

  local tmp
  tmp=$(mktemp)
  awk -v line="$exact_line" '$0 != line { print }' "$file" > "$tmp"
  mv "$tmp" "$file"
}

remove_file_if_exists "$TARGET_SEARCH"
remove_file_if_exists "$TARGET_FUNCS"
remove_file_if_exists "$TARGET_CONFIG_FILE"

if [ -d "$TARGET_CONFIG_DIR" ] && [ -z "$(ls -A "$TARGET_CONFIG_DIR" 2>/dev/null)" ]; then
  rmdir "$TARGET_CONFIG_DIR"
  echo "Removed empty directory: $TARGET_CONFIG_DIR"
fi

if [ -f "$SHELL_RC" ]; then
  remove_line_if_present "$SHELL_RC" 'export PATH="$HOME/.local/bin:$PATH"'
  remove_line_if_present "$SHELL_RC" '# extended-grep'
  echo "Updated shell profile: $SHELL_RC"
fi

echo "Uninstall complete."
