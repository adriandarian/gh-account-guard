#!/usr/bin/env bats
# Tests for lib/commands.sh

setup() {
  # Create temporary config
  TEST_CONFIG=$(mktemp)
  cat > "$TEST_CONFIG" <<'YAML'
profiles:
  - name: "test"
    gh_username: "testuser"
    path: "/tmp/test/"
    git:
      name: "Test User"
      email: "test@example.com"
      gpgsign: false
YAML
  
  # Source modules
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  source "${SCRIPT_DIR}/lib/utils.sh"
  source "${SCRIPT_DIR}/lib/config.sh"
  source "${SCRIPT_DIR}/lib/commands.sh"
  
  # Override CONFIG
  CONFIG="$TEST_CONFIG"
  
  # Create test git repo
  TEST_REPO=$(mktemp -d)
  cd "$TEST_REPO"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
}

teardown() {
  rm -f "$TEST_CONFIG"
  rm -rf "$TEST_REPO"
}

@test "cmd_init creates config file" {
  TEST_INIT_CONFIG=$(mktemp)
  rm -f "$TEST_INIT_CONFIG"
  
  CONFIG="$TEST_INIT_CONFIG"
  run cmd_init
  
  [ "$status" -eq 0 ]
  [ -f "$TEST_INIT_CONFIG" ]
  grep -q "profiles:" "$TEST_INIT_CONFIG"
  
  rm -f "$TEST_INIT_CONFIG"
}

@test "cmd_status shows matched profile" {
  # Create directory matching test profile
  TEST_DIR="/tmp/test/repo"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"
  git init -q
  
  run cmd_status
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Matched profile"
  
  rm -rf "$TEST_DIR"
}

@test "cmd_fix applies git config" {
  TEST_DIR="/tmp/test/repo"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"
  git init -q
  
  run cmd_fix
  
  [ "$status" -eq 0 ]
  [ "$(git config user.name)" = "Test User" ]
  [ "$(git config user.email)" = "test@example.com" ]
  
  rm -rf "$TEST_DIR"
}

@test "cmd_auto_enforce sets correct git identity" {
  TEST_DIR="/tmp/test/repo"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"
  git init -q
  
  # Set wrong identity
  git config user.name "Wrong User"
  git config user.email "wrong@example.com"
  
  run cmd_auto_enforce
  
  [ "$status" -eq 0 ]
  [ "$(git config user.name)" = "Test User" ]
  [ "$(git config user.email)" = "test@example.com" ]
  
  rm -rf "$TEST_DIR"
}

