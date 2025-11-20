#!/usr/bin/env bash
# Create alias command: Create 'gh ag' alias for 'gh account-guard'

cmd_create_alias() {
  # Use gh CLI's built-in alias feature to create 'gh ag' -> 'gh account-guard'
  # Check if gh alias command is available
  if ! command -v gh >/dev/null 2>&1; then
    if has_gum; then
      gum style --foreground 196 "❌ gh CLI not found"
    else
      echo "❌ gh CLI not found" >&2
    fi
    exit 1
  fi
  
  # Check if alias already exists
  local existing_alias
  existing_alias=$(gh alias list 2>/dev/null | grep -E "^ag[[:space:]]*:" || echo "")
  
  if [[ -n "$existing_alias" ]]; then
    if echo "$existing_alias" | grep -q "account-guard"; then
      if has_gum; then
        gum style --foreground 10 "✅ Alias 'gh ag' already exists and points to account-guard"
      else
        echo "✅ Alias 'gh ag' already exists and points to account-guard"
      fi
      exit 0
    else
      if has_gum; then
        gum style --foreground 11 "⚠️  Alias 'ag' already exists but points to something else:"
        gum style "   $existing_alias"
        gum style ""
        gum style "   Remove it first: gh alias delete ag"
        gum style "   Then run this command again"
      else
        echo "⚠️  Alias 'ag' already exists but points to something else:" >&2
        echo "   $existing_alias" >&2
        echo "" >&2
        echo "   Remove it first: gh alias delete ag" >&2
        echo "   Then run this command again" >&2
      fi
      exit 1
    fi
  fi
  
  # Create the alias (gh alias set may return non-zero even on success, so check if it was created)
  gh alias set ag 'account-guard' >/dev/null 2>&1 || true
  
  # Verify it was created
  existing_alias=$(gh alias list 2>/dev/null | grep -E "^ag[[:space:]]+" || echo "")
  if [[ -n "$existing_alias" ]] && echo "$existing_alias" | grep -q "account-guard"; then
    if has_gum; then
      gum style --foreground 10 "✅ Created alias 'gh ag' -> 'gh account-guard'"
      gum style "   You can now use: gh ag status, gh ag install, etc."
    else
      echo "✅ Created alias 'gh ag' -> 'gh account-guard'"
      echo "   You can now use: gh ag status, gh ag install, etc."
    fi
  else
    if has_gum; then
      gum style --foreground 196 "❌ Failed to create alias"
      gum style "   Make sure gh CLI is properly installed and configured"
    else
      echo "❌ Failed to create alias" >&2
      echo "   Make sure gh CLI is properly installed and configured" >&2
    fi
    exit 1
  fi
}

