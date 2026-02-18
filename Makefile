.PHONY: test test-mac test-ps

test: test-mac test-ps

test-mac:
	bash ./tests/smoke.tests.sh

test-ps:
	pwsh -NoProfile -Command "Invoke-Pester ./tests/smoke.tests.ps1"
