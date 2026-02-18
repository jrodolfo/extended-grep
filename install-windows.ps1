$ErrorActionPreference = 'Stop'

$repoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetDir = Join-Path $HOME '.extended-grep'
New-Item -Path $targetDir -ItemType Directory -Force | Out-Null

if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
  throw 'ripgrep (rg) is required. Install from https://github.com/BurntSushi/ripgrep/releases or winget install BurntSushi.ripgrep.MSVC'
}

Copy-Item (Join-Path $repoDir 'search.ps1') (Join-Path $targetDir 'search.ps1') -Force
New-Item -Path (Join-Path $targetDir 'config') -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $repoDir 'config/search-profiles.conf') (Join-Path $targetDir 'config/search-profiles.conf') -Force

$profilePath = $PROFILE
$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) {
  New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $profilePath)) {
  New-Item -Path $profilePath -ItemType File -Force | Out-Null
}

$aliasLine = "function search { & '$targetDir/search.ps1' @args }"
$content = Get-Content -Path $profilePath -Raw
if ($content -notmatch [regex]::Escape($aliasLine)) {
  Add-Content -Path $profilePath -Value "`n# extended-grep`n$aliasLine`n"
}

Write-Host "Installed search.ps1 to $targetDir"
Write-Host 'Open a new PowerShell window, then run: search STRING'
