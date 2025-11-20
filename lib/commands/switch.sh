#!/usr/bin/env bash
# Switch command: Switch GitHub auth to matching profile

cmd_switch() {
  local interactive=false
  local target_dir="$PWD"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --interactive|-i|--list|-l)
        interactive=true
        shift
        ;;
      --help|-h)
        echo "Usage: gh account-guard switch [--interactive|-i|--list|-l]"
        echo ""
        echo "Switch GitHub CLI account to the matching profile for the current directory."
        echo ""
        echo "Options:"
        echo "  --interactive, -i, --list, -l    Show interactive menu to select from all profiles"
        echo "  --help, -h                       Show this help message"
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Use --help for usage information" >&2
        exit 1
        ;;
    esac
  done
  
  local idx
  local profile_name
  local gh_u
  local current_user
  
  # If interactive mode, show all profiles
  if [[ "$interactive" == true ]]; then
    # Get all profiles
    local profile_count
    profile_count=$(yaml_get '.profiles | length' "$CONFIG" 2>/dev/null || echo "0")
    
    if [[ "$profile_count" -eq 0 ]]; then
      echo "No profiles configured. Run 'gh account-guard setup' to create one."
      exit 1
    fi
    
    # Build profile options
    local profile_options=()
    local profile_indices=()
    local current_gh_user
    current_gh_user=$(gh_auth_get_current_user)
    
    for ((i=0; i<profile_count; i++)); do
      local pname
      local pgh_user
      pname=$(profile_get_field "$i" "name")
      pgh_user=$(profile_get_field "$i" "gh_username")
      
      if [[ -z "$pname" || "$pname" == "null" ]]; then
        pname="Profile $((i+1))"
      fi
      
      local display="$pname"
      if [[ -n "$pgh_user" && "$pgh_user" != "null" ]]; then
        display="$pname ($pgh_user)"
        if [[ "$pgh_user" == "$current_gh_user" ]]; then
          display="$display (current)"
        fi
      else
        display="$display (no gh_username)"
      fi
      
      profile_options+=("$display")
      profile_indices+=("$i")
    done
    
    # Show interactive menu
    echo ""
    if has_gum; then
      gum style --foreground 212 --bold "Select profile to switch to:"
      echo ""
    else
      echo "Select profile to switch to:"
      echo ""
    fi
    
    local selected
    selected=$(interactive_menu "Choose a profile:" "" "${profile_options[@]}")
    local menu_exit=$?
    
    if [[ $menu_exit -eq 130 ]] || [[ -z "$selected" ]]; then
      echo "Cancelled."
      exit 0
    fi
    
    # Find the index of selected profile
    idx=""
    for i in "${!profile_options[@]}"; do
      if [[ "${profile_options[$i]}" == "$selected" ]]; then
        idx="${profile_indices[$i]}"
        break
      fi
    done
    
    if [[ -z "$idx" ]]; then
      echo "Error: Could not find selected profile" >&2
      exit 1
    fi
  else
    # Normal mode: match profile for current directory
    idx=$(match_profile "$target_dir") || true
    if [[ -z "$idx" ]]; then
      echo "No matching profile for $target_dir"
      echo ""
      echo "Tip: Use 'gh account-guard switch --interactive' to select from all profiles"
      exit 1
    fi
  fi
  
  # Get profile name and GitHub username
  profile_name=$(profile_get_field "$idx" "name")
  if [[ -z "$profile_name" || "$profile_name" == "null" ]]; then
    profile_name="Profile $((idx+1))"
  fi
  
  gh_u=$(profile_get_field "$idx" "gh_username")
  if [[ -z "$gh_u" || "$gh_u" == "null" ]]; then
    echo "No gh_username configured for profile: $profile_name"
    exit 1
  fi
  
  # Get current user before switching
  current_user=$(gh_auth_get_current_user)
  
  # Switch to the profile's GitHub account
  if ! gh_auth_switch_user "$gh_u"; then
    echo "Error: Failed to switch to GitHub account: $gh_u" >&2
    exit 1
  fi
  
  # Show success message
  if [[ "$gh_u" == "$current_user" ]]; then
    echo "✓ Already using profile: $profile_name ($gh_u)"
  else
    echo "✓ Switched to profile: $profile_name ($gh_u)"
  fi
}
