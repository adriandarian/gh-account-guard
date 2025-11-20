#!/usr/bin/env bash
# GitHub auth helper functions for gh-account-guard

# Get the currently active GitHub auth user
gh_auth_get_current_user() {
  gh auth status 2>&1 | grep -B 2 "Active account: true" | grep "Logged in to" | sed 's/.*account //' | sed 's/ .*//' 2>/dev/null || echo ""
}

# Get list of all logged-in GitHub accounts
gh_auth_get_accounts() {
  local accounts=()
  local current_account=""
  
  while IFS= read -r line; do
    if [[ "$line" =~ Logged[[:space:]]in[[:space:]]to[[:space:]]github\.com[[:space:]]account[[:space:]]([^[:space:]]+) ]]; then
      accounts+=("${BASH_REMATCH[1]}")
    fi
    if [[ "$line" =~ Active[[:space:]]account:[[:space:]]true ]]; then
      # Get the account from the previous line
      if [[ "${#accounts[@]}" -gt 0 ]]; then
        current_account="${accounts[-1]}"
      fi
    fi
  done < <(gh auth status 2>&1)
  
  # Output accounts, one per line, with current account marked
  for account in "${accounts[@]}"; do
    if [[ "$account" == "$current_account" ]]; then
      echo "$account (current)"
    else
      echo "$account"
    fi
  done
  
  # Return current account as last line (for easy extraction)
  echo "__CURRENT__:$current_account"
}

# Switch GitHub auth to a specific user
gh_auth_switch_user() {
  local username="$1"
  gh auth switch -u "$username" >/dev/null 2>&1 || return 1
}

# Get GitHub user info (name and email) for a specific account
gh_auth_get_user_info() {
  local username="$1"
  local original_user
  
  original_user=$(gh_auth_get_current_user)
  
  # Switch to the requested user temporarily
  if [[ -n "$original_user" && "$original_user" != "$username" ]]; then
    gh_auth_switch_user "$username" || return 1
  fi
  
  # Get user info from GitHub API
  local git_name
  local git_email
  
  git_name=$(gh api user --jq '.name // ""' 2>/dev/null || echo "")
  git_email=$(gh api user --jq '.email // ""' 2>/dev/null || echo "")
  
  # If email is null or empty, try to get it from the user's public email list
  if [[ -z "$git_email" ]]; then
    git_email=$(gh api user/emails --jq '.[0].email // ""' 2>/dev/null || echo "")
  fi
  
  # Switch back to original user if it was different
  if [[ -n "$original_user" && "$original_user" != "$username" ]]; then
    gh_auth_switch_user "$original_user" >/dev/null 2>&1 || true
  fi
  
  # Output name and email separated by |
  echo "$git_name|$git_email"
}

