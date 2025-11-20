#!/usr/bin/env bash
# Config command: Manage extension settings (default directory, etc.)

cmd_config() {
  local subcmd="${1:-}"
  
  case "$subcmd" in
    get)
      local key="${2:-}"
      if [[ -z "$key" ]]; then
        echo "Usage: gh account-guard config get <key>"
        echo ""
        echo "Available keys:"
        echo "  default_directory  - Default directory for file browser"
        exit 1
      fi
      
      case "$key" in
        default_directory)
          local current_default
          current_default=$(get_default_directory)
          echo "$current_default"
          ;;
        *)
          echo "Unknown key: $key" >&2
          echo "Available keys: default_directory"
          exit 1
          ;;
      esac
      ;;
    
    set)
      local key="${2:-}"
      local value="${3:-}"
      
      if [[ -z "$key" ]] || [[ -z "$value" ]]; then
        echo "Usage: gh account-guard config set <key> <value>"
        echo ""
        echo "Available keys:"
        echo "  default_directory  - Default directory for file browser"
        exit 1
      fi
      
      case "$key" in
        default_directory)
          # Expand ~
          value=${value/#\~/$HOME}
          # Trim whitespace
          value=$(echo "$value" | xargs)
          
          if [[ ! -d "$value" ]]; then
            echo "⚠️  Directory '$value' does not exist." >&2
            exit 1
          fi
          
          set_default_directory "$value"
          if has_gum; then
            gum style --foreground 10 "✅ Default directory set to: $value"
          else
            echo "✅ Default directory set to: $value"
          fi
          ;;
        *)
          echo "Unknown key: $key" >&2
          echo "Available keys: default_directory"
          exit 1
          ;;
      esac
      ;;
    
    "")
      # Show all current settings with nice formatting
      print_config
      ;;
    
    *)
      echo "Unknown subcommand: $subcmd" >&2
      echo ""
      echo "Usage:"
      echo "  gh account-guard config              - Show all settings"
      echo "  gh account-guard config get <key>  - Get a setting value"
      echo "  gh account-guard config set <key> <value>  - Set a setting value"
      exit 1
      ;;
  esac
}

