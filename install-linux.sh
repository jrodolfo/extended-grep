#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TARGET_DIR="${HOME}/.local/bin"

print_rg_install_hint() {
  if command -v dnf >/dev/null 2>&1; then
    echo "ripgrep (rg) is required. Install with: sudo dnf install -y ripgrep"
    return
  fi
  if command -v apt-get >/dev/null 2>&1; then
    echo "ripgrep (rg) is required. Install with: sudo apt-get update && sudo apt-get install -y ripgrep"
    return
  fi
  if command -v yum >/dev/null 2>&1; then
    echo "ripgrep (rg) is required. Install with: sudo yum install -y ripgrep"
    return
  fi
  if command -v zypper >/dev/null 2>&1; then
    echo "ripgrep (rg) is required. Install with: sudo zypper install -y ripgrep"
    return
  fi
  if command -v pacman >/dev/null 2>&1; then
    echo "ripgrep (rg) is required. Install with: sudo pacman -Sy ripgrep"
    return
  fi
  echo "ripgrep (rg) is required. Install it with your Linux package manager."
}

ensure_path_entry() {
  local rc_file="$1"
  [ -f "$rc_file" ] || return 0
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$rc_file" 2>/dev/null; then
    {
      echo
      echo '# extended-grep'
      echo 'export PATH="$HOME/.local/bin:$PATH"'
    } >> "$rc_file"
  fi
}

if ! command -v rg >/dev/null 2>&1; then
  print_rg_install_hint
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$SCRIPT_DIR/search.sh" "$TARGET_DIR/search"
cp "$SCRIPT_DIR/grepfunctions.sh" "$TARGET_DIR/grepfunctions.sh"
mkdir -p "$TARGET_DIR/config"
cp "$SCRIPT_DIR/config/search-profiles.conf" "$TARGET_DIR/config/search-profiles.conf"
chmod +x "$TARGET_DIR/search"

ensure_path_entry "${HOME}/.bashrc"
ensure_path_entry "${HOME}/.zshrc"

echo "Installed search to $TARGET_DIR/search"
echo "Open a new terminal, then run: search a-string"
