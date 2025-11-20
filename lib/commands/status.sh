#!/usr/bin/env bash
# Status command: Show which profile matches CWD and current gh/git identity

cmd_status() {
  [[ -f "$CONFIG" ]] || {
    if has_gum; then
      gum style --foreground 196 "⚠️  No configuration file found at $CONFIG"
      echo ""
      echo "Run 'gh account-guard setup' to create one."
    else
      echo "⚠️  No configuration file found at $CONFIG"
      echo ""
      echo "Run 'gh account-guard setup' to create one."
    fi
    return 1
  }
  
  local idx
  idx=$(match_profile "$PWD") || true
  if [[ -z "$idx" ]]; then
    echo "No matching profile found for current directory: $PWD"
    echo ""
    echo "Configured profiles:"
    local profile_count
    profile_count=$(yaml_get '.profiles | length' "$CONFIG" 2>/dev/null || echo "0")
    if [[ "$profile_count" -eq 0 ]]; then
      echo "  (no profiles configured)"
    else
      for ((i=0; i<profile_count; i++)); do
        local profile_name
        local profile_paths=()
        profile_name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
        
        # Check if path is an array or single value
        local path_type
        path_type=$(yaml_get ".profiles[$i].path | type" "$CONFIG" 2>/dev/null || echo "!!str")
        
        if [[ "$path_type" == *"seq"* ]] || [[ "$path_type" == *"array"* ]]; then
          # Multiple paths
          local path_count
          path_count=$(yaml_get ".profiles[$i].path | length" "$CONFIG" 2>/dev/null || echo "0")
          for ((j=0; j<path_count; j++)); do
            local path_val
            path_val=$(yaml_get ".profiles[$i].path[$j]" "$CONFIG" 2>/dev/null || echo "")
            if [[ -n "$path_val" ]]; then
              profile_paths+=("$path_val")
            fi
          done
          # Display as comma-separated list
          if [[ ${#profile_paths[@]} -gt 0 ]]; then
            local paths_display=$(IFS=','; echo "${profile_paths[*]}")
            echo "  - $profile_name: $paths_display"
          else
            echo "  - $profile_name: (no paths)"
          fi
        else
          # Single path
          local profile_path
          profile_path=$(yaml_get ".profiles[$i].path" "$CONFIG" 2>/dev/null || echo "")
          echo "  - $profile_name: $profile_path"
        fi
      done
    fi
    echo ""
    echo "Run 'gh account-guard setup' to add or modify profiles."
    exit 1
  fi
  local name
  local gh_u
  local git_name
  local git_email
  local git_gpgsign
  
  name=$(profile_get_field "$idx" "name")
  gh_u=$(profile_get_field "$idx" "gh_username")
  git_name=$(profile_get_field "$idx" "git.name")
  git_email=$(profile_get_field "$idx" "git.email")
  git_gpgsign=$(profile_get_field "$idx" "git.gpgsign")
  
  echo "Matched profile: $name (gh user: $gh_u)"
  echo ""
  
  # Check if gh auth matches
  local current_gh_user
  current_gh_user=$(gh_auth_get_current_user)
  
  echo "Current gh auth:"
  gh auth status || true
  echo ""
  
  if [[ -n "$current_gh_user" && "$current_gh_user" != "$gh_u" ]]; then
    if has_gum; then
      gum style --foreground 11 "⚠️  gh auth is set to '$current_gh_user' but profile expects '$gh_u'"
      gum style "   Note: gh auth is global and affects all terminals/editors"
      gum style "   Run 'gh account-guard switch' to change it (if desired)"
    else
      echo "⚠️  gh auth is set to '$current_gh_user' but profile expects '$gh_u'"
      echo "   Note: gh auth is global and affects all terminals/editors"
      echo "   Run 'gh account-guard switch' to change it (if desired)"
    fi
    echo ""
  fi
  
  echo "Current git identity:"
  local current_name
  local current_email
  current_name=$(git config --get user.name || echo '<unset>')
  current_email=$(git config --get user.email || echo '<unset>')
  
  if [[ "$current_name" == "$git_name" ]] && [[ "$current_email" == "$git_email" ]]; then
    echo "  ✓ user.name  = $current_name"
    echo "  ✓ user.email = $current_email"
  else
    echo "  ⚠️  user.name  = $current_name (should be: $git_name)"
    echo "  ⚠️  user.email = $current_email (should be: $git_email)"
    echo ""
    echo "Run 'gh account-guard fix' to update git identity"
  fi
  echo "  gpgsign    = $(git config --get commit.gpgsign || echo '<unset>')"
}

