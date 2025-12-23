#!/usr/bin/env bash
# Status command: Show which profile matches CWD and current gh/git identity

cmd_status() {
  [[ -f "$CONFIG" ]] || {
    echo "${YELLOW}⚠️  No configuration file found at $CONFIG${RESET}"
    echo ""
    echo "Run 'gh account-guard setup' to create one."
    return 1
  }
  
  # Header
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "${BOLD}🔍 gh-account-guard Status${RESET}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Current directory
  echo "${CYAN}📁 Current directory:${RESET} $PWD"
  echo ""
  
  local idx
  idx=$(match_profile "$PWD") || true
  if [[ -z "$idx" ]]; then
    echo "${YELLOW}⚠️  No matching profile found${RESET}"
    echo ""
    echo "${BOLD}📋 Configured Profiles${RESET}"
    echo ""
    local profile_count
    profile_count=$(yaml_get '.profiles | length' "$CONFIG" 2>/dev/null || echo "0")
    if [[ "$profile_count" -eq 0 ]]; then
      echo "  (no profiles configured)"
    else
      for ((i=0; i<profile_count; i++)); do
        local profile_name
        profile_name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
        
        # Check if path is an array or single value
        local path_type
        path_type=$(yaml_get ".profiles[$i].path | type" "$CONFIG" 2>/dev/null || echo "!!str")
        
        if [[ "$path_type" == *"seq"* ]] || [[ "$path_type" == *"array"* ]]; then
          # Multiple paths
          local path_count
          path_count=$(yaml_get ".profiles[$i].path | length" "$CONFIG" 2>/dev/null || echo "0")
          echo "  ${CYAN}┌─ Profile: ${BOLD}$profile_name${RESET}"
          echo "  ${CYAN}│${RESET}  Paths:"
          for ((j=0; j<path_count; j++)); do
            local path_val
            path_val=$(yaml_get ".profiles[$i].path[$j]" "$CONFIG" 2>/dev/null || echo "")
            if [[ -n "$path_val" ]]; then
              echo "  ${CYAN}│${RESET}    • $path_val"
            fi
          done
          echo "  ${CYAN}└─${RESET}"
        else
          # Single path
          local profile_path
          profile_path=$(yaml_get ".profiles[$i].path" "$CONFIG" 2>/dev/null || echo "")
          echo "  ${CYAN}┌─ Profile: ${BOLD}$profile_name${RESET}"
          echo "  ${CYAN}│${RESET}  Path: $profile_path"
          echo "  ${CYAN}└─${RESET}"
        fi
        echo ""
      done
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Run 'gh account-guard setup' to add or modify profiles."
    exit 1
  fi
  
  local name
  local gh_u
  local git_name
  local git_email
  
  name=$(profile_get_field "$idx" "name")
  gh_u=$(profile_get_field "$idx" "gh_username")
  git_name=$(profile_get_field "$idx" "git.name")
  git_email=$(profile_get_field "$idx" "git.email")
  
  # Matched profile section
  echo "${BOLD}📋 Matched Profile${RESET}"
  echo ""
  echo "  ${CYAN}┌─ Profile: ${BOLD}$name${RESET}"
  echo "  ${CYAN}│${RESET}  GitHub: $gh_u"
  echo "  ${CYAN}│${RESET}  Expected Git Name: $git_name"
  echo "  ${CYAN}│${RESET}  Expected Git Email: $git_email"
  echo "  ${CYAN}└─${RESET}"
  echo ""
  
  # GitHub Auth section
  echo "${BOLD}🔐 GitHub Authentication${RESET}"
  echo ""
  local current_gh_user
  current_gh_user=$(gh_auth_get_current_user)
  
  if [[ -n "$current_gh_user" ]]; then
    if [[ "$current_gh_user" == "$gh_u" ]]; then
      echo "  ${GREEN}✓${RESET} Logged in as: ${BOLD}$current_gh_user${RESET}"
    else
      echo "  ${YELLOW}⚠️${RESET} Logged in as: ${BOLD}$current_gh_user${RESET}"
      echo "     ${YELLOW}Expected: $gh_u${RESET}"
      echo ""
      echo "     Note: gh auth is global and affects all terminals/editors"
      echo "     Run 'gh account-guard switch' to change it (if desired)"
    fi
  else
    echo "  ${YELLOW}⚠️${RESET} Not logged in to GitHub CLI"
  fi
  echo ""
  
  # Git Identity section
  echo "${BOLD}👤 Git Identity${RESET}"
  echo ""
  local current_name
  local current_email
  local current_gpgsign
  current_name=$(git config --get user.name 2>/dev/null || echo '<unset>')
  current_email=$(git config --get user.email 2>/dev/null || echo '<unset>')
  current_gpgsign=$(git config --get commit.gpgsign 2>/dev/null || echo '<unset>')
  
  local name_ok=false
  local email_ok=false
  
  if [[ "$current_name" == "$git_name" ]]; then
    echo "  ${GREEN}✓${RESET} user.name:  $current_name"
    name_ok=true
  else
    echo "  ${YELLOW}⚠️${RESET} user.name:  $current_name"
    echo "     ${YELLOW}Expected: $git_name${RESET}"
  fi
  
  if [[ "$current_email" == "$git_email" ]]; then
    echo "  ${GREEN}✓${RESET} user.email: $current_email"
    email_ok=true
  else
    echo "  ${YELLOW}⚠️${RESET} user.email: $current_email"
    echo "     ${YELLOW}Expected: $git_email${RESET}"
  fi
  
  echo "  ${CYAN}○${RESET} gpgsign:    $current_gpgsign"
  echo ""
  
  # Footer with suggestions
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if [[ "$name_ok" == false ]] || [[ "$email_ok" == false ]]; then
    echo ""
    echo "Run 'gh account-guard fix' to update git identity"
  fi
}

