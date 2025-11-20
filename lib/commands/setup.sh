#!/usr/bin/env bash
# Setup command: Interactive setup wizard to configure profiles

cmd_setup() {
  mkdir -p "$(dirname "$CONFIG")"
  
  local overwrite=false
  
  if [[ -e "$CONFIG" ]]; then
    local choice
    choice=$(interactive_menu "What would you like to do?" "Config already exists at $CONFIG" \
      "Add a new profile (keep existing)" \
      "Start fresh (overwrite existing config)" \
      "Cancel")
    local menu_exit=$?
    
    if [[ $menu_exit -eq 130 ]] || [[ -z "$choice" ]]; then
      echo "Cancelled."
      exit 0
    fi
    
    case "$choice" in
      "Add a new profile"*) ;;
      "Start fresh"*) overwrite=true ;;
      "Cancel"*) echo "Cancelled."; exit 0 ;;
      *) echo "Invalid choice. Cancelled."; exit 1 ;;
    esac
  fi

  if [[ "$overwrite" == true ]]; then
    rm -f "$CONFIG"
  fi

  if has_gum; then
    gum style --foreground 212 --bold "🔧 gh-account-guard Interactive Setup"
    echo ""
    gum style "This wizard will help you configure your GitHub account profiles."
    gum style "You can add multiple profiles (work, personal, clients, etc.)"
    echo ""
  else
    echo "🔧 gh-account-guard Interactive Setup"
    echo ""
    echo "This wizard will help you configure your GitHub account profiles."
    echo "You can add multiple profiles (work, personal, clients, etc.)"
    echo ""
  fi

  local profile_num=1
  local profile_names=()
  
  while true; do
    local default_name
    if [[ $profile_num -eq 1 ]]; then
      default_name="work"
    elif [[ $profile_num -eq 2 ]]; then
      default_name="personal"
    else
      default_name="profile$profile_num"
    fi
    
    local profile_name
    profile_name=$(collect_profile_info "$profile_num" "$default_name")
    
    # Validate profile name was captured
    if [[ -z "$profile_name" ]]; then
      echo "Error: Failed to capture profile name." >&2
      exit 1
    fi
    
    profile_names+=("$profile_name")
    
    # Add a small separator and ensure output is clear
    echo ""
    if has_gum; then
      gum style --foreground 10 "✅ Profile '$profile_name' added!"
    else
      echo "✅ Profile '$profile_name' added!"
    fi
    echo ""
    
    if ! prompt_yesno "Add another profile?" "n"; then
      break
    fi
    
    profile_num=$((profile_num + 1))
  done

  echo ""
  if has_gum; then
    gum spin --spinner dot --title "Saving configuration..." -- sleep 0.5 2>/dev/null || true
    gum style --foreground 10 "✅ Configuration saved to $CONFIG"
  else
    echo "✅ Configuration saved to $CONFIG"
  fi
  echo ""
  if has_gum; then
    gum style --bold "Profiles configured: ${profile_names[*]}"
  else
    echo "Profiles configured: ${profile_names[*]}"
  fi
  echo ""
  echo "Next steps:"
  echo "  1. Make sure all GitHub accounts are logged in:"
  for name in "${profile_names[@]}"; do
    local gh_user
    gh_user=$(yaml_get ".profiles[] | select(.name == \"$name\") | .gh_username" "$CONFIG" 2>/dev/null || echo "")
    if [[ -n "$gh_user" && "$gh_user" != "null" ]]; then
      echo "     gh auth login -u $gh_user"
    fi
  done
  echo "  2. Test it in a repo:"
  echo "     cd <some-repo>"
  echo "     gh account-guard status"
  echo "     gh account-guard fix"
  echo "     gh account-guard switch"
}

