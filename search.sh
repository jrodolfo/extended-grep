#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./grepfunctions.sh
source "$SCRIPT_DIR/grepfunctions.sh"

usage() {
  cat <<'USAGE'
Usage:
  search.sh STRING
  search.sh PROFILE STRING

Profiles:
  grepx (default), codescan, android, code, web, java, java_filename,
  javascript, xhtml, css, sql, xml, docs, filename, x_filename, jar
USAGE
}

if ! command -v rg >/dev/null 2>&1; then
  echo "Error: ripgrep (rg) is required but not installed." >&2
  exit 1
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

results_dir="${HOME}/search-results"
mkdir -p "$results_dir"

safe_query=$(safe_filename "$query")
if [ "$profile" = "grepx" ]; then
  output_file="$results_dir/${safe_query}.grepx.html"
else
  output_file="$results_dir/${safe_query}.${profile}.html"
fi

tmp_output=$(mktemp)
trap 'rm -f "$tmp_output"' EXIT

if profile_is_filename_search "$profile"; then
  echo "Searching \"$query\" using filename profile \"$profile\"..."
  set +e
  run_filename_search "$profile" "$query" > "$tmp_output"
  search_rc=$?
  set -e
  if [ "$search_rc" -eq 2 ]; then
    echo "Error: unknown profile '$profile'." >&2
    usage
    exit 1
  fi
else
  echo "Searching \"$query\" using content profile \"$profile\"..."
  set +e
  run_content_search "$profile" "$query" > "$tmp_output"
  search_rc=$?
  set -e
  if [ "$search_rc" -eq 2 ]; then
    echo "Error: unknown profile '$profile'." >&2
    usage
    exit 1
  fi
fi

render_html_report "$tmp_output" "$output_file" "$query" "$profile"
echo "Result saved to: $output_file"
