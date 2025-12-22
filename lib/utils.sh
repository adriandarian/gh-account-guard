#!/usr/bin/env bash
# Utility functions for gh-account-guard

# Configuration file path (respects CONFIG env var if already set)
export CONFIG="${CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/gh/account-guard.yml}"

# Check if a command exists
need_cmd() { 
  command -v "$1" >/dev/null 2>&1 || { echo "Missing '$1'." >&2; exit 1; }; 
}

# Check if optional UI tools are available and usable (for enhanced experience)
# Disabled: gum has compatibility issues with environment variables (BOLD, etc.)
# The native bash fallbacks provide equivalent functionality without external deps
has_gum() { 
  return 1
}

has_fzf() { 
  # Check if fzf exists - it will handle TTY checks itself
  command -v fzf >/dev/null 2>&1
}

has_fd() {
  # fd is much faster than find for directory traversal
  command -v fd >/dev/null 2>&1
}

has_bat() { 
  command -v bat >/dev/null 2>&1; 
}

# Cross-platform terminal detection
# Try harder to detect if we're in an interactive terminal
is_tty() {
  # Check if stdin and stdout are TTYs
  if [ -t 0 ] && [ -t 1 ]; then
    return 0
  fi
  # Also check if we can read from /dev/tty (works even when stdin is redirected)
  if [ -r /dev/tty ] 2>/dev/null && [ -w /dev/tty ] 2>/dev/null; then
    # Test if we can actually read from /dev/tty
    if read -t 0 < /dev/tty 2>/dev/null || true; then
      return 0
    fi
  fi
  return 1
}

# ANSI escape codes for cross-platform terminal control
ESC=$(printf '\033')
export CLEAR_LINE="${ESC}[2K"
export CURSOR_UP="${ESC}[1A"
export CURSOR_DOWN="${ESC}[1B"
export CURSOR_HOME="${ESC}[H"
export HIDE_CURSOR="${ESC}[?25l"
export SHOW_CURSOR="${ESC}[?25h"
export REVERSE="${ESC}[7m"
export RESET="${ESC}[0m"
export BOLD="${ESC}[1m"
export CYAN="${ESC}[36m"
export GREEN="${ESC}[32m"
export YELLOW="${ESC}[33m"
export BLUE="${ESC}[34m"

