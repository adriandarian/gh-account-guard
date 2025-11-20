#!/usr/bin/env bash
# Install git hook command: Install pre-commit hook (per-repo or global)

cmd_install_git_hook() {
  local global="${1:-}"
  
  if [[ "$global" == "--global" ]] || [[ "$global" == "-g" ]]; then
    # Install globally via git template directory
    cmd_install_git_hook_global
    return $?
  fi
  
  # Install a git pre-commit hook that validates git identity matches profile
  # Check if we're in a git repo (handles both regular repos and worktrees)
  git_is_repo || { echo "Not a git repository. Run this command from inside a git repo."; exit 1; }
  
  # Get the actual git directory (handles worktrees where .git is a file)
  local git_dir
  git_dir=$(git_get_dir)
  local hook_file="$git_dir/hooks/pre-commit"
  
  # Ensure hooks directory exists
  mkdir -p "$(dirname "$hook_file")" 2>/dev/null || true
  
  # Create the hook that validates identity before commit
  # This hook calls back to gh account-guard to validate the identity
  cat > "$hook_file" <<'HOOK'
#!/usr/bin/env bash
# gh-account-guard pre-commit hook
# Validates that git identity matches the profile for this directory
# This prevents accidental commits with the wrong identity

set -e

# Check if gh account-guard is available
command -v gh >/dev/null || exit 0

# First, auto-enforce to ensure identity is correct
gh account-guard auto-enforce >/dev/null 2>&1 || true

# Get current git identity after enforcement
current_name=$(git config --get user.name 2>/dev/null || echo "")
current_email=$(git config --get user.email 2>/dev/null || echo "")

# If no identity is set, allow commit (git will use global config)
if [[ -z "$current_name" ]] || [[ -z "$current_email" ]]; then
  exit 0
fi

# Get expected identity by calling status and parsing output
status_output=$(gh account-guard status 2>&1 || echo "")

# Check if there's a matched profile
if ! echo "$status_output" | grep -q "Matched profile:"; then
  # No profile matches - allow commit
  exit 0
fi

# Extract expected values from status output
# Look for lines like "✓ user.name = value" or "⚠️  user.name = current (should be: expected)"
expected_name=""
expected_email=""

# Try to get expected name
name_line=$(echo "$status_output" | grep "user.name" | head -1)
if echo "$name_line" | grep -q "should be:"; then
  expected_name=$(echo "$name_line" | sed 's/.*should be: //' | xargs)
elif echo "$name_line" | grep -q "✓"; then
  expected_name=$(echo "$name_line" | sed 's/.*= //' | xargs)
fi

# Try to get expected email
email_line=$(echo "$status_output" | grep "user.email" | head -1)
if echo "$email_line" | grep -q "should be:"; then
  expected_email=$(echo "$email_line" | sed 's/.*should be: //' | xargs)
elif echo "$email_line" | grep -q "✓"; then
  expected_email=$(echo "$email_line" | sed 's/.*= //' | xargs)
fi

# If we couldn't determine expected values, allow commit (fail open)
if [[ -z "$expected_name" ]] || [[ -z "$expected_email" ]]; then
  exit 0
fi

# Compare current vs expected
if [[ "$current_name" != "$expected_name" ]] || [[ "$current_email" != "$expected_email" ]]; then
  echo "❌ Pre-commit hook: Git identity mismatch!" >&2
  echo "" >&2
  echo "Current identity:" >&2
  echo "  user.name  = $current_name" >&2
  echo "  user.email = $current_email" >&2
  echo "" >&2
  echo "Expected identity for this profile:" >&2
  echo "  user.name  = $expected_name" >&2
  echo "  user.email = $expected_email" >&2
  echo "" >&2
  echo "The identity has been auto-corrected. Please try committing again." >&2
  echo "" >&2
  echo "To bypass this check (not recommended):" >&2
  echo "  git commit --no-verify" >&2
  exit 1
fi

exit 0
HOOK

  chmod +x "$hook_file"
  
  if has_gum; then
    gum style --foreground 10 "✅ Installed pre-commit hook at $hook_file"
    gum style "This hook will block commits if your git identity doesn't match the profile."
    echo ""
    gum style "To test, try committing with wrong identity - it will be blocked."
  else
    echo "✅ Installed pre-commit hook at $hook_file"
    echo "This hook will block commits if your git identity doesn't match the profile."
    echo ""
    echo "To test, try committing with wrong identity - it will be blocked."
  fi
}

