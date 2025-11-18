#!/usr/bin/env bash
# Utility functions for gh-account-guard

# Configuration file path
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/gh/account-guard.yml"

# Check if a command exists
need_cmd() { 
  command -v "$1" >/dev/null 2>&1 || { echo "Missing '$1'." >&2; exit 1; }; 
}

# Check if optional UI tools are available and usable (for enhanced experience)
has_gum() { 
  command -v gum >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]
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
CLEAR_LINE="${ESC}[2K"
CURSOR_UP="${ESC}[1A"
CURSOR_DOWN="${ESC}[1B"
CURSOR_HOME="${ESC}[H"
HIDE_CURSOR="${ESC}[?25l"
SHOW_CURSOR="${ESC}[?25h"
REVERSE="${ESC}[7m"
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
CYAN="${ESC}[36m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
BLUE="${ESC}[34m"

