param(
  [Parameter(Position=0)]
  [string]$Arg1,
  [Parameter(Position=1)]
  [string]$Arg2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Usage {
  @"
Usage:
  search.ps1 STRING
  search.ps1 PROFILE STRING

Profiles:
  grepx (default), codescan, android, code, web, java, java_filename,
  javascript, xhtml, css, sql, xml, docs, filename, x_filename, jar
"@
}

function Escape-Html([string]$Text) {
  if ($null -eq $Text) { return '' }
  return $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

function Safe-Name([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return 'search' }
  $v = $Text -replace '\s+', '_'
  $v = $v -replace '[^a-zA-Z0-9_.-]', ''
  if ([string]::IsNullOrWhiteSpace($v)) { return 'search' }
  return $v
}

function Get-CommonExcludeGlobs {
  return @(
    '--glob=!**/.git/**', '--glob=!**/.idea/**', '--glob=!**/.metadata/**', '--glob=!**/.jazz5/**',
    '--glob=!**/.jazzShed/**', '--glob=!**/.mule/**', '--glob=!**/target/**', '--glob=!**/bin/**',
    '--glob=!**/*Documentation*/**', '--glob=!**/RoboHelp*/**', '--glob=!**/.gradle/**',
    '--glob=!**/gradle/**', '--glob=!**/build/**'
  )
}

function Is-FilenameProfile([string]$Profile) {
  return @('filename','docs','jar','java_filename','x_filename') -contains $Profile
}

function Get-ContentArgs([string]$Profile) {
  $args = @('--hidden','--line-number','--column','--with-filename','--smart-case','--color=never','-A5','-B5')
  $args += Get-CommonExcludeGlobs

  switch ($Profile) {
    'grepx' { $args += @('--glob=!**/*.jar','--glob=!**/*.class','--glob=!**/*.zip','--glob=!**/*.png','--glob=!**/*.jpg','--glob=!**/*.gif','--glob=!**/*.pdf','--glob=!**/*.mp4','--glob=!**/*.exe','--glob=!**/*.msi','--glob=!**/*.7z') }
    'codescan' { $args += @('--glob=!**/*.jar','--glob=!**/*.class','--glob=!**/*.zip','--glob=!**/*.png','--glob=!**/*.jpg','--glob=!**/*.gif','--glob=!**/*.pdf','--glob=!**/*.mp4','--glob=!**/*.exe','--glob=!**/*.msi','--glob=!**/*.7z') }
    'android' { $args += @('--glob=!**/*.jar','--glob=!**/*.class','--glob=!**/*.zip','--glob=!**/*.apk','--glob=!**/*.iml','--glob=!**/gradlew','--glob=!**/*.png','--glob=!**/*.jpg','--glob=!**/*.gif','--glob=!**/*.pdf','--glob=!**/*.mp4','--glob=!**/*.exe','--glob=!**/*.msi','--glob=!**/*.7z') }
    'code' { $args += @('--glob=**/*.java','--glob=**/*.js','--glob=**/*.ts','--glob=**/*.tsx','--glob=**/*.jsx','--glob=**/*.kt','--glob=**/*.kts','--glob=**/*.xml','--glob=**/*.yml','--glob=**/*.yaml','--glob=**/*.properties','--glob=**/*.sh','--glob=**/*.bat','--glob=**/*.cmd','--glob=**/*.ps1') }
    'web' { $args += @('--glob=**/*.html','--glob=**/*.htm','--glob=**/*.xhtml','--glob=**/*.css','--glob=**/*.js','--glob=**/*.ts','--glob=**/*.jsx','--glob=**/*.tsx') }
    'java' { $args += @('--glob=**/*.java') }
    'javascript' { $args += @('--glob=**/*.js','--glob=**/*.ts','--glob=**/*.jsx','--glob=**/*.tsx') }
    'xhtml' { $args += @('--glob=**/*.xhtml','--glob=**/*.html','--glob=**/*.htm') }
    'css' { $args += @('--glob=**/*.css') }
    'sql' { $args += @('--glob=**/*.sql') }
    'xml' { $args += @('--glob=**/*.xml') }
    default { throw "Unknown profile: $Profile" }
  }

  return $args
}

function Run-ContentSearch([string]$Profile, [string]$Query, [string]$OutFile) {
  $args = Get-ContentArgs -Profile $Profile
  $args += @('--', $Query, '.')
  $results = & rg @args
  $results | Set-Content -Encoding UTF8 $OutFile
}

function Run-FilenameSearch([string]$Profile, [string]$Query, [string]$OutFile) {
  $args = @('--files')
  $args += Get-CommonExcludeGlobs
  switch ($Profile) {
    'filename' { }
    'x_filename' { }
    'java_filename' { $args += @('--glob=**/*.java') }
    'jar' { $args += @('--glob=**/*.jar') }
    'docs' { $args += @('--glob=**/*.doc','--glob=**/*.docx','--glob=**/*.pdf','--glob=**/*.ppt','--glob=**/*.pptx','--glob=**/*.xls','--glob=**/*.xlsx') }
    default { throw "Unknown profile: $Profile" }
  }

  $files = & rg @args
  $matches = $files | & rg --smart-case --color=never -- $Query
  $matches | Set-Content -Encoding UTF8 $OutFile
}

function Add-HtmlHeader([System.Text.StringBuilder]$sb, [string]$Query, [string]$Profile) {
  [void]$sb.AppendLine('<!doctype html>')
  [void]$sb.AppendLine('<html lang="en"><head>')
  [void]$sb.AppendLine('<meta charset="utf-8"/>')
  [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1"/>')
  [void]$sb.AppendLine('<title>extended-grep results</title>')
  [void]$sb.AppendLine('<style>')
  [void]$sb.AppendLine(':root{--bg:#0b1220;--panel:#111a2b;--panel-border:#243349;--muted:#9fb0c8;--path:#7dd3fc;--line:#a78bfa;--col:#f9a8d4;--text:#e2e8f0;--match-bg:#fde047;--match-fg:#111827;}')
  [void]$sb.AppendLine('*{box-sizing:border-box;} body{margin:0;padding:20px;font-family:Consolas,Menlo,monospace;background:var(--bg);color:var(--text);}')
  [void]$sb.AppendLine('h1{margin:0 0 8px;font-size:20px;} .meta{color:var(--muted);margin-bottom:16px;}')
  [void]$sb.AppendLine('.file{background:var(--panel);border:1px solid var(--panel-border);border-radius:10px;margin:0 0 14px;overflow:hidden;}')
  [void]$sb.AppendLine('.file-header{padding:10px 12px;border-bottom:1px solid var(--panel-border);color:var(--path);font-weight:700;}')
  [void]$sb.AppendLine('.row{display:grid;grid-template-columns:70px 70px 1fr;gap:8px;padding:6px 12px;align-items:start;}')
  [void]$sb.AppendLine('.row.match{background:rgba(125,211,252,0.08);} .row.context{background:rgba(148,163,184,0.06);}')
  [void]$sb.AppendLine('.line{color:var(--line);} .col{color:var(--col);} .text{white-space:pre-wrap;word-break:break-word;}')
  [void]$sb.AppendLine('.separator{border-top:1px dashed #334155;}')
  [void]$sb.AppendLine('.file-list{list-style:none;margin:0;padding:0;} .file-list li{padding:8px 12px;border-top:1px solid var(--panel-border);color:var(--path);word-break:break-all;}')
  [void]$sb.AppendLine('mark.hit{background:var(--match-bg);color:var(--match-fg);padding:0 2px;border-radius:3px;font-weight:700;}')
  [void]$sb.AppendLine('.empty{background:var(--panel);border:1px solid var(--panel-border);padding:12px;border-radius:10px;color:var(--muted);}')
  [void]$sb.AppendLine('</style></head>')
  [void]$sb.AppendLine("<body data-query=\"$(Escape-Html $Query)\">")
  [void]$sb.AppendLine('<h1>extended-grep</h1>')
  [void]$sb.AppendLine("<div class=\"meta\">profile: <strong>$(Escape-Html $Profile)</strong> | query: <strong>$(Escape-Html $Query)</strong></div>")
}

function Add-HtmlFooter([System.Text.StringBuilder]$sb) {
  [void]$sb.AppendLine('<script>')
  [void]$sb.AppendLine('(function () {')
  [void]$sb.AppendLine('  const query = document.body.dataset.query || "";')
  [void]$sb.AppendLine('  if (!query) return;')
  [void]$sb.AppendLine('  function escapeRegex(value) { return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }')
  [void]$sb.AppendLine('  function highlight(selector, className) {')
  [void]$sb.AppendLine('    const re = new RegExp(escapeRegex(query), "ig");')
  [void]$sb.AppendLine('    document.querySelectorAll(selector).forEach((el) => {')
  [void]$sb.AppendLine('      const text = el.textContent;')
  [void]$sb.AppendLine('      if (!text) return;')
  [void]$sb.AppendLine('      re.lastIndex = 0;')
  [void]$sb.AppendLine('      if (!re.test(text)) return;')
  [void]$sb.AppendLine('      el.textContent = "";')
  [void]$sb.AppendLine('      re.lastIndex = 0;')
  [void]$sb.AppendLine('      let last = 0;')
  [void]$sb.AppendLine('      let m;')
  [void]$sb.AppendLine('      while ((m = re.exec(text)) !== null) {')
  [void]$sb.AppendLine('        if (m.index > last) { el.appendChild(document.createTextNode(text.slice(last, m.index))); }')
  [void]$sb.AppendLine('        const mark = document.createElement("mark");')
  [void]$sb.AppendLine('        mark.className = className;')
  [void]$sb.AppendLine('        mark.textContent = m[0];')
  [void]$sb.AppendLine('        el.appendChild(mark);')
  [void]$sb.AppendLine('        last = m.index + m[0].length;')
  [void]$sb.AppendLine('      }')
  [void]$sb.AppendLine('      if (last < text.length) { el.appendChild(document.createTextNode(text.slice(last))); }')
  [void]$sb.AppendLine('    });')
  [void]$sb.AppendLine('  }')
  [void]$sb.AppendLine("  highlight('.text', 'hit');")
  [void]$sb.AppendLine("  highlight('.file-header', 'hit');")
  [void]$sb.AppendLine("  highlight('.file-list li', 'hit');")
  [void]$sb.AppendLine('})();')
  [void]$sb.AppendLine('</script>')
  [void]$sb.AppendLine('</body></html>')
}

function Add-ContentResults([System.Text.StringBuilder]$sb, [string[]]$Lines) {
  if ($Lines.Count -eq 0) {
    [void]$sb.AppendLine('<div class="empty">No matches found.</div>')
    return
  }

  $currentFile = ''
  foreach ($line in $Lines) {
    if ($line -eq '--') {
      if (-not [string]::IsNullOrWhiteSpace($currentFile)) {
        [void]$sb.AppendLine('<div class="separator"></div>')
      }
      continue
    }

    if ($line -match '^(.*):(\d+):(\d+):(.*)$') {
      $filePath = $Matches[1]
      $lineNo = $Matches[2]
      $colNo = $Matches[3]
      $text = $Matches[4]

      if ($filePath -ne $currentFile) {
        if (-not [string]::IsNullOrWhiteSpace($currentFile)) {
          [void]$sb.AppendLine('</div>')
        }
        $currentFile = $filePath
        [void]$sb.AppendLine('<div class="file">')
        [void]$sb.AppendLine("<div class=\"file-header\">$(Escape-Html $filePath)</div>")
      }

      [void]$sb.AppendLine("<div class=\"row match\"><span class=\"line\">$(Escape-Html $lineNo)</span><span class=\"col\">$(Escape-Html $colNo)</span><span class=\"text\">$(Escape-Html $text)</span></div>")
      continue
    }

    if ($line -match '^(.*)-(\d+)-(\d+)-(.*)$') {
      $filePath = $Matches[1]
      $lineNo = $Matches[2]
      $colNo = $Matches[3]
      $text = $Matches[4]

      if ($filePath -ne $currentFile) {
        if (-not [string]::IsNullOrWhiteSpace($currentFile)) {
          [void]$sb.AppendLine('</div>')
        }
        $currentFile = $filePath
        [void]$sb.AppendLine('<div class="file">')
        [void]$sb.AppendLine("<div class=\"file-header\">$(Escape-Html $filePath)</div>")
      }

      [void]$sb.AppendLine("<div class=\"row context\"><span class=\"line\">$(Escape-Html $lineNo)</span><span class=\"col\">$(Escape-Html $colNo)</span><span class=\"text\">$(Escape-Html $text)</span></div>")
      continue
    }

    if ($line -match '^(.*)-(\d+)-(.*)$') {
      $filePath = $Matches[1]
      $lineNo = $Matches[2]
      $text = $Matches[3]

      if ($filePath -ne $currentFile) {
        if (-not [string]::IsNullOrWhiteSpace($currentFile)) {
          [void]$sb.AppendLine('</div>')
        }
        $currentFile = $filePath
        [void]$sb.AppendLine('<div class="file">')
        [void]$sb.AppendLine("<div class=\"file-header\">$(Escape-Html $filePath)</div>")
      }

      [void]$sb.AppendLine("<div class=\"row context\"><span class=\"line\">$(Escape-Html $lineNo)</span><span class=\"col\">-</span><span class=\"text\">$(Escape-Html $text)</span></div>")
      continue
    }

    if (-not [string]::IsNullOrWhiteSpace($currentFile)) {
      [void]$sb.AppendLine("<div class=\"row context\"><span class=\"line\">-</span><span class=\"col\">-</span><span class=\"text\">$(Escape-Html $line)</span></div>")
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($currentFile)) {
    [void]$sb.AppendLine('</div>')
  }
}

function Add-FilenameResults([System.Text.StringBuilder]$sb, [string[]]$Lines) {
  if ($Lines.Count -eq 0) {
    [void]$sb.AppendLine('<div class="empty">No files found.</div>')
    return
  }

  [void]$sb.AppendLine('<div class="file">')
  [void]$sb.AppendLine('<div class="file-header">Matching files</div>')
  [void]$sb.AppendLine('<ul class="file-list">')
  foreach ($line in $Lines) {
    [void]$sb.AppendLine("<li>$(Escape-Html $line)</li>")
  }
  [void]$sb.AppendLine('</ul>')
  [void]$sb.AppendLine('</div>')
}

function Render-Html([string]$InFile, [string]$OutFile, [string]$Query, [string]$Profile) {
  $lines = @()
  if (Test-Path $InFile) {
    $lines = Get-Content -Path $InFile
  }

  $sb = [System.Text.StringBuilder]::new()
  Add-HtmlHeader -sb $sb -Query $Query -Profile $Profile

  if (Is-FilenameProfile $Profile) {
    Add-FilenameResults -sb $sb -Lines $lines
  } else {
    Add-ContentResults -sb $sb -Lines $lines
  }

  Add-HtmlFooter -sb $sb
  $sb.ToString() | Set-Content -Path $OutFile -Encoding UTF8
}

if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
  throw 'ripgrep (rg) is required but not installed.'
}

if ([string]::IsNullOrWhiteSpace($Arg1)) {
  Show-Usage
  exit 1
}

$profile = 'grepx'
$query = $Arg1
if (-not [string]::IsNullOrWhiteSpace($Arg2)) {
  $profile = $Arg1
  $query = $Arg2
}

$resultsDir = Join-Path $HOME 'search-results'
New-Item -Path $resultsDir -ItemType Directory -Force | Out-Null

$safeQuery = Safe-Name $query
if ($profile -eq 'grepx') {
  $outputFile = Join-Path $resultsDir "$safeQuery.grepx.html"
} else {
  $outputFile = Join-Path $resultsDir "$safeQuery.$profile.html"
}

$tempFile = [System.IO.Path]::GetTempFileName()
try {
  if (Is-FilenameProfile $profile) {
    Write-Host "Searching \"$query\" using filename profile \"$profile\"..."
    Run-FilenameSearch -Profile $profile -Query $query -OutFile $tempFile
  } else {
    Write-Host "Searching \"$query\" using content profile \"$profile\"..."
    Run-ContentSearch -Profile $profile -Query $query -OutFile $tempFile
  }

  Render-Html -InFile $tempFile -OutFile $outputFile -Query $query -Profile $profile
  Write-Host "Result saved to: $outputFile"
} finally {
  Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
}
