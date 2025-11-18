.PHONY: test lint install-deps help

help:
	@echo "Available targets:"
	@echo "  test          - Run all tests"
	@echo "  lint          - Run shellcheck on all scripts"
	@echo "  install-deps  - Install test dependencies (bats, shellcheck)"
	@echo "  ci            - Run all checks (lint + test)"

test:
	@./test/run_tests.sh

lint:
	@command -v shellcheck >/dev/null || { echo "Install shellcheck: brew install shellcheck"; exit 1; }
	@shellcheck gh-account-guard install
	@shellcheck lib/*.sh
	@shellcheck test/*.sh
	@echo "✅ Linting passed"

install-deps:
	@command -v bats >/dev/null || { echo "Installing bats..."; brew install bats-core || apt-get install -y bats; }
	@command -v shellcheck >/dev/null || { echo "Installing shellcheck..."; brew install shellcheck || apt-get install -y shellcheck; }
	@echo "✅ Dependencies installed"

ci: lint test
	@echo "✅ All checks passed"

