.DEFAULT_GOAL := help

.PHONY: help test test-mac test-ps run

help:
	@echo "Available targets:"
	@echo "  make test                 - Run all tests"
	@echo "  make test-mac             - Run bash smoke tests"
	@echo "  make test-ps              - Run PowerShell smoke tests"
	@echo "  make run ARGS=\"...\"       - Run extended-grep (e.g. ARGS=\"fox\")"

test: test-mac test-ps

test-mac:
	bash ./tests/smoke.tests.sh

test-ps:
	pwsh -NoProfile -Command "Invoke-Pester ./tests/smoke.tests.ps1"

run:
	bash ./search.sh $(ARGS)