# Print configuration in a nice formatted way
print_config() {
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
  
  # Header
  if has_gum; then
    gum style --foreground 212 --bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    gum style --foreground 212 --bold "⚙️  gh-account-guard Configuration"
    gum style --foreground 212 --bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "${BOLD}⚙️  gh-account-guard Configuration${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi
  echo ""
  
  # Config file path
  if has_gum; then
    echo -n "📄 Config file: "
    gum style --foreground 14 "$CONFIG"
  else
    echo "${CYAN}📄 Config file:${RESET} $CONFIG"
  fi
  echo ""
  
  # Default directory
  local current_default
  current_default=$(get_default_directory)
  if has_gum; then
    echo -n "📁 Default directory: "
    gum style --foreground 14 "$current_default"
  else
    echo "${CYAN}📁 Default directory:${RESET} $current_default"
  fi
  echo ""
  
  # Profiles section
  local profile_count
  profile_count=$(yaml_get '.profiles | length' "$CONFIG" 2>/dev/null || echo "0")
  
  if [[ "$profile_count" -eq 0 ]]; then
    if has_gum; then
      gum style --foreground 196 "⚠️  No profiles configured"
      echo ""
      echo "Run 'gh account-guard setup' to add profiles."
    else
      echo "${YELLOW}⚠️  No profiles configured${RESET}"
      echo ""
      echo "Run 'gh account-guard setup' to add profiles."
    fi
    return 0
  fi
  
  if has_gum; then
    gum style --foreground 212 --bold "📋 Profiles ($profile_count)"
  else
    echo "${BOLD}📋 Profiles ($profile_count)${RESET}"
  fi
  echo ""
  
  # Print each profile
  for ((i=0; i<profile_count; i++)); do
    local profile_name
    local gh_username
    local git_name
    local git_email
    local signing_key
    local gpgsign
    local gpgformat
    local remote_match
    
    profile_name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
    gh_username=$(yaml_get ".profiles[$i].gh_username" "$CONFIG" 2>/dev/null || echo "")
    git_name=$(yaml_get ".profiles[$i].git.name" "$CONFIG" 2>/dev/null || echo "")
    git_email=$(yaml_get ".profiles[$i].git.email" "$CONFIG" 2>/dev/null || echo "")
    signing_key=$(yaml_get ".profiles[$i].git.signingkey" "$CONFIG" 2>/dev/null || echo "")
    gpgsign=$(yaml_get ".profiles[$i].git.gpgsign" "$CONFIG" 2>/dev/null || echo "false")
    gpgformat=$(yaml_get ".profiles[$i].git.gpgformat" "$CONFIG" 2>/dev/null || echo "ssh")
    remote_match=$(yaml_get ".profiles[$i].remote_match" "$CONFIG" 2>/dev/null || echo "")
    
    # Profile header
    if has_gum; then
      echo -n "  ┌─ Profile: "
      gum style --foreground 212 --bold "$profile_name"
    else
      echo "  ${CYAN}┌─ Profile: ${BOLD}$profile_name${RESET}"
    fi
    
    # GitHub username
    if [[ -n "$gh_username" && "$gh_username" != "null" ]]; then
      if has_gum; then
        echo -n "  │  GitHub: "
        gum style --foreground 14 "$gh_username"
      else
        echo "  ${CYAN}│${RESET}  GitHub: $gh_username"
      fi
    fi
    
    # Paths
    local path_type
    path_type=$(yaml_get ".profiles[$i].path | type" "$CONFIG" 2>/dev/null || echo "!!str")
    
    if [[ "$path_type" == *"seq"* ]] || [[ "$path_type" == *"array"* ]]; then
      # Multiple paths
      local path_count
      path_count=$(yaml_get ".profiles[$i].path | length" "$CONFIG" 2>/dev/null || echo "0")
      if has_gum; then
        echo "  │  Paths:"
      else
        echo "  ${CYAN}│${RESET}  Paths:"
      fi
      for ((j=0; j<path_count; j++)); do
        local path_val
        path_val=$(yaml_get ".profiles[$i].path[$j]" "$CONFIG" 2>/dev/null || echo "")
        if [[ -n "$path_val" ]]; then
          if has_gum; then
            echo -n "  │    • "
            gum style --foreground 14 "$path_val"
          else
            echo "  ${CYAN}│${RESET}    • $path_val"
          fi
        fi
      done
    else
      # Single path
      local path_val
      path_val=$(yaml_get ".profiles[$i].path" "$CONFIG" 2>/dev/null || echo "")
      if [[ -n "$path_val" && "$path_val" != "null" ]]; then
        if has_gum; then
          echo -n "  │  Path: "
          gum style --foreground 14 "$path_val"
        else
          echo "  ${CYAN}│${RESET}  Path: $path_val"
        fi
      fi
    fi
    
    # Git config
    if has_gum; then
      echo "  │  Git:"
    else
      echo "  ${CYAN}│${RESET}  Git:"
    fi
    if [[ -n "$git_name" && "$git_name" != "null" ]]; then
      if has_gum; then
        echo -n "  │    Name:  "
        gum style --foreground 14 "$git_name"
      else
        echo "  ${CYAN}│${RESET}    Name:  $git_name"
      fi
    fi
    if [[ -n "$git_email" && "$git_email" != "null" ]]; then
      if has_gum; then
        echo -n "  │    Email: "
        gum style --foreground 14 "$git_email"
      else
        echo "  ${CYAN}│${RESET}    Email: $git_email"
      fi
    fi
    
    # Signing
    if [[ "$gpgsign" == "true" ]]; then
      if has_gum; then
        echo -n "  │    Signing: "
        gum style --foreground 10 "enabled"
        echo " ($gpgformat)"
      else
        echo "  ${CYAN}│${RESET}    Signing: ${GREEN}enabled${RESET} ($gpgformat)"
      fi
      if [[ -n "$signing_key" && "$signing_key" != "null" && -n "$signing_key" ]]; then
        if has_gum; then
          echo -n "  │    Key: "
          gum style --foreground 14 "$signing_key"
        else
          echo "  ${CYAN}│${RESET}    Key: $signing_key"
        fi
      fi
    else
      if has_gum; then
        echo -n "  │    Signing: "
        gum style --foreground 11 "disabled"
      else
        echo "  ${CYAN}│${RESET}    Signing: ${YELLOW}disabled${RESET}"
      fi
    fi
    
    # Remote match
    if [[ -n "$remote_match" && "$remote_match" != "null" ]]; then
      if has_gum; then
        echo -n "  │  Remote match: "
        gum style --foreground 14 "$remote_match"
      else
        echo "  ${CYAN}│${RESET}  Remote match: $remote_match"
      fi
    fi
    
    # Profile footer
    if has_gum; then
      echo "  └─"
    else
      echo "  ${CYAN}└─${RESET}"
    fi
    echo ""
  done
  
  # Footer with usage info
  if has_gum; then
    gum style --foreground 240 "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "To change settings:"
    echo -n "  "
    gum style --foreground 14 "gh account-guard config set <key> <value>"
    echo ""
    echo "Available keys:"
    echo -n "  "
    gum style --foreground 14 "default_directory"
    echo "  - Default directory for file browser"
  else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "To change settings:"
    echo "  ${CYAN}gh account-guard config set <key> <value>${RESET}"
    echo ""
    echo "Available keys:"
    echo "  ${CYAN}default_directory${RESET}  - Default directory for file browser"
  fi
}
