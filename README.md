# extended-grep

`extended-grep` is a wrapper around `rg` (ripgrep) that saves search results as HTML files in `~/search-results`.

## Why use extended-grep

- Better handling for tricky search strings in day-to-day usage (for example: `search "fox, "`).
- Search results are written to HTML reports, so your terminal stays clean even for large searches.

Example:

```bash
search "fox, "
```

This creates an HTML report in `~/search-results`.

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
search a-string
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
search a-string
```

## Usage

```bash
search
search [OPTIONS] STRING
search [OPTIONS] PROFILE STRING
```

Running `search` with no arguments prints the help with all options.

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
search a-string
search --deep a-string
search --max-per-file 50 a-string
search xml another-string
search filename part-of-file-name
```

Options:

- `--deep` or `--hidden`: include hidden files/directories (slower)
- `--context N`: context lines before/after each hit (default `3`)
- `--max-per-file N`: limit matches per file (default `200`, `0` disables limit)
- `--max-filesize SIZE`: skip files larger than `SIZE` (default `1M`, use `none` to disable)
- `--max-scan-lines N`: cap lines collected from `rg` before rendering (default `20000`, `0` disables cap)
- `--max-line-length N`: trim very long result lines before rendering (default `2000`, `0` disables trimming)
- `--max-render-lines N`: cap rendered HTML lines (default `12000`, `0` disables cap)

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
