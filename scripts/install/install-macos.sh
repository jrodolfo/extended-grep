#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
RUNTIME_DIR="$REPO_ROOT/scripts/runtime"
TARGET_DIR="${HOME}/.local/bin"
SHELL_RC="${HOME}/.zshrc"

if [ ! -f "$SHELL_RC" ]; then
  SHELL_RC="${HOME}/.bashrc"
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required. Install with: brew install ripgrep"
  exit 1
fi

mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/config"
cp "$RUNTIME_DIR/search.sh" "$TARGET_DIR/search"
cp "$RUNTIME_DIR/grepfunctions.sh" "$TARGET_DIR/grepfunctions.sh"
cp "$REPO_ROOT/config/search-profiles.conf" "$TARGET_DIR/config/search-profiles.conf"
chmod +x "$TARGET_DIR/search"

if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_RC" 2>/dev/null; then
  {
    echo
    echo '# extended-grep'
    echo 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "$SHELL_RC"
fi

echo "Installed search to $TARGET_DIR/search"
echo "Open a new terminal, then run: search STRING"
