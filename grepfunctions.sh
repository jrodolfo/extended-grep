#!/usr/bin/env bash

# Shared search functions for search.sh.

set -o pipefail

# Directories we skip across all profiles.
COMMON_EXCLUDE_GLOBS=(
  "!**/.git/**"
  "!**/.idea/**"
  "!**/.metadata/**"
  "!**/.jazz5/**"
  "!**/.jazzShed/**"
  "!**/.mule/**"
  "!**/target/**"
  "!**/bin/**"
  "!**/*Documentation*/**"
  "!**/RoboHelp*/**"
  "!**/.gradle/**"
  "!**/gradle/**"
  "!**/build/**"
)

html_escape() {
  local input="$1"
  input=${input//&/&amp;}
  input=${input//</&lt;}
  input=${input//>/&gt;}
  input=${input//\"/&quot;}
  printf '%s' "$input"
}

safe_filename() {
  local input="$1"
  input=$(printf '%s' "$input" | tr ' ' '_')
  input=$(printf '%s' "$input" | tr -cd '[:alnum:]_.-')
  if [ -z "$input" ]; then
    input="search"
  fi
  printf '%s' "$input"
}

append_common_globs() {
  local g
  for g in "${COMMON_EXCLUDE_GLOBS[@]}"; do
    RG_WORK_ARGS+=("--glob=$g")
  done
}

profile_is_filename_search() {
  case "$1" in
    filename|docs|jar|java_filename|x_filename) return 0 ;;
    *) return 1 ;;
  esac
}

# Build profile-specific rg args for content searches.
build_profile_args() {
  local profile="$1"

  RG_WORK_ARGS=(--hidden --line-number --column --with-filename --smart-case --color=never -A5 -B5)
  append_common_globs

  case "$profile" in
    grepx|codescan)
      RG_WORK_ARGS+=(--glob=!**/*.jar --glob=!**/*.class --glob=!**/*.zip --glob=!**/*.png --glob=!**/*.jpg --glob=!**/*.gif --glob=!**/*.pdf --glob=!**/*.mp4 --glob=!**/*.exe --glob=!**/*.msi --glob=!**/*.7z)
      ;;
    android)
      RG_WORK_ARGS+=(--glob=!**/*.jar --glob=!**/*.class --glob=!**/*.zip --glob=!**/*.apk --glob=!**/*.iml --glob=!**/gradlew --glob=!**/*.png --glob=!**/*.jpg --glob=!**/*.gif --glob=!**/*.pdf --glob=!**/*.mp4 --glob=!**/*.exe --glob=!**/*.msi --glob=!**/*.7z)
      ;;
    code)
      RG_WORK_ARGS+=(--glob=**/*.java --glob=**/*.js --glob=**/*.ts --glob=**/*.tsx --glob=**/*.jsx --glob=**/*.kt --glob=**/*.kts --glob=**/*.xml --glob=**/*.yml --glob=**/*.yaml --glob=**/*.properties --glob=**/*.sh --glob=**/*.bat --glob=**/*.cmd --glob=**/*.ps1)
      ;;
    web)
      RG_WORK_ARGS+=(--glob=**/*.html --glob=**/*.htm --glob=**/*.xhtml --glob=**/*.css --glob=**/*.js --glob=**/*.ts --glob=**/*.jsx --glob=**/*.tsx)
      ;;
    java)
      RG_WORK_ARGS+=(--glob=**/*.java)
      ;;
    javascript)
      RG_WORK_ARGS+=(--glob=**/*.js --glob=**/*.ts --glob=**/*.jsx --glob=**/*.tsx)
      ;;
    xhtml)
      RG_WORK_ARGS+=(--glob=**/*.xhtml --glob=**/*.html --glob=**/*.htm)
      ;;
    css)
      RG_WORK_ARGS+=(--glob=**/*.css)
      ;;
    sql)
      RG_WORK_ARGS+=(--glob=**/*.sql)
      ;;
    xml)
      RG_WORK_ARGS+=(--glob=**/*.xml)
      ;;
    *)
      return 2
      ;;
  esac

  return 0
}

run_content_search() {
  local profile="$1"
  local query="$2"

  build_profile_args "$profile" || return $?
  rg "${RG_WORK_ARGS[@]}" -- "$query" .
}

