#!/usr/bin/env bats
# Tests for lib/config.sh

setup() {
  # Create a temporary config file for testing
  TEST_CONFIG=$(mktemp)
  cat > "$TEST_CONFIG" <<'YAML'
profiles:
  - name: "work"
    gh_username: "workuser"
    path: "/tmp/work/"
    git:
      name: "Work User"
      email: "work@example.com"
      gpgsign: false
  - name: "personal"
    gh_username: "personaluser"
    path:
      - "/tmp/personal/"
      - "/tmp/home/"
    git:
      name: "Personal User"
      email: "personal@example.com"
      gpgsign: true
YAML
  
  # Source the config module
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  source "${SCRIPT_DIR}/lib/utils.sh"
  source "${SCRIPT_DIR}/lib/config.sh"
  
  # Override CONFIG variable
  CONFIG="$TEST_CONFIG"
}

teardown() {
  rm -f "$TEST_CONFIG"
}

@test "yaml_get retrieves profile count" {
  run yaml_get '.profiles | length' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "yaml_get retrieves profile name" {
  run yaml_get '.profiles[0].name' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "work" ]
}

@test "yaml_get retrieves git email" {
  run yaml_get '.profiles[0].git.email' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "work@example.com" ]
}

@test "yaml_get handles array paths" {
  run yaml_get '.profiles[1].path | length' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "yaml_get retrieves array path element" {
  run yaml_get '.profiles[1].path[0]' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/personal/" ]
}

@test "match_profile finds correct profile for path" {
  # Create test directory
  TEST_DIR="/tmp/work/test-repo"
  mkdir -p "$TEST_DIR"
  
  run match_profile "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]  # Should match work profile (index 0)
  
  rm -rf "$TEST_DIR"
}

@test "match_profile finds personal profile for personal path" {
  TEST_DIR="/tmp/personal/test-repo"
  mkdir -p "$TEST_DIR"
  
  run match_profile "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]  # Should match personal profile (index 1)
  
  rm -rf "$TEST_DIR"
}

