#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
SEARCH_SCRIPT="$REPO_ROOT/search.sh"

if ! command -v rg >/dev/null 2>&1; then
  echo "Error: ripgrep (rg) is required for smoke tests." >&2
  exit 1
fi

if [ ! -f "$SEARCH_SCRIPT" ]; then
  echo "Error: search.sh not found at $SEARCH_SCRIPT" >&2
  exit 1
fi

TEST_ROOT=$(mktemp -d)
RESULTS_DIR="$TEST_ROOT/search-results"
mkdir -p "$RESULTS_DIR"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

assert_file_exists() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "Assertion failed: expected file $path" >&2
    exit 1
  fi
}

assert_file_contains() {
  local path="$1"
  local pattern="$2"
  if ! rg -q -- "$pattern" "$path"; then
    echo "Assertion failed: expected $path to contain '$pattern'" >&2
    exit 1
  fi
}

run_search() {
  SEARCH_RESULTS_DIR="$RESULTS_DIR" bash "$SEARCH_SCRIPT" "$@"
}

echo "Running macOS/bash smoke tests..."

# 1) default profile
query='extended-grep'
out="$RESULTS_DIR/${query}.grepx.html"
rm -f "$out"
run_search "$query" >/dev/null
assert_file_exists "$out"
assert_file_contains "$out" 'extended-grep'

echo "[ok] default profile search creates HTML"

# 2) filename profile
query='search.ps1'
out="$RESULTS_DIR/${query}.filename.html"
rm -f "$out"
run_search filename "$query" >/dev/null
assert_file_exists "$out"
assert_file_contains "$out" 'Matching files'

echo "[ok] filename profile search creates HTML"

# 3) no content matches
query="$(date +%s)-nohit-content"
out="$RESULTS_DIR/${query}.code.html"
rm -f "$out"
run_search code "$query" >/dev/null
assert_file_exists "$out"
assert_file_contains "$out" 'No matches found.'

echo "[ok] no-content match case handled"

# 4) no filename matches
query="$(date +%s)-nohit-file"
out="$RESULTS_DIR/${query}.filename.html"
rm -f "$out"
run_search filename "$query" >/dev/null
assert_file_exists "$out"
assert_file_contains "$out" 'No files found.'

echo "[ok] no-filename match case handled"

echo "All macOS/bash smoke tests passed."
