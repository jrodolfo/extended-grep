#!/usr/bin/env bash

set -euo pipefail
VERSION="2.0.0"

resolve_script_dir() {
  local src="${BASH_SOURCE[0]}"
  while [ -L "$src" ]; do
    local dir
    dir=$(cd -- "$(dirname -- "$src")" && pwd)
    src=$(readlink "$src")
    case "$src" in
      /*) ;;
      *) src="$dir/$src" ;;
    esac
  done
  cd -- "$(dirname -- "$src")" && pwd
}

SCRIPT_DIR=$(resolve_script_dir)
SEARCH_CONFIG_FILE="${SEARCH_CONFIG_FILE:-$SCRIPT_DIR/config/search-profiles.conf}"
# shellcheck source=./grepfunctions.sh
source "$SCRIPT_DIR/grepfunctions.sh"

usage() {
  cat <<USAGE
Usage:
  search [OPTIONS] STRING
  search [OPTIONS] PROFILE STRING

Profiles:
  $(profile_print_help)

Options:
  -h, --help                 Show this help message
  -v, --version              Show version and exit
  --profile-list             Print profiles and exit
  --format FMT               Output format: html or txt (default: html)
  --open                     Open generated report after search
  --deep                     Include hidden files and directories
  --hidden                   Alias for --deep
  --context N                Context lines before/after each hit (default: 3)
  --max-per-file N           Max matches per file (default: 200, 0 = unlimited)
  --max-filesize SIZE        Skip files larger than SIZE (default: 1M, use 'none' for unlimited)
  --max-scan-lines N         Cap lines collected from rg before rendering (default: 20000, 0 = unlimited)
  --max-line-length N        Trim very long result lines before rendering (default: 2000, 0 = unlimited)
  --max-render-lines N       Cap rendered lines in report (default: 12000, 0 = unlimited)

Environment:
  SEARCH_RESULTS_DIR         Output directory (default: ~/search-results)

Examples:
  search fox
  search --deep fox
  search --max-per-file 50 xml fox
  search filename part-of-file-name
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

if ! validate_search_config; then
  exit 1
fi

SEARCH_INCLUDE_HIDDEN=0
SEARCH_CONTEXT_LINES="$(config_default_value context_lines)"
SEARCH_MAX_PER_FILE="$(config_default_value max_per_file)"
SEARCH_MAX_FILESIZE="$(config_default_value max_filesize)"
SEARCH_MAX_SCAN_LINES="$(config_default_value max_scan_lines)"
SEARCH_MAX_LINE_LENGTH="$(config_default_value max_line_length)"
SEARCH_MAX_RENDER_LINES="$(config_default_value max_render_lines)"
SEARCH_OPEN=0
SEARCH_FORMAT="html"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      echo "extended-grep $VERSION"
      exit 0
      ;;
    --profile-list)
      profile_list_print
      exit 0
      ;;
    --open)
      SEARCH_OPEN=1
      shift
      ;;
    --format)
      require_option_value "$1" "${2:-}"
      case "$2" in
        html|txt) SEARCH_FORMAT="$2" ;;
        *)
          echo "Error: --format expects 'html' or 'txt'." >&2
          exit 1
          ;;
      esac
      shift 2
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
  profile="$(profile_default)"
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
  output_file="$results_dir/${safe_query}.grepx.${SEARCH_FORMAT}"
else
  output_file="$results_dir/${safe_query}.${profile}.${SEARCH_FORMAT}"
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
if [ "$SEARCH_FORMAT" = "txt" ]; then
  render_txt_report "$tmp_render" "$output_file" "$query" "$profile" "$note"
else
  render_html_report "$tmp_render" "$output_file" "$query" "$profile" "$note"
fi
render_ended=$(date +%s)

echo "Result saved to: $output_file"
echo "Timing: search=$((search_ended-search_started))s render=$((render_ended-render_started))s"

if [ "$SEARCH_OPEN" -eq 1 ]; then
  if command -v open >/dev/null 2>&1; then
    open "$output_file" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$output_file" >/dev/null 2>&1 || true
  else
    echo "Note: no opener command found (open/xdg-open)." >&2
  fi
fi
