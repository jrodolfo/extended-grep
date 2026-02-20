$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = (Resolve-Path (Join-Path $scriptDir '../..')).Path
$runtimeDir = Join-Path $repoDir 'scripts/runtime'
$installHome = if ($env:SEARCH_HOME_OVERRIDE) { $env:SEARCH_HOME_OVERRIDE } else { $HOME }
$targetDir = Join-Path $installHome '.extended-grep'
New-Item -Path $targetDir -ItemType Directory -Force | Out-Null

if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
  throw 'ripgrep (rg) is required. Install from https://github.com/BurntSushi/ripgrep/releases or winget install BurntSushi.ripgrep.MSVC'
}

Copy-Item (Join-Path $runtimeDir 'search.ps1') (Join-Path $targetDir 'search.ps1') -Force
New-Item -Path (Join-Path $targetDir 'config') -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $repoDir 'config/search-profiles.conf') (Join-Path $targetDir 'config/search-profiles.conf') -Force

$profilePath = if ($env:SEARCH_PROFILE_PATH) { $env:SEARCH_PROFILE_PATH } else { $PROFILE }
$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) {
  New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $profilePath)) {
  New-Item -Path $profilePath -ItemType File -Force | Out-Null
}

$profileStart = '# >>> extended-grep >>>'
$profileEnd = '# <<< extended-grep <<<'
$searchScriptPath = Join-Path $targetDir 'search.ps1'
$searchFunction = "function search { & '$searchScriptPath' `@args }"
$searchFunctionBody = "& '$searchScriptPath' `@args"
$managedBlock = @"
$profileStart
$searchFunction
$profileEnd
"@

$content = ''
$rawContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
if ($null -ne $rawContent) {
  $content = [string]$rawContent
}
$managedPattern = "(?ms)^\s*# >>> extended-grep >>>.*?# <<< extended-grep <<<\s*"
if ($content -match $managedPattern) {
  $updated = [regex]::Replace($content, $managedPattern, "$managedBlock`r`n")
  Set-Content -Path $profilePath -Value $updated
} elseif ($content -notmatch [regex]::Escape($searchFunction)) {
  Add-Content -Path $profilePath -Value "`n$managedBlock`n"
}

# Also define in the current session so `search` works right after install.
Set-Item -Path Function:\global:search -Value $searchFunctionBody

Write-Host "Installed search.ps1 to $targetDir"
Write-Host 'Added/updated search function in your PowerShell profile.'
if (Get-Command search -ErrorAction SilentlyContinue) {
  Write-Host 'search is ready in this session. Try: search STRING'
} else {
  Write-Warning 'search is not available in this session. Run: . $PROFILE'
  Write-Warning 'If that fails, ensure this shell is not running with -NoProfile.'
}
