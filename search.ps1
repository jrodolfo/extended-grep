param(
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$CliArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Version = '2.0.0'
$FieldMatchSep = [string][char]31
$FieldContextSep = [string][char]30
$ContextBlockSep = [string][char]29
$SearchConfigFile = if ($env:SEARCH_CONFIG_FILE) { $env:SEARCH_CONFIG_FILE } else { Join-Path $PSScriptRoot 'config/search-profiles.conf' }

function Show-Usage {
  @"
Usage:
  search STRING
  search PROFILE STRING
  search [OPTIONS] STRING
  search [OPTIONS] PROFILE STRING

Profiles:
  $($script:Profiles -join ', ')

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
"@
}

function Escape-Html([string]$Text) {
  if ($null -eq $Text) { return '' }
  return $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

function Trim-TextForDisplay([string]$Text, [bool]$IsMatch, [string]$Query, [int]$MaxLineLength) {
  if ($MaxLineLength -le 0 -or [string]::IsNullOrEmpty($Text) -or $Text.Length -le $MaxLineLength) {
    return $Text
  }

  if ($IsMatch -and -not [string]::IsNullOrWhiteSpace($Query)) {
    $idx = $Text.IndexOf($Query, [System.StringComparison]::OrdinalIgnoreCase)
    if ($idx -ge 0) {
      $start = $idx - [int]($MaxLineLength / 3)
      $prefix = ''
      if ($start -lt 0) {
        $start = 0
      } else {
        $prefix = '... '
      }
      $len = [Math]::Min($MaxLineLength, $Text.Length - $start)
      return $prefix + $Text.Substring($start, $len) + ' ... [trimmed]'
    }
  }

  return $Text.Substring(0, $MaxLineLength) + ' ... [trimmed]'
}

function Safe-Name([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return 'search' }
  $v = $Text -replace '\s+', '_'
  $v = $v -replace '[^a-zA-Z0-9_.-]', ''
  if ([string]::IsNullOrWhiteSpace($v)) { return 'search' }
  return $v
}

function Read-ConfigMap([string]$Path) {
  if (-not (Test-Path $Path)) {
    throw "Config file not found: $Path"
  }
  $map = @{}
  foreach ($line in Get-Content -Path $Path) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
      continue
    }
    $eq = $trimmed.IndexOf('=')
    if ($eq -lt 0) { continue }
    $key = $trimmed.Substring(0, $eq).Trim()
    $value = $trimmed.Substring($eq + 1)
    $map[$key] = $value
  }
  return $map
}

function Get-ConfigValue([hashtable]$Config, [string]$Key) {
  if (-not $Config.ContainsKey($Key)) {
    throw "Missing config key: $Key"
  }
  return [string]$Config[$Key]
}

