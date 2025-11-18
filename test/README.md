# Tests

This directory contains the test suite for `gh-account-guard`.

## Running Tests

### Prerequisites

Install `bats` (Bash Automated Testing System):

```bash
# macOS
brew install bats-core

# Linux (Ubuntu/Debian)
sudo apt-get install bats

# Or from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Run All Tests

```bash
make test
# or
./test/run_tests.sh
```

### Run Individual Test Files

```bash
bats test/test_utils.sh
bats test/test_config.sh
bats test/test_commands.sh
```

## Test Structure

- `test_utils.sh` - Tests for utility functions (gum/fzf detection, TTY detection)
- `test_config.sh` - Tests for YAML parsing and profile matching
- `test_commands.sh` - Tests for command implementations
- `run_tests.sh` - Test runner script

## Writing New Tests

Tests use the [bats](https://github.com/bats-core/bats-core) framework. Example:

```bash
#!/usr/bin/env bats

@test "my function works correctly" {
  run my_function "input"
  [ "$status" -eq 0 ]
  [ "$output" = "expected output" ]
}
```

