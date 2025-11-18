#!/usr/bin/env bash
# Test runner script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if bats is installed
if ! command -v bats >/dev/null 2>&1; then
  echo "❌ bats is not installed"
  echo ""
  echo "Install it with:"
  echo "  macOS: brew install bats-core"
  echo "  Linux: See https://github.com/bats-core/bats-core#installation"
  exit 1
fi

# Run all tests
echo "Running tests..."
echo ""

cd "$PROJECT_ROOT"

# Run tests with verbose output
bats --verbose test/*.sh

echo ""
echo "✅ All tests passed!"

