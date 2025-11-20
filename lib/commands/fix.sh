#!/usr/bin/env bash
# Fix command: Apply matching profile to current repo

cmd_fix() {
  # Check if we're in a git repo (handles both regular repos and worktrees)
  git_is_repo || { echo "Not a git repo."; exit 1; }
  
  local idx
  idx=$(match_profile "$PWD") || true
  [[ -n "$idx" ]] || { echo "No matching profile for $PWD"; exit 1; }

  local name
  local email
  local skey
  local gpgf
  local gpgs
  local gh_u
  local rmatch
  
  name=$(profile_get_field "$idx" "git.name")
  email=$(profile_get_field "$idx" "git.email")
  skey=$(profile_get_field "$idx" "git.signingkey")
  gpgf=$(profile_get_field "$idx" "git.gpgformat")
  gpgs=$(profile_get_field "$idx" "git.gpgsign")
  gh_u=$(profile_get_field "$idx" "gh_username")
  rmatch=$(profile_get_field "$idx" "remote_match")

  if [[ -n "$rmatch" ]]; then
    local remote
    remote=$(git_get_remote_url)
    if [[ -n "$remote" && "$remote" != *"$rmatch"* ]]; then
      echo "⚠️  Remote '$remote' does not match '$rmatch' for this profile."
    fi
  fi

  # Apply git identity using helper function
  git_apply_identity "$name" "$email" "$skey" "$gpgf" "$gpgs"
  
  # Configure git remote URL to include username for authentication
  git_configure_remote_url "$gh_u"

  echo "✅ Set repo identity to: $name <$email>; signing=$(git config --get commit.gpgsign)"
  
  # Warn about gh auth if it doesn't match
  if [[ -n "$gh_u" && "$gh_u" != "null" ]]; then
    local current_gh_user
    current_gh_user=$(gh_auth_get_current_user)
    if [[ -n "$current_gh_user" && "$current_gh_user" != "$gh_u" ]]; then
      echo ""
      if has_gum; then
        gum style --foreground 11 "⚠️  Note: gh auth is '$current_gh_user' but profile expects '$gh_u'"
        gum style "   For git push to work, run: gh account-guard switch"
        gum style "   (gh auth is global - affects all terminals/editors)"
      else
        echo "⚠️  Note: gh auth is '$current_gh_user' but profile expects '$gh_u'"
        echo "   For git push to work, run: gh account-guard switch"
        echo "   (gh auth is global - affects all terminals/editors)"
      fi
    fi
  fi
}

