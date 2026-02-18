Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'search.ps1 smoke tests' {
  BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:searchScript = Join-Path $script:repoRoot 'search.ps1'
    $script:testRoot = Join-Path $script:repoRoot '.tmp-test-home'
    $script:resultsDir = Join-Path $script:testRoot 'search-results'
    $script:originalResultsDir = $env:SEARCH_RESULTS_DIR

    if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
      throw 'ripgrep (rg) is required for smoke tests.'
    }

    if (-not (Test-Path $script:searchScript)) {
      throw "search.ps1 not found at $script:searchScript"
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
}
