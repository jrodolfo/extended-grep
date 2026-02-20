Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'search.ps1 smoke tests' {
  BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:searchScript = Join-Path $script:repoRoot 'scripts/runtime/search.ps1'
    $script:configFile = Join-Path $script:repoRoot 'config/search-profiles.conf'
    $script:testRoot = Join-Path $script:repoRoot '.tmp-test-home'
    $script:resultsDir = Join-Path $script:testRoot 'search-results'
    $script:originalResultsDir = $env:SEARCH_RESULTS_DIR

    if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
      throw 'ripgrep (rg) is required for smoke tests.'
    }

    if (-not (Test-Path $script:searchScript)) {
      throw "search.ps1 not found at $script:searchScript"
    }
    if (-not (Test-Path $script:configFile)) {
      throw "search config not found at $script:configFile"
    }

    if (Test-Path $script:testRoot) {
      Remove-Item -Path $script:testRoot -Recurse -Force
    }

    New-Item -Path $script:resultsDir -ItemType Directory -Force | Out-Null
    $env:SEARCH_RESULTS_DIR = $script:resultsDir

    function script:Remove-OutputFile([string]$Path) {
      if (Test-Path $Path) {
        Remove-Item -Path $Path -Force
      }
    }
  }

  AfterAll {
    if ([string]::IsNullOrWhiteSpace($script:originalResultsDir)) {
      Remove-Item Env:SEARCH_RESULTS_DIR -ErrorAction SilentlyContinue
    } else {
      $env:SEARCH_RESULTS_DIR = $script:originalResultsDir
    }

    if (Test-Path $script:testRoot) {
      Remove-Item -Path $script:testRoot -Recurse -Force
    }
  }

  It 'creates HTML output for default profile search' {
    $query = 'extended-grep'
    $outputFile = Join-Path $script:resultsDir "$query.grepx.html"
    Remove-OutputFile $outputFile
    { & $script:searchScript $query } | Should -Not -Throw

    (Test-Path $outputFile) | Should -Be $true
    (Get-Content -Path $outputFile -Raw) | Should -Match 'extended-grep'
  }

  It 'creates HTML output for filename profile search' {
    $query = 'search.ps1'
    $outputFile = Join-Path $script:resultsDir "$query.filename.html"
    Remove-OutputFile $outputFile
    { & $script:searchScript 'filename' $query } | Should -Not -Throw

    (Test-Path $outputFile) | Should -Be $true
    (Get-Content -Path $outputFile -Raw) | Should -Match 'Matching files'
  }

  It 'handles no-content matches without crashing' {
    $query = [Guid]::NewGuid().ToString('N')
    { & $script:searchScript 'code' $query } | Should -Not -Throw

    $outputFile = Join-Path $script:resultsDir "$query.code.html"
    (Test-Path $outputFile) | Should -Be $true
    (Get-Content -Path $outputFile -Raw) | Should -Match 'No matches found.'
  }

  It 'handles no-filename matches without crashing' {
    $query = [Guid]::NewGuid().ToString('N')
    { & $script:searchScript 'filename' $query } | Should -Not -Throw

    $outputFile = Join-Path $script:resultsDir "$query.filename.html"
    (Test-Path $outputFile) | Should -Be $true
    (Get-Content -Path $outputFile -Raw) | Should -Match 'No files found.'
  }

  It 'prints profile list from shared config' {
    $output = & $script:searchScript '--profile-list'
    ($output -join "`n") | Should -Match 'grepx'
    ($output -join "`n") | Should -Match 'filename'
  }

  It 'creates TXT output for content search' {
    $query = 'extended-grep'
    $outputFile = Join-Path $script:resultsDir "$query.grepx.txt"
    Remove-OutputFile $outputFile
    { & $script:searchScript '--format' 'txt' $query } | Should -Not -Throw

    (Test-Path $outputFile) | Should -Be $true
    $content = Get-Content -Path $outputFile -Raw
    $content | Should -Match 'profile: grepx'
    $content | Should -Match 'hit [0-9]+ of [0-9]+'
    $content | Should -Match '\[\['
  }

  It 'creates TXT output for filename search' {
    $query = 'search.ps1'
    $outputFile = Join-Path $script:resultsDir "$query.filename.txt"
    Remove-OutputFile $outputFile
    { & $script:searchScript '--format' 'txt' 'filename' $query } | Should -Not -Throw

    (Test-Path $outputFile) | Should -Be $true
    (Get-Content -Path $outputFile -Raw) | Should -Match '\(file [0-9]+ of [0-9]+\)'
  }

  It 'handles punctuation query across diverse fixture types in TXT mode' {
    $query = 'fox, '
    $outputFile = Join-Path $script:resultsDir 'fox_.grepx.txt'
    Remove-OutputFile $outputFile

    Push-Location (Join-Path $script:repoRoot 'scripts/tests/documents/diverse')
    try {
      { & $script:searchScript '--format' 'txt' $query } | Should -Not -Throw
    } finally {
      Pop-Location
    }

    (Test-Path $outputFile) | Should -Be $true
    $content = Get-Content -Path $outputFile -Raw
    $content | Should -Match 'sample.json'
    $content | Should -Match 'sample.xml'
    $content | Should -Match 'sample.yaml'
    $content | Should -Match 'sample.csv'
    $content | Should -Match 'file with spaces.txt'
    $content | Should -Match '\[\[fox, \]\]'
  }

  It 'enforces --max-per-file in TXT mode' {
    $query = 'fox'
    $outputFile = Join-Path $script:resultsDir "$query.grepx.txt"
    Remove-OutputFile $outputFile

    Push-Location (Join-Path $script:repoRoot 'scripts/tests/documents/limits')
    try {
      {
        & $script:searchScript '--format' 'txt' '--context' '0' '--max-per-file' '2' $query
      } | Should -Not -Throw
    } finally {
      Pop-Location
    }

    (Test-Path $outputFile) | Should -Be $true
    $content = Get-Content -Path $outputFile -Raw
    $content | Should -Match 'hit 1 of 2'
    $content | Should -Match 'hit 2 of 2'
    $content | Should -Not -Match 'hit 3 of'
  }

  It 'enforces --max-scan-lines and --max-render-lines in TXT mode' {
    $query = 'fox'
    $outputFile = Join-Path $script:resultsDir "$query.grepx.txt"
    Remove-OutputFile $outputFile

    Push-Location (Join-Path $script:repoRoot 'scripts/tests/documents/limits')
    try {
      {
        & $script:searchScript '--format' 'txt' '--context' '0' '--max-per-file' '0' '--max-scan-lines' '5' '--max-render-lines' '3' $query
      } | Should -Not -Throw
    } finally {
      Pop-Location
    }

    (Test-Path $outputFile) | Should -Be $true
    $content = Get-Content -Path $outputFile -Raw
    $content | Should -Match 'output truncated to 3 lines \(original: 5\)'
    $content | Should -Match 'hit 3 of 3'
  }

  It 'runs windows install and uninstall scripts in isolated home/profile' {
    $installScript = Join-Path $script:repoRoot 'scripts/install/install-windows.ps1'
    $uninstallScript = Join-Path $script:repoRoot 'scripts/uninstall/uninstall-windows.ps1'
    $isolatedHome = Join-Path $script:testRoot 'ps-home'
    $isolatedProfile = Join-Path $isolatedHome 'Documents/PowerShell/Microsoft.PowerShell_profile.ps1'
    New-Item -Path (Split-Path -Parent $isolatedProfile) -ItemType Directory -Force | Out-Null
    New-Item -Path $isolatedProfile -ItemType File -Force | Out-Null

    $originalHome = $env:HOME
    $originalProfileOverride = $env:SEARCH_PROFILE_PATH
    $originalHomeOverride = $env:SEARCH_HOME_OVERRIDE
    try {
      $env:HOME = $isolatedHome
      $env:SEARCH_HOME_OVERRIDE = $isolatedHome
      $env:SEARCH_PROFILE_PATH = $isolatedProfile

      { & $installScript } | Should -Not -Throw
      (Test-Path (Join-Path $isolatedHome '.extended-grep/search.ps1')) | Should -Be $true
      (Test-Path (Join-Path $isolatedHome '.extended-grep/config/search-profiles.conf')) | Should -Be $true
      (Get-Content -Path $isolatedProfile -Raw) | Should -Match 'function search'

      { & $uninstallScript } | Should -Not -Throw
      (Test-Path (Join-Path $isolatedHome '.extended-grep/search.ps1')) | Should -Be $false
      (Test-Path (Join-Path $isolatedHome '.extended-grep/config/search-profiles.conf')) | Should -Be $false
      (Get-Content -Path $isolatedProfile -Raw) | Should -Not -Match 'function search'
    } finally {
      if ([string]::IsNullOrWhiteSpace($originalHome)) {
        Remove-Item Env:HOME -ErrorAction SilentlyContinue
      } else {
        $env:HOME = $originalHome
      }
      if ([string]::IsNullOrWhiteSpace($originalProfileOverride)) {
        Remove-Item Env:SEARCH_PROFILE_PATH -ErrorAction SilentlyContinue
      } else {
        $env:SEARCH_PROFILE_PATH = $originalProfileOverride
      }
      if ([string]::IsNullOrWhiteSpace($originalHomeOverride)) {
        Remove-Item Env:SEARCH_HOME_OVERRIDE -ErrorAction SilentlyContinue
      } else {
        $env:SEARCH_HOME_OVERRIDE = $originalHomeOverride
      }
    }
  }
}