function Get-ConfigList([hashtable]$Config, [string]$Key) {
  $raw = Get-ConfigValue -Config $Config -Key $Key
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return @()
  }
  return @($raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-CommonExcludeGlobs {
  return @($script:CommonExcludeGlobs | ForEach-Object { "--glob=$_" })
}

function Is-FilenameProfile([string]$Profile) {
  return $script:FilenameProfiles -contains $Profile
}

function Parse-Int([string]$Value, [string]$Name) {
  $parsed = 0
  if (-not [int]::TryParse($Value, [ref]$parsed) -or $parsed -lt 0) {
    throw "$Name expects a non-negative integer"
  }
  return $parsed
}

function Get-ContentArgs(
  [string]$Profile,
  [bool]$IncludeHidden,
  [int]$ContextLines,
  [int]$MaxPerFile,
  [string]$MaxFileSize
) {
  $args = @('--line-number','--with-filename','--smart-case','--color=never',"-A$ContextLines", "-B$ContextLines")
  if ($IncludeHidden) {
    $args += @('--hidden')
  }
  if ($MaxPerFile -gt 0) {
    $args += @("--max-count=$MaxPerFile")
  }
  if (-not [string]::IsNullOrWhiteSpace($MaxFileSize)) {
    $args += @("--max-filesize=$MaxFileSize")
  }
  $args += @("--field-match-separator=$FieldMatchSep", "--field-context-separator=$FieldContextSep", "--context-separator=$ContextBlockSep")

  $args += Get-CommonExcludeGlobs

  $key = "profile.$Profile.content_globs"
  if (-not $script:Config.ContainsKey($key)) {
    throw "Unknown profile: $Profile"
  }
  $profileGlobs = Get-ConfigList -Config $script:Config -Key $key
  $args += @($profileGlobs | ForEach-Object { "--glob=$_" })

  return $args
}

function Get-FilenameArgs([string]$Profile, [bool]$IncludeHidden) {
  $args = @('--files')
  if ($IncludeHidden) {
    $args += @('--hidden')
  }
  $args += Get-CommonExcludeGlobs

  if (-not (Is-FilenameProfile $Profile)) {
    throw "Unknown profile: $Profile"
  }
  $key = "profile.$Profile.file_globs"
  if ($script:Config.ContainsKey($key)) {
    $profileGlobs = Get-ConfigList -Config $script:Config -Key $key
    $args += @($profileGlobs | ForEach-Object { "--glob=$_" })
  }

  return $args
}

function Run-ContentSearch(
  [string]$Profile,
  [string]$Query,
  [string]$OutFile,
  [bool]$IncludeHidden,
  [int]$ContextLines,
  [int]$MaxPerFile,
  [string]$MaxFileSize,
  [int]$MaxScanLines
) {
  $rgArgs = Get-ContentArgs -Profile $Profile -IncludeHidden $IncludeHidden -ContextLines $ContextLines -MaxPerFile $MaxPerFile -MaxFileSize $MaxFileSize
  $rgArgs += @('--', $Query, '.')
  if ($MaxScanLines -gt 0) {
    $results = & rg @rgArgs | Select-Object -First $MaxScanLines
  } else {
    $results = & rg @rgArgs
  }
  $results | Set-Content -Encoding UTF8 $OutFile
}

function Run-FilenameSearch([string]$Profile, [string]$Query, [string]$OutFile, [bool]$IncludeHidden, [int]$MaxScanLines) {
  $rgArgs = Get-FilenameArgs -Profile $Profile -IncludeHidden $IncludeHidden
  if ($MaxScanLines -gt 0) {
    $files = & rg @rgArgs | Select-Object -First $MaxScanLines
  } else {
    $files = & rg @rgArgs
  }
  $matches = $files | & rg --smart-case --color=never -- $Query
  $matches | Set-Content -Encoding UTF8 $OutFile
}

function Add-HtmlHeader([System.Text.StringBuilder]$sb, [string]$Query, [string]$Profile, [string]$Note) {
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
  [void]$sb.AppendLine('.row .hitmeta{justify-self:end;color:#fcd34d;font-size:12px;}')
  [void]$sb.AppendLine('.row.match{background:rgba(125,211,252,0.08);} .row.context{background:rgba(148,163,184,0.06);}')
  [void]$sb.AppendLine('.line{color:var(--line);} .col{color:var(--col);} .text{white-space:pre-wrap;word-break:break-word;}')
  [void]$sb.AppendLine('.separator{border-top:1px dashed #334155;}')
  [void]$sb.AppendLine('.file-list{list-style:none;margin:0;padding:0;} .file-list li{padding:8px 12px;border-top:1px solid var(--panel-border);color:var(--path);word-break:break-all;}')
  [void]$sb.AppendLine('mark.hit{background:var(--match-bg);color:var(--match-fg);padding:0 2px;border-radius:3px;font-weight:700;}')
  [void]$sb.AppendLine('.empty{background:var(--panel);border:1px solid var(--panel-border);padding:12px;border-radius:10px;color:var(--muted);}')
  [void]$sb.AppendLine('</style></head>')
  [void]$sb.AppendLine("<body data-query=`"$(Escape-Html $Query)`">")
  [void]$sb.AppendLine('<h1>extended-grep</h1>')
  [void]$sb.AppendLine("<div class=`"meta`">profile: <strong>$(Escape-Html $Profile)</strong> | query: <strong>$(Escape-Html $Query)</strong></div>")
  if (-not [string]::IsNullOrWhiteSpace($Note)) {
    [void]$sb.AppendLine("<div class=`"meta`">note: <strong>$(Escape-Html $Note)</strong></div>")
  }
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

function Add-ContentResults([System.Text.StringBuilder]$sb, [string[]]$Lines, [string]$Query, [int]$MaxLineLength) {
  $normalizedLines = @($Lines)
  if ($normalizedLines.Count -eq 0) {
    [void]$sb.AppendLine('<div class="empty">No matches found.</div>')
    return
  }

  $hitsByFile = @{}
  foreach ($line in $normalizedLines) {
    if ($line.Contains($FieldMatchSep)) {
      $parts = $line.Split($FieldMatchSep, 3)
      if ($parts.Count -ge 1) {
        $fileKey = $parts[0]
        if ($hitsByFile.ContainsKey($fileKey)) {
          $hitsByFile[$fileKey] = $hitsByFile[$fileKey] + 1
        } else {
          $hitsByFile[$fileKey] = 1
        }
      }
    }
  }

  $currentFile = ''
  $currentFileHitIndex = 0
  $currentFileHitTotal = 0
  $currentFileIndex = 0
  $totalFiles = $hitsByFile.Keys.Count
  $skipContextAfterLastHit = $false
  foreach ($line in $normalizedLines) {
    if ($line -eq $ContextBlockSep) {
      if (-not [string]::IsNullOrWhiteSpace($currentFile) -and -not $skipContextAfterLastHit) {
        [void]$sb.AppendLine('<div class="separator"></div>')
      }
      continue
    }

    if ($line.Contains($FieldMatchSep)) {
      $parts = $line.Split($FieldMatchSep, 3)
      if ($parts.Count -lt 3) { continue }
      $filePath = $parts[0]
      $lineNo = $parts[1]
      $colNo = '-'
      $text = $parts[2]

      if ($filePath -ne $currentFile) {
        if (-not [string]::IsNullOrWhiteSpace($currentFile)) {
          [void]$sb.AppendLine('</div>')
        }
        $currentFile = $filePath
        $currentFileIndex = $currentFileIndex + 1
        $currentFileHitIndex = 0
        $currentFileHitTotal = if ($hitsByFile.ContainsKey($filePath)) { [int]$hitsByFile[$filePath] } else { 0 }
        $skipContextAfterLastHit = $false
        [void]$sb.AppendLine('<div class="file">')
        [void]$sb.AppendLine("<div class=`"file-header`">(file $currentFileIndex of $totalFiles) $(Escape-Html $filePath)</div>")
      }

      $currentFileHitIndex = $currentFileHitIndex + 1
      $skipContextAfterLastHit = ($currentFileHitIndex -ge $currentFileHitTotal)
      $displayText = Trim-TextForDisplay -Text $text -IsMatch $true -Query $Query -MaxLineLength $MaxLineLength
      [void]$sb.AppendLine("<div class=`"row match`"><span class=`"line`">$(Escape-Html $lineNo)</span><span class=`"col`">$(Escape-Html $colNo)</span><span class=`"text`">$(Escape-Html $displayText)</span><span class=`"hitmeta`">hit $currentFileHitIndex of $currentFileHitTotal</span></div>")
      continue
    }

    if ($line.Contains($FieldContextSep)) {
      $parts = $line.Split($FieldContextSep, 3)
      if ($parts.Count -lt 3) { continue }
      $filePath = $parts[0]
      $lineNo = $parts[1]
      $colNo = '-'
      $text = $parts[2]

      if ($filePath -ne $currentFile) {
        if (-not [string]::IsNullOrWhiteSpace($currentFile)) {
          [void]$sb.AppendLine('</div>')
        }
        $currentFile = $filePath
        $currentFileIndex = $currentFileIndex + 1
        $currentFileHitIndex = 0
        $currentFileHitTotal = if ($hitsByFile.ContainsKey($filePath)) { [int]$hitsByFile[$filePath] } else { 0 }
        $skipContextAfterLastHit = $false
        [void]$sb.AppendLine('<div class="file">')
        [void]$sb.AppendLine("<div class=`"file-header`">(file $currentFileIndex of $totalFiles) $(Escape-Html $filePath)</div>")
      }

      if ($skipContextAfterLastHit) {
        continue
      }

      $displayText = Trim-TextForDisplay -Text $text -IsMatch $false -Query $Query -MaxLineLength $MaxLineLength
      [void]$sb.AppendLine("<div class=`"row context`"><span class=`"line`">$(Escape-Html $lineNo)</span><span class=`"col`">$(Escape-Html $colNo)</span><span class=`"text`">$(Escape-Html $displayText)</span><span class=`"hitmeta`"></span></div>")
      continue
    }

    if (-not [string]::IsNullOrWhiteSpace($currentFile) -and -not $skipContextAfterLastHit) {
      $displayText = Trim-TextForDisplay -Text $line -IsMatch $false -Query $Query -MaxLineLength $MaxLineLength
      [void]$sb.AppendLine("<div class=`"row context`"><span class=`"line`">-</span><span class=`"col`">-</span><span class=`"text`">$(Escape-Html $displayText)</span><span class=`"hitmeta`"></span></div>")
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($currentFile)) {
    [void]$sb.AppendLine('</div>')
  }
}

function Add-FilenameResults([System.Text.StringBuilder]$sb, [string[]]$Lines) {
  $normalizedLines = @($Lines)
  if ($normalizedLines.Count -eq 0) {
    [void]$sb.AppendLine('<div class="empty">No files found.</div>')
    return
  }

  [void]$sb.AppendLine('<div class="file">')
  [void]$sb.AppendLine('<div class="file-header">Matching files</div>')
  [void]$sb.AppendLine('<ul class="file-list">')
  foreach ($line in $normalizedLines) {
    [void]$sb.AppendLine("<li>$(Escape-Html $line)</li>")
  }
  [void]$sb.AppendLine('</ul>')
  [void]$sb.AppendLine('</div>')
}

function Render-Html([string]$InFile, [string]$OutFile, [string]$Query, [string]$Profile, [string]$Note, [int]$MaxLineLength) {
  $lines = @()
  if (Test-Path $InFile) {
    $lines = @(Get-Content -Path $InFile)
  }

  $sb = [System.Text.StringBuilder]::new()
  Add-HtmlHeader -sb $sb -Query $Query -Profile $Profile -Note $Note

  if (Is-FilenameProfile $Profile) {
    Add-FilenameResults -sb $sb -Lines $lines
  } else {
    Add-ContentResults -sb $sb -Lines $lines -Query $Query -MaxLineLength $MaxLineLength
  }

  Add-HtmlFooter -sb $sb
  $sb.ToString() | Set-Content -Path $OutFile -Encoding UTF8
}

function Add-TxtHeader([System.Text.StringBuilder]$sb, [string]$Query, [string]$Profile, [string]$Note) {
  [void]$sb.AppendLine('extended-grep')
  [void]$sb.AppendLine("profile: $Profile")
  [void]$sb.AppendLine("query: $Query")
  if (-not [string]::IsNullOrWhiteSpace($Note)) {
    [void]$sb.AppendLine("note: $Note")
  }
}

function Add-TxtContentResults([System.Text.StringBuilder]$sb, [string[]]$Lines, [string]$Query, [int]$MaxLineLength) {
  $normalizedLines = @($Lines)
  if ($normalizedLines.Count -eq 0) {
    [void]$sb.AppendLine('No matches found.')
    return
  }

  $hitsByFile = @{}
  foreach ($line in $normalizedLines) {
    if ($line.Contains($FieldMatchSep)) {
      $parts = $line.Split($FieldMatchSep, 3)
      if ($parts.Count -ge 1) {
        $fileKey = $parts[0]
        if ($hitsByFile.ContainsKey($fileKey)) {
          $hitsByFile[$fileKey] = $hitsByFile[$fileKey] + 1
        } else {
          $hitsByFile[$fileKey] = 1
        }
      }
    }
  }

  $currentFile = ''
  $currentFileHitIndex = 0
  $currentFileHitTotal = 0
  $currentFileIndex = 0
  $totalFiles = $hitsByFile.Keys.Count
  $skipContextAfterLastHit = $false
  foreach ($line in $normalizedLines) {
    if ($line -eq $ContextBlockSep) {
      if (-not [string]::IsNullOrWhiteSpace($currentFile) -and -not $skipContextAfterLastHit) {
        [void]$sb.AppendLine('  ---')
      }
      continue
    }

    if ($line.Contains($FieldMatchSep)) {
      $parts = $line.Split($FieldMatchSep, 3)
      if ($parts.Count -lt 3) { continue }
      $filePath = $parts[0]
      $lineNo = $parts[1]
      $colNo = '-'
      $text = $parts[2]

      if ($filePath -ne $currentFile) {
        $currentFile = $filePath
        $currentFileIndex = $currentFileIndex + 1
        $currentFileHitIndex = 0
        $currentFileHitTotal = if ($hitsByFile.ContainsKey($filePath)) { [int]$hitsByFile[$filePath] } else { 0 }
        $skipContextAfterLastHit = $false
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("(file $currentFileIndex of $totalFiles) $filePath")
      }

      $currentFileHitIndex = $currentFileHitIndex + 1
      $skipContextAfterLastHit = ($currentFileHitIndex -ge $currentFileHitTotal)
      $displayText = Trim-TextForDisplay -Text $text -IsMatch $true -Query $Query -MaxLineLength $MaxLineLength
      [void]$sb.AppendLine("  $lineNo | $colNo | $displayText (hit $currentFileHitIndex of $currentFileHitTotal)")
      continue
    }

    if ($line.Contains($FieldContextSep)) {
      $parts = $line.Split($FieldContextSep, 3)
      if ($parts.Count -lt 3) { continue }
      $filePath = $parts[0]
      $lineNo = $parts[1]
      $colNo = '-'
      $text = $parts[2]

      if ($filePath -ne $currentFile) {
        $currentFile = $filePath
        $currentFileIndex = $currentFileIndex + 1
        $currentFileHitIndex = 0
        $currentFileHitTotal = if ($hitsByFile.ContainsKey($filePath)) { [int]$hitsByFile[$filePath] } else { 0 }
        $skipContextAfterLastHit = $false
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("(file $currentFileIndex of $totalFiles) $filePath")
      }

      if ($skipContextAfterLastHit) {
        continue
      }

      $displayText = Trim-TextForDisplay -Text $text -IsMatch $false -Query $Query -MaxLineLength $MaxLineLength
      [void]$sb.AppendLine("  $lineNo | $colNo | $displayText")
      continue
    }

    if (-not [string]::IsNullOrWhiteSpace($currentFile) -and -not $skipContextAfterLastHit) {
      $displayText = Trim-TextForDisplay -Text $line -IsMatch $false -Query $Query -MaxLineLength $MaxLineLength
      [void]$sb.AppendLine("  - | - | $displayText")
    }
  }
}

function Add-TxtFilenameResults([System.Text.StringBuilder]$sb, [string[]]$Lines) {
  $normalizedLines = @($Lines)
  if ($normalizedLines.Count -eq 0) {
    [void]$sb.AppendLine('No files found.')
    return
  }

  $totalFiles = $normalizedLines.Count
  $idx = 0
  foreach ($line in $normalizedLines) {
    $idx = $idx + 1
    [void]$sb.AppendLine("(file $idx of $totalFiles) $line")
  }
}

function Render-Txt([string]$InFile, [string]$OutFile, [string]$Query, [string]$Profile, [string]$Note, [int]$MaxLineLength) {
  $lines = @()
  if (Test-Path $InFile) {
    $lines = @(Get-Content -Path $InFile)
  }

  $sb = [System.Text.StringBuilder]::new()
  Add-TxtHeader -sb $sb -Query $Query -Profile $Profile -Note $Note

  if (Is-FilenameProfile $Profile) {
    Add-TxtFilenameResults -sb $sb -Lines $lines
  } else {
    Add-TxtContentResults -sb $sb -Lines $lines -Query $Query -MaxLineLength $MaxLineLength
  }

  [void]$sb.AppendLine('')
  $sb.ToString() | Set-Content -Path $OutFile -Encoding UTF8
}

if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
  throw 'ripgrep (rg) is required but not installed.'
}

$script:Config = Read-ConfigMap -Path $SearchConfigFile
$script:Profiles = Get-ConfigList -Config $script:Config -Key 'profiles.order'
$script:FilenameProfiles = Get-ConfigList -Config $script:Config -Key 'profiles.filename'
$script:CommonExcludeGlobs = Get-ConfigList -Config $script:Config -Key 'common.exclude_globs'
if ($script:Profiles.Count -eq 0) {
  throw 'profiles.order is empty in config.'
}

$includeHidden = $false
$contextLines = Parse-Int -Value (Get-ConfigValue -Config $script:Config -Key 'defaults.context_lines') -Name 'defaults.context_lines'
$maxPerFile = Parse-Int -Value (Get-ConfigValue -Config $script:Config -Key 'defaults.max_per_file') -Name 'defaults.max_per_file'
$maxFileSize = Get-ConfigValue -Config $script:Config -Key 'defaults.max_filesize'
$maxScanLines = Parse-Int -Value (Get-ConfigValue -Config $script:Config -Key 'defaults.max_scan_lines') -Name 'defaults.max_scan_lines'
$maxLineLength = Parse-Int -Value (Get-ConfigValue -Config $script:Config -Key 'defaults.max_line_length') -Name 'defaults.max_line_length'
$maxRenderLines = Parse-Int -Value (Get-ConfigValue -Config $script:Config -Key 'defaults.max_render_lines') -Name 'defaults.max_render_lines'
$openAfter = $false
$outputFormat = 'html'

$positionals = New-Object System.Collections.Generic.List[string]
$i = 0
while ($i -lt $CliArgs.Count) {
  $arg = $CliArgs[$i]
  switch ($arg) {
    '-h' { Show-Usage; exit 0 }
    '--help' { Show-Usage; exit 0 }
    '-v' { Write-Output "extended-grep $Version"; exit 0 }
    '--version' { Write-Output "extended-grep $Version"; exit 0 }
    '--profile-list' { $script:Profiles | ForEach-Object { Write-Output $_ }; exit 0 }
    '--open' { $openAfter = $true }
    '--format' {
      $i++
      if ($i -ge $CliArgs.Count) { throw '--format requires a value' }
      $fmt = $CliArgs[$i].ToLowerInvariant()
      if ($fmt -ne 'html' -and $fmt -ne 'txt') {
        throw "--format expects 'html' or 'txt'"
      }
      $outputFormat = $fmt
    }
    '--deep' { $includeHidden = $true }
    '--hidden' { $includeHidden = $true }
    '--context' {
      $i++
      if ($i -ge $CliArgs.Count) { throw '--context requires a value' }
      $contextLines = Parse-Int -Value $CliArgs[$i] -Name '--context'
    }
    '--max-per-file' {
      $i++
      if ($i -ge $CliArgs.Count) { throw '--max-per-file requires a value' }
      $maxPerFile = Parse-Int -Value $CliArgs[$i] -Name '--max-per-file'
    }
    '--max-filesize' {
      $i++
      if ($i -ge $CliArgs.Count) { throw '--max-filesize requires a value' }
      if ($CliArgs[$i] -eq "none") {
        $maxFileSize = ""
      } else {
        $maxFileSize = $CliArgs[$i]
      }
    }
    '--max-render-lines' {
      $i++
      if ($i -ge $CliArgs.Count) { throw '--max-render-lines requires a value' }
      $maxRenderLines = Parse-Int -Value $CliArgs[$i] -Name '--max-render-lines'
    }
    '--max-line-length' {
      $i++
      if ($i -ge $CliArgs.Count) { throw '--max-line-length requires a value' }
      $maxLineLength = Parse-Int -Value $CliArgs[$i] -Name '--max-line-length'
    }
    '--max-scan-lines' {
      $i++
      if ($i -ge $CliArgs.Count) { throw '--max-scan-lines requires a value' }
      $maxScanLines = Parse-Int -Value $CliArgs[$i] -Name '--max-scan-lines'
    }
    '--' {
      for ($j = $i + 1; $j -lt $CliArgs.Count; $j++) {
        $positionals.Add($CliArgs[$j])
      }
      $i = $CliArgs.Count
      continue
    }
    default {
      if ($arg.StartsWith('-')) {
        throw "Unknown option: $arg"
      }
      $positionals.Add($arg)
    }
  }
  $i++
}

if ($positionals.Count -eq 0) {
  Show-Usage
  exit 0
}

$profile = 'grepx'
$query = ''
if ($positionals.Count -eq 1) {
  $profile = $script:Profiles[0]
  $query = $positionals[0]
} elseif ($positionals.Count -eq 2) {
  $profile = $positionals[0]
  $query = $positionals[1]
} else {
  Show-Usage
  exit 1
}

$resultsDir = if ([string]::IsNullOrWhiteSpace($env:SEARCH_RESULTS_DIR)) { Join-Path $HOME 'search-results' } else { $env:SEARCH_RESULTS_DIR }
New-Item -Path $resultsDir -ItemType Directory -Force | Out-Null

$safeQuery = Safe-Name $query
if ($profile -eq 'grepx') {
  $outputFile = Join-Path $resultsDir "$safeQuery.grepx.$outputFormat"
} else {
  $outputFile = Join-Path $resultsDir "$safeQuery.$profile.$outputFormat"
}

$tempFile = [System.IO.Path]::GetTempFileName()
$tempRenderFile = [System.IO.Path]::GetTempFileName()

$searchTimer = [System.Diagnostics.Stopwatch]::StartNew()
try {
  if (Is-FilenameProfile $profile) {
    Write-Host "Searching \"$query\" using filename profile \"$profile\"..."
    Run-FilenameSearch -Profile $profile -Query $query -OutFile $tempFile -IncludeHidden $includeHidden -MaxScanLines $maxScanLines
  } else {
    Write-Host "Searching \"$query\" using content profile \"$profile\"..."
    Run-ContentSearch -Profile $profile -Query $query -OutFile $tempFile -IncludeHidden $includeHidden -ContextLines $contextLines -MaxPerFile $maxPerFile -MaxFileSize $maxFileSize -MaxScanLines $maxScanLines
  }
  $searchTimer.Stop()

  $lines = @()
  if (Test-Path $tempFile) {
    $lines = @(Get-Content -Path $tempFile)
  }

  $note = ''
  $originalLineCount = $lines.Count
  if ($maxScanLines -gt 0 -and $lines.Count -ge $maxScanLines) {
    $note = "search output reached max scan lines ($maxScanLines)"
  }

  if ($maxRenderLines -gt 0 -and $lines.Count -gt $maxRenderLines) {
    $lines = $lines[0..($maxRenderLines - 1)]
    if ([string]::IsNullOrWhiteSpace($note)) {
      $note = "output truncated to $maxRenderLines lines (original: $originalLineCount)"
    } else {
      $note = "$note; output truncated to $maxRenderLines lines (original: $originalLineCount)"
    }
  }

  $lines | Set-Content -Path $tempRenderFile -Encoding UTF8

  $renderTimer = [System.Diagnostics.Stopwatch]::StartNew()
  if ($outputFormat -eq 'txt') {
    Render-Txt -InFile $tempRenderFile -OutFile $outputFile -Query $query -Profile $profile -Note $note -MaxLineLength $maxLineLength
  } else {
    Render-Html -InFile $tempRenderFile -OutFile $outputFile -Query $query -Profile $profile -Note $note -MaxLineLength $maxLineLength
  }
  $renderTimer.Stop()

  Write-Host "Result saved to: $outputFile"
  Write-Host "Timing: search=$([int]$searchTimer.Elapsed.TotalSeconds)s render=$([int]$renderTimer.Elapsed.TotalSeconds)s"
  if ($openAfter) {
    try {
      Start-Process $outputFile | Out-Null
    } catch {
      Write-Warning "Could not open output file automatically."
    }
  }
} finally {
  Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
  Remove-Item -Path $tempRenderFile -ErrorAction SilentlyContinue
}
