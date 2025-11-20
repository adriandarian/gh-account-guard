#!/usr/bin/env bash
# Git helper functions for gh-account-guard

# Check if we're in a git repository (handles both regular repos and worktrees)
git_is_repo() {
  git rev-parse --git-dir >/dev/null 2>&1
}

# Get the git directory (handles worktrees where .git is a file)
git_get_dir() {
  git rev-parse --git-dir 2>/dev/null || echo ".git"
}

# Get git remote URL
git_get_remote_url() {
  git config --get remote.origin.url 2>/dev/null || echo ""
}

# Set git remote URL
git_set_remote_url() {
  local url="$1"
  git remote set-url origin "$url" 2>/dev/null || true
}

# Configure git remote URL to include username for authentication
# This helps git push use the correct account even when gh auth is different
git_configure_remote_url() {
  local gh_username="$1"
  local remote_url
  
  remote_url=$(git_get_remote_url)
  if [[ -z "$remote_url" ]] || [[ -z "$gh_username" ]] || [[ "$gh_username" == "null" ]]; then
    return 0
  fi
  
  if [[ "$remote_url" == https://github.com/* ]] && [[ "$remote_url" != *"@"* ]]; then
    # Update remote URL to include username (helps git use correct credentials)
    local new_url
    new_url=$(echo "$remote_url" | sed "s|https://github.com/|https://$gh_username@github.com/|")
    git_set_remote_url "$new_url"
  elif [[ "$remote_url" == https://*@github.com/* ]]; then
    # Update existing username in URL if it's different
    local current_user
    current_user=$(echo "$remote_url" | sed 's|https://\([^@]*\)@github.com/.*|\1|' 2>/dev/null || echo "")
    if [[ -n "$current_user" && "$current_user" != "$gh_username" ]]; then
      local new_url
      new_url=$(echo "$remote_url" | sed "s|https://[^@]*@github.com/|https://$gh_username@github.com/|")
      git_set_remote_url "$new_url"
    fi
  fi
}

# Apply git identity from profile settings
git_apply_identity() {
  local git_name="$1"
  local git_email="$2"
  local signing_key="${3:-}"
  local gpg_format="${4:-}"
  local gpgsign="${5:-}"
  
  git config --local user.name "$git_name" 2>/dev/null || true
  git config --local user.email "$git_email" 2>/dev/null || true
  [[ -n "$signing_key" ]] && git config --local user.signingkey "$signing_key" 2>/dev/null || true
  [[ -n "$gpg_format" ]] && git config --local gpg.format "$gpg_format" 2>/dev/null || true
  [[ -n "$gpgsign" ]] && git config --local commit.gpgsign "$gpgsign" 2>/dev/null || true
}

# Get current git identity
git_get_identity() {
  local name
  local email
  local gpgsign
  
  name=$(git config --get user.name 2>/dev/null || echo "")
  email=$(git config --get user.email 2>/dev/null || echo "")
  gpgsign=$(git config --get commit.gpgsign 2>/dev/null || echo "false")
  
  echo "$name|$email|$gpgsign"
}

# Check if git identity matches profile
git_identity_matches() {
  local expected_name="$1"
  local expected_email="$2"
  local expected_gpgsign="${3:-false}"
  
  local current_name
  local current_email
  local current_gpgsign
  
  current_name=$(git config --get user.name 2>/dev/null || echo "")
  current_email=$(git config --get user.email 2>/dev/null || echo "")
  current_gpgsign=$(git config --get commit.gpgsign 2>/dev/null || echo "false")
  
  if [[ "$current_name" == "$expected_name" ]] && \
     [[ "$current_email" == "$expected_email" ]] && \
     [[ "$current_gpgsign" == "$expected_gpgsign" ]]; then
    return 0
  fi
  
  return 1
}

