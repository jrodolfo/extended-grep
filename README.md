# extended-grep

`extended-grep` is a wrapper around `rg` (ripgrep) that saves search results as HTML files in `~/search-results`.

## Features

- Recursive project search with profiles (`grepx`, `code`, `xml`, `filename`, etc.)
- Colorized HTML output per search for faster visual scanning
- Works on macOS and Windows

## Prerequisites

- ripgrep (`rg`) installed and available on `PATH`

macOS:

```bash
brew install ripgrep
```

Windows (PowerShell):

```powershell
winget install BurntSushi.ripgrep.MSVC
```

## Install on macOS

1. Clone this repository.
2. Run:

```bash
./install-macos.sh
```

3. Open a new terminal and run:

```bash
search additionalId
```

## Install on Windows (PowerShell)

1. Clone this repository.
2. Run in PowerShell:

```powershell
./install-windows.ps1
```

3. If script execution is blocked, run once (current user):

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

4. Open a new PowerShell window and run:

```powershell
search additionalId
```

## Usage

```bash
search STRING
search PROFILE STRING
```

Profiles:

- `grepx` (default)
- `codescan`
- `android`
- `code`
- `web`
- `java`
- `java_filename`
- `javascript`
- `xhtml`
- `css`
- `sql`
- `xml`
- `docs`
- `filename`
- `x_filename`
- `jar`

Examples:

```bash
search additionalId
search xml Transaction-ID
search filename p-dcs-flightsummary
```

Each run creates an HTML file in `~/search-results`.

Optional override:

- Set `SEARCH_RESULTS_DIR` to write results to a custom directory.

## Notes

- The generated HTML is plain and portable (no browser plugins required).
- File naming is sanitized for cross-platform compatibility.
- You can still run scripts directly from the repo:

macOS/Linux shell:

```bash
./search.sh STRING
./search.sh PROFILE STRING
```

Windows PowerShell:

```powershell
./search.ps1 STRING
./search.ps1 PROFILE STRING
```

## Smoke Tests (Windows PowerShell)

Run Pester smoke tests:

```powershell
Invoke-Pester ./tests/Search.Smoke.Tests.ps1
```
