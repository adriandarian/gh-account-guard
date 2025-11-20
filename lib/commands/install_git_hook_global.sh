#!/usr/bin/env bash
# Install git hook global command: Install pre-commit hook globally via git template

cmd_install_git_hook_global() {
  # Install pre-commit hook globally via git template directory
  # This will apply to all new repos and can be applied to existing repos
  
  local template_dir="$HOME/.git-template"
  local hooks_dir="$template_dir/hooks"
  local hook_file="$hooks_dir/pre-commit"
  
  # Create template directory structure
  mkdir -p "$hooks_dir" 2>/dev/null || {
    if has_gum; then
      gum style --foreground 196 "❌ Failed to create template directory: $template_dir"
    else
      echo "❌ Failed to create template directory: $template_dir" >&2
    fi
    exit 1
  }
  
  # Create the hook (same as per-repo hook)
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
  
  # Set git config to use this template directory
  git config --global init.templateDir "$template_dir"
  
  if has_gum; then
    gum style --foreground 10 "✅ Installed global git hook template"
    gum style "   Location: $hook_file"
    gum style ""
    gum style "This hook will be automatically added to:"
    gum style "  • All new repos (git init, git clone)"
    gum style "  • Existing repos (run 'git init' in them to apply)"
    echo ""
    gum style --foreground 11 "To apply to existing repos, run:"
    gum style "  find ~/work -name .git -type d -execdir git init \\;"
    gum style "  find ~/personal -name .git -type d -execdir git init \\;"
  else
    echo "✅ Installed global git hook template"
    echo "   Location: $hook_file"
    echo ""
    echo "This hook will be automatically added to:"
    echo "  • All new repos (git init, git clone)"
    echo "  • Existing repos (run 'git init' in them to apply)"
    echo ""
    echo ""
    echo "To apply to existing repos, run:"
    echo "  gh account-guard apply-hook-to-repos"
  fi
}

