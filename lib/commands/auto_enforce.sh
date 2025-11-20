#!/usr/bin/env bash
# Auto-enforce command: Silently enforce profile settings (used by shell hooks)

cmd_auto_enforce() {
  # Silently enforce profile settings without any output
  # Only show errors if something goes wrong
  
  # Ensure CONFIG is set
  [[ -n "${CONFIG:-}" ]] || CONFIG="$HOME/.config/gh/account-guard.yml"
  
  # Check if config exists
  [[ -f "$CONFIG" ]] || return 0
  
  # Check if we're in a git repo (handles both regular repos and worktrees)
  git_is_repo || return 0
  
  # Find matching profile
  local idx
  idx=$(match_profile "$PWD" 2>/dev/null || echo "")
  [[ -n "$idx" ]] || return 0
  
  # Get profile settings using helper function
  local git_identity
  git_identity=$(profile_get_git_identity "$idx")
  IFS='|' read -r git_name git_email skey gpgf gpgs <<< "$git_identity"
  
  local gh_u
  gh_u=$(profile_get_field "$idx" "gh_username")
  
  # NOTE: We do NOT automatically switch gh auth here because gh auth switch is GLOBAL
  # and affects all terminals/editors. This causes problems when working with multiple
  # projects simultaneously. Users should manually run 'gh account-guard switch' if
  # they want to change the active gh auth account.
  # 
  # The pre-commit hook validates git identity (which is per-repo), not gh auth.
  # Git commits use git config, not gh auth, so this is sufficient for compliance.
  
  # Check and apply git identity if needed
  if ! git_identity_matches "$git_name" "$git_email" "$gpgs"; then
    git_apply_identity "$git_name" "$git_email" "$skey" "$gpgf" "$gpgs"
  fi
  
  # Configure git remote URL to include username for authentication
  git_configure_remote_url "$gh_u"
  
  return 0
}

