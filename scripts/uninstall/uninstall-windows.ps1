$ErrorActionPreference = 'Stop'

$installHome = if ($env:SEARCH_HOME_OVERRIDE) { $env:SEARCH_HOME_OVERRIDE } else { $HOME }
$targetDir = Join-Path $installHome '.extended-grep'
$targetScript = Join-Path $targetDir 'search.ps1'
$targetConfigFile = Join-Path $targetDir 'config/search-profiles.conf'
$targetConfigDir = Join-Path $targetDir 'config'
$profilePath = if ($env:SEARCH_PROFILE_PATH) { $env:SEARCH_PROFILE_PATH } else { $PROFILE }
$aliasLine = "function search { & '$targetDir/search.ps1' @args }"

function Remove-FileIfExists([string]$Path) {
  if (Test-Path $Path) {
    Remove-Item -Path $Path -Force
    Write-Host "Removed: $Path"
  } else {
    Write-Host "Already absent: $Path"
  }
}

Remove-FileIfExists $targetScript
Remove-FileIfExists $targetConfigFile

if (Test-Path $targetConfigDir) {
  $children = Get-ChildItem -Path $targetConfigDir -Force -ErrorAction SilentlyContinue
  if ($children.Count -eq 0) {
    Remove-Item -Path $targetConfigDir -Force
    Write-Host "Removed empty directory: $targetConfigDir"
  }
}

if (Test-Path $targetDir) {
  $children = Get-ChildItem -Path $targetDir -Force -ErrorAction SilentlyContinue
  if ($children.Count -eq 0) {
    Remove-Item -Path $targetDir -Force
    Write-Host "Removed empty directory: $targetDir"
  }
}

if (Test-Path $profilePath) {
  $lines = Get-Content -Path $profilePath
  $filtered = @($lines | Where-Object { $_ -ne $aliasLine -and $_ -ne '# extended-grep' })
  Set-Content -Path $profilePath -Value $filtered
  Write-Host "Updated PowerShell profile: $profilePath"
}

Write-Host "Uninstall complete."
