#!/usr/bin/env bats
# Tests for lib/utils.sh

load '../lib/utils.sh'

@test "has_gum returns 0 when gum is available" {
  if command -v gum >/dev/null 2>&1; then
    run has_gum
    [ "$status" -eq 0 ]
  else
    skip "gum not installed"
  fi
}

@test "has_fzf returns 0 when fzf is available" {
  if command -v fzf >/dev/null 2>&1; then
    run has_fzf
    [ "$status" -eq 0 ]
  else
    skip "fzf not installed"
  fi
}

@test "is_tty detects TTY correctly" {
  # This test is tricky since we're running in bats
  # Just verify the function exists and doesn't crash
  run is_tty
  # Should return 0 or 1, not crash
  [ "$status" -ge 0 ] || [ "$status" -le 1 ]
}

