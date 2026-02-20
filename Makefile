.DEFAULT_GOAL := help

.PHONY: help test test-mac test-linux test-ps run

help:
	@echo "Available targets:"
	@echo "  make test                 - Run all tests"
	@echo "  make test-mac             - Run bash smoke tests"
	@echo "  make test-linux           - Run Linux bash smoke tests"
	@echo "  make test-ps              - Run PowerShell smoke tests"
	@echo "  make run ARGS=\"...\"       - Run extended-grep (e.g. ARGS=\"fox\")"

test: test-mac test-ps

test-mac:
	bash ./scripts/tests/smoke.tests.mac.sh

test-linux:
	bash ./scripts/tests/smoke.tests.linux.sh

test-ps:
	pwsh -NoProfile -Command "Invoke-Pester ./scripts/tests/smoke.tests.windows.ps1"

run:
	bash ./scripts/runtime/search.sh $(ARGS)
