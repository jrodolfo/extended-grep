# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added
- Shared profile/default configuration in `config/search-profiles.conf` used by both shell and PowerShell implementations.
- `--profile-list` option in `search.sh` and `search.ps1`.
- `--version` and `--open` options in `search.sh` and `search.ps1`.
- `--format html|txt` option in `search.sh` and `search.ps1` (default remains HTML).
- Linux installer script `install-linux.sh`.
- Linux smoke test entrypoint `tests/smoke.tests.linux.sh`.
- `Makefile` targets for `help`, `test-mac`, `test-ps`, `test`, and `run`.
- GitHub Actions CI workflow for Linux, macOS, and Windows smoke tests.
- macOS smoke test script `tests/smoke.tests.mac.sh` with deterministic fixture assertions.

### Changed
- Search profile definitions and default limits now come from a single source of truth (`config/search-profiles.conf`).
- README now documents Linux installation, make-based workflow, visual examples, and Windows make installation notes.
- PowerShell smoke tests updated for Pester 5 syntax and compatibility.

### Fixed
- Robust parsing of ripgrep output to avoid path/content corruption when lines contain `-` or `:`.
- Correct file grouping and per-file hit counters (`hit X of Y`).
- Context rows are no longer rendered after the final hit in a file section.
