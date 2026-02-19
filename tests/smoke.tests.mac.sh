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

if [ ! -f "$REPO_ROOT/config/search-profiles.conf" ]; then
  echo "Error: missing shared config at $REPO_ROOT/config/search-profiles.conf" >&2
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

assert_file_not_contains() {
  local path="$1"
  local pattern="$2"
  if rg -q -- "$pattern" "$path"; then
    echo "Assertion failed: expected $path to NOT contain '$pattern'" >&2
    exit 1
  fi
}

run_search() {
  (
    cd "$REPO_ROOT"
    SEARCH_RESULTS_DIR="$RESULTS_DIR" bash "$SEARCH_SCRIPT" "$@"
  )
}

echo "Running shell smoke tests..."

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

# 5) txt output (content profile)
query='extended-grep'
out="$RESULTS_DIR/${query}.grepx.txt"
rm -f "$out"
run_search --format txt "$query" >/dev/null
assert_file_exists "$out"
assert_file_contains "$out" 'extended-grep'
assert_file_contains "$out" 'profile: grepx'
assert_file_contains "$out" '\(hit [0-9]+ of [0-9]+\)'
assert_file_contains "$out" '\[\['

echo "[ok] txt content output handled"

# 6) txt output (filename profile)
query='search.ps1'
out="$RESULTS_DIR/${query}.filename.txt"
rm -f "$out"
run_search --format txt filename "$query" >/dev/null
assert_file_exists "$out"
if ! rg -q '\(file [0-9]+ of [0-9]+\)' "$out"; then
  echo "Assertion failed: expected file counters in txt filename output." >&2
  exit 1
fi

echo "[ok] txt filename output handled"

# 7) profile list
profiles_output=$(bash "$SEARCH_SCRIPT" --profile-list)
if ! printf '%s\n' "$profiles_output" | rg -q '^grepx$'; then
  echo "Assertion failed: expected grepx in --profile-list output." >&2
  exit 1
fi
if ! printf '%s\n' "$profiles_output" | rg -q '^filename$'; then
  echo "Assertion failed: expected filename in --profile-list output." >&2
  exit 1
fi

echo "[ok] profile-list output handled"

# 8) deterministic fixture rendering checks
query='fox'
out="$RESULTS_DIR/${query}.grepx.html"
rm -f "$out"
(
  cd "$REPO_ROOT/tests/documents"
  SEARCH_RESULTS_DIR="$RESULTS_DIR" bash "$SEARCH_SCRIPT" "$query" >/dev/null
)
assert_file_exists "$out"
if ! rg -q '\(file 1 of [0-9]+\)' "$out"; then
  echo "Assertion failed: expected first file counter header." >&2
  exit 1
fi
if ! rg -q 'hit [0-9]+ of [0-9]+' "$out"; then
  echo "Assertion failed: expected hit counters in match rows." >&2
  exit 1
fi
assert_file_contains "$out" 'row context'
assert_file_contains "$out" 'article:published_time'
if ! rg -q 'row context.*article:published_time' "$out"; then
  echo "Assertion failed: expected article:published_time to be a context row." >&2
  exit 1
fi

echo "[ok] fixture rendering includes file counters and context/match structure"

# 9) diverse fixture set: punctuation query and multi-format coverage
query='fox, '
out="$RESULTS_DIR/fox_.grepx.txt"
rm -f "$out"
(
  cd "$REPO_ROOT/tests/documents/diverse"
  SEARCH_RESULTS_DIR="$RESULTS_DIR" bash "$SEARCH_SCRIPT" --format txt "$query" >/dev/null
)
assert_file_exists "$out"
assert_file_contains "$out" 'sample.json'
assert_file_contains "$out" 'sample.xml'
assert_file_contains "$out" 'sample.yaml'
assert_file_contains "$out" 'sample.csv'
assert_file_contains "$out" 'file with spaces.txt'
assert_file_contains "$out" '\[\[fox, \]\]'

echo "[ok] diverse fixtures cover punctuation, spaces, and multiple file types"

# 10) limits behavior: max-per-file
query='fox'
out="$RESULTS_DIR/${query}.grepx.txt"
rm -f "$out"
(
  cd "$REPO_ROOT/tests/documents/limits"
  SEARCH_RESULTS_DIR="$RESULTS_DIR" bash "$SEARCH_SCRIPT" --format txt --context 0 --max-per-file 2 "$query" >/dev/null
)
assert_file_exists "$out"
assert_file_contains "$out" 'hit 1 of 2'
assert_file_contains "$out" 'hit 2 of 2'
assert_file_not_contains "$out" 'hit 3 of'

echo "[ok] max-per-file cap is enforced"

# 11) limits behavior: max-scan-lines + max-render-lines
query='fox'
out="$RESULTS_DIR/${query}.grepx.txt"
rm -f "$out"
(
  cd "$REPO_ROOT/tests/documents/limits"
  SEARCH_RESULTS_DIR="$RESULTS_DIR" bash "$SEARCH_SCRIPT" --format txt --context 0 --max-per-file 0 --max-scan-lines 5 --max-render-lines 3 "$query" >/dev/null
)
assert_file_exists "$out"
assert_file_contains "$out" 'note: output truncated to 3 lines \(original: 5\)'
assert_file_contains "$out" 'hit 3 of 3'

echo "[ok] max-scan-lines and max-render-lines caps are enforced"

echo "All shell smoke tests passed."
