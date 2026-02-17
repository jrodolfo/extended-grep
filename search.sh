#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./grepfunctions.sh
source "$SCRIPT_DIR/grepfunctions.sh"

usage() {
  cat <<'USAGE'
Usage:
  search [OPTIONS] STRING
  search [OPTIONS] PROFILE STRING

Profiles:
  grepx (default), codescan, android, code, web, java, java_filename,
  javascript, xhtml, css, sql, xml, docs, filename, x_filename, jar

Options:
  -h, --help                 Show this help message
  --deep                     Include hidden files and directories
  --hidden                   Alias for --deep
  --context N                Context lines before/after each hit (default: 3)
  --max-per-file N           Max matches per file (default: 200, 0 = unlimited)
  --max-filesize SIZE        Skip files larger than SIZE (default: 1M, use 'none' for unlimited)
  --max-scan-lines N         Cap lines collected from rg before rendering (default: 20000, 0 = unlimited)
  --max-line-length N        Trim very long result lines before rendering (default: 2000, 0 = unlimited)
  --max-render-lines N       Cap rendered lines in HTML (default: 12000, 0 = unlimited)

Environment:
  SEARCH_RESULTS_DIR         Output directory (default: ~/search-results)

Examples:
  search fox
  search --deep fox
  search --max-per-file 50 xml Transaction-ID
  search filename p-dcs-flightsummary
USAGE
}

is_positive_int() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

require_option_value() {
  local opt="$1"
  local val="$2"
  if [ -z "$val" ]; then
    echo "Error: $opt requires a value." >&2
    usage
    exit 1
  fi
}

if ! command -v rg >/dev/null 2>&1; then
  echo "Error: ripgrep (rg) is required but not installed." >&2
  exit 1
fi

SEARCH_INCLUDE_HIDDEN=0
SEARCH_CONTEXT_LINES=3
SEARCH_MAX_PER_FILE=200
SEARCH_MAX_FILESIZE="1M"
SEARCH_MAX_SCAN_LINES=20000
SEARCH_MAX_LINE_LENGTH=2000
SEARCH_MAX_RENDER_LINES=12000

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --deep|--hidden)
      SEARCH_INCLUDE_HIDDEN=1
      shift
      ;;
    --context)
      require_option_value "$1" "${2:-}"
      if ! is_positive_int "$2"; then
        echo "Error: --context expects a non-negative integer." >&2
        exit 1
      fi
      SEARCH_CONTEXT_LINES="$2"
      shift 2
      ;;
    --max-per-file)
      require_option_value "$1" "${2:-}"
      if ! is_positive_int "$2"; then
        echo "Error: --max-per-file expects a non-negative integer." >&2
        exit 1
      fi
      SEARCH_MAX_PER_FILE="$2"
      shift 2
      ;;
    --max-filesize)
      require_option_value "$1" "${2:-}"
      if [ "$2" = "none" ]; then
        SEARCH_MAX_FILESIZE=""
      else
        SEARCH_MAX_FILESIZE="$2"
      fi
      shift 2
      ;;
    --max-render-lines)
      require_option_value "$1" "${2:-}"
      if ! is_positive_int "$2"; then
        echo "Error: --max-render-lines expects a non-negative integer." >&2
        exit 1
      fi
      SEARCH_MAX_RENDER_LINES="$2"
      shift 2
      ;;
    --max-line-length)
      require_option_value "$1" "${2:-}"
      if ! is_positive_int "$2"; then
        echo "Error: --max-line-length expects a non-negative integer." >&2
        exit 1
      fi
      SEARCH_MAX_LINE_LENGTH="$2"
      shift 2
      ;;
    --max-scan-lines)
      require_option_value "$1" "${2:-}"
      if ! is_positive_int "$2"; then
        echo "Error: --max-scan-lines expects a non-negative integer." >&2
        exit 1
      fi
      SEARCH_MAX_SCAN_LINES="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: unknown option '$1'." >&2
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  usage
  exit 0
fi

if [ "$#" -eq 1 ]; then
  profile="grepx"
  query="$1"
elif [ "$#" -eq 2 ]; then
  profile="$1"
  query="$2"
else
  usage
  exit 1
fi

results_dir="${SEARCH_RESULTS_DIR:-${HOME}/search-results}"
mkdir -p "$results_dir"

safe_query=$(safe_filename "$query")
if [ "$profile" = "grepx" ]; then
  output_file="$results_dir/${safe_query}.grepx.html"
else
  output_file="$results_dir/${safe_query}.${profile}.html"
fi

tmp_output=$(mktemp)
tmp_render=$(mktemp)
trap 'rm -f "$tmp_output" "$tmp_render"' EXIT

search_started=$(date +%s)
scan_note=""
if profile_is_filename_search "$profile"; then
  echo "Searching \"$query\" using filename profile \"$profile\"..."
  set +e
  if [ "$SEARCH_MAX_SCAN_LINES" -gt 0 ]; then
    run_filename_search "$profile" "$query" | awk -v max="$SEARCH_MAX_SCAN_LINES" 'NR<=max{print} NR==max{exit 0}' > "$tmp_output"
  else
    run_filename_search "$profile" "$query" > "$tmp_output"
  fi
  search_rc=$?
  set -e
else
  echo "Searching \"$query\" using content profile \"$profile\"..."
  set +e
  if [ "$SEARCH_MAX_SCAN_LINES" -gt 0 ]; then
    run_content_search "$profile" "$query" | awk -v max="$SEARCH_MAX_SCAN_LINES" 'NR<=max{print} NR==max{exit 0}' > "$tmp_output"
  else
    run_content_search "$profile" "$query" > "$tmp_output"
  fi
  search_rc=$?
  set -e
fi
search_ended=$(date +%s)

if [ "$search_rc" -eq 141 ]; then
  search_rc=0
  scan_note="search output reached max scan lines (${SEARCH_MAX_SCAN_LINES})"
fi

if [ "$search_rc" -eq 2 ]; then
  echo "Error: unknown profile '$profile'." >&2
  usage
  exit 1
fi

note=""
if [ -n "$scan_note" ]; then
  note="$scan_note"
fi

if [ "$SEARCH_MAX_RENDER_LINES" -gt 0 ]; then
  result_lines=$(wc -l < "$tmp_output" | tr -d ' ')
  if [ "$result_lines" -gt "$SEARCH_MAX_RENDER_LINES" ]; then
    head -n "$SEARCH_MAX_RENDER_LINES" "$tmp_output" > "$tmp_render"
    if [ -n "$note" ]; then
      note="${note}; output truncated to ${SEARCH_MAX_RENDER_LINES} lines (original: ${result_lines})"
    else
      note="output truncated to ${SEARCH_MAX_RENDER_LINES} lines (original: ${result_lines})"
    fi
  else
    cp "$tmp_output" "$tmp_render"
  fi
else
  cp "$tmp_output" "$tmp_render"
fi

render_started=$(date +%s)
render_html_report "$tmp_render" "$output_file" "$query" "$profile" "$note"
render_ended=$(date +%s)

echo "Result saved to: $output_file"
echo "Timing: search=$((search_ended-search_started))s render=$((render_ended-render_started))s"
