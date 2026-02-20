.DEFAULT_GOAL := help

.PHONY: help test test-mac test-linux test-ps run uninstall-mac uninstall-linux uninstall-windows

help:
	@echo "Available targets:"
	@echo "  make test                 - Run all tests"
	@echo "  make test-mac             - Run bash smoke tests"
	@echo "  make test-linux           - Run Linux bash smoke tests"
	@echo "  make test-ps              - Run PowerShell smoke tests"
	@echo "  make run ARGS=\"...\"       - Run extended-grep (e.g. ARGS=\"fox\")"
	@echo "  make uninstall-mac        - Uninstall from macOS user home"
	@echo "  make uninstall-linux      - Uninstall from Linux user home"
	@echo "  make uninstall-windows    - Uninstall from Windows user home (pwsh)"

test: test-mac test-ps

test-mac:
	bash ./scripts/tests/smoke.tests.mac.sh

test-linux:
	bash ./scripts/tests/smoke.tests.linux.sh

test-ps:
	pwsh -NoProfile -Command "Invoke-Pester ./scripts/tests/smoke.tests.windows.ps1"

run:
	bash ./scripts/runtime/search.sh $(ARGS)

uninstall-mac:
	bash ./scripts/uninstall/uninstall-macos.sh

uninstall-linux:
	bash ./scripts/uninstall/uninstall-linux.sh

uninstall-windows:
	pwsh -NoProfile -Command "& ./scripts/uninstall/uninstall-windows.ps1"