run_filename_search() {
  local profile="$1"
  local query="$2"
  RG_WORK_ARGS=(--files)

  append_common_globs

  case "$profile" in
    filename|x_filename)
      ;;
    java_filename)
      RG_WORK_ARGS+=(--glob=**/*.java)
      ;;
    jar)
      RG_WORK_ARGS+=(--glob=**/*.jar)
      ;;
    docs)
      RG_WORK_ARGS+=(--glob=**/*.doc --glob=**/*.docx --glob=**/*.pdf --glob=**/*.ppt --glob=**/*.pptx --glob=**/*.xls --glob=**/*.xlsx)
      ;;
    *)
      return 2
      ;;
  esac

  rg "${RG_WORK_ARGS[@]}" | rg --smart-case --color=never -- "$query"
}

emit_html_header() {
  local query="$1"
  local profile="$2"

  printf '<!doctype html>\n'
  printf '<html lang="en">\n<head>\n'
  printf '<meta charset="utf-8"/>\n'
  printf '<meta name="viewport" content="width=device-width, initial-scale=1"/>\n'
  printf '<title>extended-grep results</title>\n'
  printf '<style>\n'
  printf ':root{--bg:#0b1220;--panel:#111a2b;--panel-border:#243349;--muted:#9fb0c8;--path:#7dd3fc;--line:#a78bfa;--col:#f9a8d4;--text:#e2e8f0;--match-bg:#fde047;--match-fg:#111827;}\n'
  printf '*{box-sizing:border-box;} body{margin:0;padding:20px;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;background:var(--bg);color:var(--text);}\n'
  printf 'h1{margin:0 0 8px;font-size:20px;} .meta{color:var(--muted);margin-bottom:16px;}\n'
  printf '.file{background:var(--panel);border:1px solid var(--panel-border);border-radius:10px;margin:0 0 14px;overflow:hidden;}\n'
  printf '.file-header{padding:10px 12px;border-bottom:1px solid var(--panel-border);color:var(--path);font-weight:700;}\n'
  printf '.row{display:grid;grid-template-columns:70px 70px 1fr;gap:8px;padding:6px 12px;align-items:start;}\n'
  printf '.row.match{background:rgba(125,211,252,0.08);} .row.context{background:rgba(148,163,184,0.06);}\n'
  printf '.line{color:var(--line);} .col{color:var(--col);} .text{white-space:pre-wrap;word-break:break-word;}\n'
  printf '.separator{border-top:1px dashed #334155;}\n'
  printf '.file-list{list-style:none;margin:0;padding:0;} .file-list li{padding:8px 12px;border-top:1px solid var(--panel-border);color:var(--path);word-break:break-all;}\n'
  printf 'mark.hit{background:var(--match-bg);color:var(--match-fg);padding:0 2px;border-radius:3px;font-weight:700;}\n'
  printf '.empty{background:var(--panel);border:1px solid var(--panel-border);padding:12px;border-radius:10px;color:var(--muted);}\n'
  printf '</style>\n'
  printf '</head>\n'
  printf '<body data-query="%s">\n' "$(html_escape "$query")"
  printf '<h1>extended-grep</h1>\n'
  printf '<div class="meta">profile: <strong>%s</strong> | query: <strong>%s</strong></div>\n' "$(html_escape "$profile")" "$(html_escape "$query")"
}

emit_html_footer() {
  cat <<'END_HTML_JS'
<script>
(function () {
  const query = document.body.dataset.query || "";
  if (!query) return;

  function escapeRegex(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  function highlight(selector, className) {
    const re = new RegExp(escapeRegex(query), "ig");
    document.querySelectorAll(selector).forEach((el) => {
      const text = el.textContent;
      if (!text) return;
      re.lastIndex = 0;
      if (!re.test(text)) return;

      el.textContent = "";
      re.lastIndex = 0;
      let last = 0;
      let m;
      while ((m = re.exec(text)) !== null) {
        if (m.index > last) {
          el.appendChild(document.createTextNode(text.slice(last, m.index)));
        }
        const mark = document.createElement("mark");
        mark.className = className;
        mark.textContent = m[0];
        el.appendChild(mark);
        last = m.index + m[0].length;
      }
      if (last < text.length) {
        el.appendChild(document.createTextNode(text.slice(last)));
      }
    });
  }

  highlight('.text', 'hit');
  highlight('.file-header', 'hit');
  highlight('.file-list li', 'hit');
})();
</script>
</body>
</html>
END_HTML_JS
}

render_content_report() {
  local infile="$1"

  if [ ! -s "$infile" ]; then
    printf '<div class="empty">No matches found.</div>\n'
    return
  fi

  local current_file=""
  local line

  while IFS= read -r line; do
    if [ "$line" = "--" ]; then
      if [ -n "$current_file" ]; then
        printf '<div class="separator"></div>\n'
      fi
      continue
    fi

    if [[ "$line" =~ ^(.+):([0-9]+):([0-9]+):(.*)$ ]]; then
      local file_path="${BASH_REMATCH[1]}"
      local line_no="${BASH_REMATCH[2]}"
      local col_no="${BASH_REMATCH[3]}"
      local text="${BASH_REMATCH[4]}"

      if [ "$file_path" != "$current_file" ]; then
        if [ -n "$current_file" ]; then
          printf '</div>\n'
        fi
        current_file="$file_path"
        printf '<div class="file">\n'
        printf '<div class="file-header">%s</div>\n' "$(html_escape "$file_path")"
      fi

      printf '<div class="row match"><span class="line">%s</span><span class="col">%s</span><span class="text">%s</span></div>\n' \
        "$(html_escape "$line_no")" "$(html_escape "$col_no")" "$(html_escape "$text")"
      continue
    fi

    if [[ "$line" =~ ^(.+)-([0-9]+)-([0-9]+)-(.*)$ ]]; then
      local file_path="${BASH_REMATCH[1]}"
      local line_no="${BASH_REMATCH[2]}"
      local col_no="${BASH_REMATCH[3]}"
      local text="${BASH_REMATCH[4]}"

      if [ "$file_path" != "$current_file" ]; then
        if [ -n "$current_file" ]; then
          printf '</div>\n'
        fi
        current_file="$file_path"
        printf '<div class="file">\n'
        printf '<div class="file-header">%s</div>\n' "$(html_escape "$file_path")"
      fi

      printf '<div class="row context"><span class="line">%s</span><span class="col">%s</span><span class="text">%s</span></div>\n' \
        "$(html_escape "$line_no")" "$(html_escape "$col_no")" "$(html_escape "$text")"
      continue
    fi

    if [[ "$line" =~ ^(.+)-([0-9]+)-(.*)$ ]]; then
      local file_path="${BASH_REMATCH[1]}"
      local line_no="${BASH_REMATCH[2]}"
      local text="${BASH_REMATCH[3]}"

      if [ "$file_path" != "$current_file" ]; then
        if [ -n "$current_file" ]; then
          printf '</div>\n'
        fi
        current_file="$file_path"
        printf '<div class="file">\n'
        printf '<div class="file-header">%s</div>\n' "$(html_escape "$file_path")"
      fi

      printf '<div class="row context"><span class="line">%s</span><span class="col">-</span><span class="text">%s</span></div>\n' \
        "$(html_escape "$line_no")" "$(html_escape "$text")"
      continue
    fi

    if [ -n "$current_file" ]; then
      printf '<div class="row context"><span class="line">-</span><span class="col">-</span><span class="text">%s</span></div>\n' "$(html_escape "$line")"
    fi
  done < "$infile"

  if [ -n "$current_file" ]; then
    printf '</div>\n'
  fi
}

render_filename_report() {
  local infile="$1"

  if [ ! -s "$infile" ]; then
    printf '<div class="empty">No files found.</div>\n'
    return
  fi

  printf '<div class="file">\n<div class="file-header">Matching files</div>\n<ul class="file-list">\n'
  local line
  while IFS= read -r line; do
    printf '<li>%s</li>\n' "$(html_escape "$line")"
  done < "$infile"
  printf '</ul>\n</div>\n'
}

render_html_report() {
  local infile="$1"
  local outfile="$2"
  local query="$3"
  local profile="$4"

  {
    emit_html_header "$query" "$profile"
    if profile_is_filename_search "$profile"; then
      render_filename_report "$infile"
    else
      render_content_report "$infile"
    fi
    emit_html_footer
  } > "$outfile"
}
