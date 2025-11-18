#!/usr/bin/env bash
# Command implementations for gh-account-guard
cmd_setup() {
  mkdir -p "$(dirname "$CONFIG")"
  
  local overwrite=false
  local add_mode=false
  
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
      "Add a new profile"*) add_mode=true ;;
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

cmd_init() {
  mkdir -p "$(dirname "$CONFIG")"
  if [[ -e "$CONFIG" ]]; then
    echo "Config already exists at $CONFIG"
    echo "Run 'gh account-guard setup' for interactive setup, or edit the file directly."
    exit 0
  fi
  cat > "$CONFIG" <<'YAML'
# Map local paths (prefix-glob) to profiles.
# Longest matching path wins.
# Run 'gh account-guard setup' for interactive configuration.
profiles:
  - name: company
    path: ~/work/company/            # Update with your company repos path
    gh_username: yourcompany-username # Update with your company GitHub username
    git:
      name: "Your Name"
      email: "you@company.com"        # Update with your company email
      signingkey: ""                  # Optional: SSH or GPG signing key
      gpgsign: false
      gpgformat: ssh
    remote_match: "github.com/YourCompany/"  # Optional: remote URL pattern
  - name: personal
    path: ~/                           # Default: matches everything else
    gh_username: yourpersonal-username # Update with your personal GitHub username
    git:
      name: "Your Name (Personal)"
      email: "you+personal@example.com"  # Update with your personal email
      signingkey: ""                      # Optional: SSH or GPG signing key
      gpgsign: false
      gpgformat: ssh
YAML
  echo "✅ Created example config at $CONFIG"
  echo ""
  echo "Edit the file directly, or run 'gh account-guard setup' for interactive setup."
}

cmd_status() {
  [[ -f "$CONFIG" ]] || { echo "No config at $CONFIG. Run: gh account-guard setup"; exit 1; }
  idx=$(match_profile "$PWD")
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
  name=$(yaml_get ".profiles[$idx].name" "$CONFIG")
  gh_u=$(yaml_get ".profiles[$idx].gh_username" "$CONFIG")
  git_name=$(yaml_get ".profiles[$idx].git.name" "$CONFIG")
  git_email=$(yaml_get ".profiles[$idx].git.email" "$CONFIG")
  git_gpgsign=$(yaml_get ".profiles[$idx].git.gpgsign" "$CONFIG")
  
  echo "Matched profile: $name (gh user: $gh_u)"
  echo ""
  
  # Check if gh auth matches
  local current_gh_user
  current_gh_user=$(gh auth status 2>&1 | grep -B 2 "Active account: true" | grep "Logged in to" | sed 's/.*account //' | sed 's/ .*//' 2>/dev/null || echo "")
  
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

cmd_fix() {
  [[ -d .git ]] || { echo "Not a git repo."; exit 1; }
  idx=$(match_profile "$PWD") || true
  [[ -n "$idx" ]] || { echo "No matching profile for $PWD"; exit 1; }

  name=$(yaml_get ".profiles[$idx].git.name" "$CONFIG")
  email=$(yaml_get ".profiles[$idx].git.email" "$CONFIG")
  skey=$(yaml_get ".profiles[$idx].git.signingkey" "$CONFIG")
  gpgf=$(yaml_get ".profiles[$idx].git.gpgformat" "$CONFIG")
  gpgs=$(yaml_get ".profiles[$idx].git.gpgsign" "$CONFIG")
  rmatch=$(yaml_get ".profiles[$idx].remote_match" "$CONFIG" 2>/dev/null || echo "")

  if [[ -n "$rmatch" ]]; then
    remote=$(git config --get remote.origin.url || echo "")
    if [[ -n "$remote" && "$remote" != *"$rmatch"* ]]; then
      echo "⚠️  Remote '$remote' does not match '$rmatch' for this profile."
    fi
  fi

  git config --local user.name  "$name"
  git config --local user.email "$email"
  [[ -n "$skey" ]] && git config --local user.signingkey "$skey"
  [[ -n "$gpgf" ]] && git config --local gpg.format "$gpgf"
  [[ -n "$gpgs" ]] && git config --local commit.gpgsign "$gpgs"

  echo "✅ Set repo identity to: $name <$email>; signing=$(git config --get commit.gpgsign)"
}

cmd_switch() {
  idx=$(match_profile "$PWD") || true
  [[ -n "$idx" ]] || { echo "No matching profile for $PWD"; exit 1; }
  gh_u=$(yaml_get ".profiles[$idx].gh_username" "$CONFIG")
  if [[ -z "$gh_u" || "$gh_u" == "null" ]]; then
    echo "No gh_username configured for this profile."
    exit 1
  fi
  gh auth switch -u "$gh_u"
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

# Silent auto-enforcement function (used by shell hooks)
cmd_auto_enforce() {
  # Silently enforce profile settings without any output
  # Only show errors if something goes wrong
  
  # Ensure CONFIG is set
  [[ -n "${CONFIG:-}" ]] || CONFIG="$HOME/.config/gh/account-guard.yml"
  
  # Check if config exists
  [[ -f "$CONFIG" ]] || return 0
  
  # Check if we're in a git repo
  [[ -d .git ]] || return 0
  
  # Find matching profile
  local idx
  idx=$(match_profile "$PWD" 2>/dev/null || echo "")
  [[ -n "$idx" ]] || return 0
  
  # Get profile settings
  local gh_u
  local git_name
  local git_email
  local skey
  local gpgf
  local gpgs
  
  gh_u=$(yaml_get ".profiles[$idx].gh_username" "$CONFIG" 2>/dev/null || echo "")
  git_name=$(yaml_get ".profiles[$idx].git.name" "$CONFIG" 2>/dev/null || echo "")
  git_email=$(yaml_get ".profiles[$idx].git.email" "$CONFIG" 2>/dev/null || echo "")
  skey=$(yaml_get ".profiles[$idx].git.signingkey" "$CONFIG" 2>/dev/null || echo "")
  gpgf=$(yaml_get ".profiles[$idx].git.gpgformat" "$CONFIG" 2>/dev/null || echo "")
  gpgs=$(yaml_get ".profiles[$idx].git.gpgsign" "$CONFIG" 2>/dev/null || echo "")
  
  # NOTE: We do NOT automatically switch gh auth here because gh auth switch is GLOBAL
  # and affects all terminals/editors. This causes problems when working with multiple
  # projects simultaneously. Users should manually run 'gh account-guard switch' if
  # they want to change the active gh auth account.
  # 
  # The pre-commit hook validates git identity (which is per-repo), not gh auth.
  # Git commits use git config, not gh auth, so this is sufficient for compliance.
  
  # Check and apply git identity if needed
  local current_name
  local current_email
  current_name=$(git config --get user.name 2>/dev/null || echo "")
  current_email=$(git config --get user.email 2>/dev/null || echo "")
  current_gpgsign=$(git config --get commit.gpgsign 2>/dev/null || echo "false")
  
  # Always ensure git identity matches profile (this is per-repo, safe to auto-set)
  # This enables automatic commits/pushes without manual intervention
  if [[ "$current_name" != "$git_name" ]] || \
     [[ "$current_email" != "$git_email" ]] || \
     [[ "$current_gpgsign" != "$gpgs" ]]; then
    git config --local user.name "$git_name" 2>/dev/null || true
    git config --local user.email "$git_email" 2>/dev/null || true
    [[ -n "$skey" ]] && git config --local user.signingkey "$skey" 2>/dev/null || true
    [[ -n "$gpgf" ]] && git config --local gpg.format "$gpgf" 2>/dev/null || true
    [[ -n "$gpgs" ]] && git config --local commit.gpgsign "$gpgs" 2>/dev/null || true
  fi
  
  return 0
}

cmd_install_git_hook() {
  local global="${1:-}"
  
  if [[ "$global" == "--global" ]] || [[ "$global" == "-g" ]]; then
    # Install globally via git template directory
    cmd_install_git_hook_global
    return $?
  fi
  
  # Install a git pre-commit hook that validates git identity matches profile
  [[ -d .git ]] || { echo "Not a git repository. Run this command from inside a git repo."; exit 1; }
  
  local hook_file=".git/hooks/pre-commit"
  
  # Create the hook that validates identity before commit
  # This hook calls back to gh account-guard to validate the identity
  cat > "$hook_file" <<'HOOK'
#!/usr/bin/env bash
# gh-account-guard pre-commit hook
# Validates that git identity matches the profile for this directory
# This prevents accidental commits with the wrong identity

set -e

# Check if gh account-guard is available
command -v gh >/dev/null || exit 0

# First, auto-enforce to ensure identity is correct
gh account-guard auto-enforce >/dev/null 2>&1 || true

# Get current git identity after enforcement
current_name=$(git config --get user.name 2>/dev/null || echo "")
current_email=$(git config --get user.email 2>/dev/null || echo "")

# If no identity is set, allow commit (git will use global config)
if [[ -z "$current_name" ]] || [[ -z "$current_email" ]]; then
  exit 0
fi

# Get expected identity by calling status and parsing output
status_output=$(gh account-guard status 2>&1 || echo "")

# Check if there's a matched profile
if ! echo "$status_output" | grep -q "Matched profile:"; then
  # No profile matches - allow commit
  exit 0
fi

# Extract expected values from status output
# Look for lines like "✓ user.name = value" or "⚠️  user.name = current (should be: expected)"
expected_name=""
expected_email=""

# Try to get expected name
name_line=$(echo "$status_output" | grep "user.name" | head -1)
if echo "$name_line" | grep -q "should be:"; then
  expected_name=$(echo "$name_line" | sed 's/.*should be: //' | xargs)
elif echo "$name_line" | grep -q "✓"; then
  expected_name=$(echo "$name_line" | sed 's/.*= //' | xargs)
fi

# Try to get expected email
email_line=$(echo "$status_output" | grep "user.email" | head -1)
if echo "$email_line" | grep -q "should be:"; then
  expected_email=$(echo "$email_line" | sed 's/.*should be: //' | xargs)
elif echo "$email_line" | grep -q "✓"; then
  expected_email=$(echo "$email_line" | sed 's/.*= //' | xargs)
fi

# If we couldn't determine expected values, allow commit (fail open)
if [[ -z "$expected_name" ]] || [[ -z "$expected_email" ]]; then
  exit 0
fi

# Compare current vs expected
if [[ "$current_name" != "$expected_name" ]] || [[ "$current_email" != "$expected_email" ]]; then
  echo "❌ Pre-commit hook: Git identity mismatch!" >&2
  echo "" >&2
  echo "Current identity:" >&2
  echo "  user.name  = $current_name" >&2
  echo "  user.email = $current_email" >&2
  echo "" >&2
  echo "Expected identity for this profile:" >&2
  echo "  user.name  = $expected_name" >&2
  echo "  user.email = $expected_email" >&2
  echo "" >&2
  echo "The identity has been auto-corrected. Please try committing again." >&2
  echo "" >&2
  echo "To bypass this check (not recommended):" >&2
  echo "  git commit --no-verify" >&2
  exit 1
fi

exit 0
HOOK

  chmod +x "$hook_file"
  
  if has_gum; then
    gum style --foreground 10 "✅ Installed pre-commit hook at $hook_file"
    gum style "This hook will block commits if your git identity doesn't match the profile."
    echo ""
    gum style "To test, try committing with wrong identity - it will be blocked."
  else
    echo "✅ Installed pre-commit hook at $hook_file"
    echo "This hook will block commits if your git identity doesn't match the profile."
    echo ""
    echo "To test, try committing with wrong identity - it will be blocked."
  fi
}

cmd_install_git_hook_global() {
  # Install pre-commit hook globally via git template directory
  # This will apply to all new repos and can be applied to existing repos
  
  local template_dir="$HOME/.git-template"
  local hooks_dir="$template_dir/hooks"
  local hook_file="$hooks_dir/pre-commit"
  
  # Create template directory structure
  mkdir -p "$hooks_dir" 2>/dev/null || {
    if has_gum; then
      gum style --foreground 196 "❌ Failed to create template directory: $template_dir"
    else
      echo "❌ Failed to create template directory: $template_dir" >&2
    fi
    exit 1
  }
  
  # Create the hook (same as per-repo hook)
  cat > "$hook_file" <<'HOOK'
#!/usr/bin/env bash
# gh-account-guard pre-commit hook
# Validates that git identity matches the profile for this directory
# This prevents accidental commits with the wrong identity

set -e

# Check if gh account-guard is available
command -v gh >/dev/null || exit 0

# First, auto-enforce to ensure identity is correct
gh account-guard auto-enforce >/dev/null 2>&1 || true

# Get current git identity after enforcement
current_name=$(git config --get user.name 2>/dev/null || echo "")
current_email=$(git config --get user.email 2>/dev/null || echo "")

# If no identity is set, allow commit (git will use global config)
if [[ -z "$current_name" ]] || [[ -z "$current_email" ]]; then
  exit 0
fi

# Get expected identity by calling status and parsing output
status_output=$(gh account-guard status 2>&1 || echo "")

# Check if there's a matched profile
if ! echo "$status_output" | grep -q "Matched profile:"; then
  # No profile matches - allow commit
  exit 0
fi

# Extract expected values from status output
# Look for lines like "✓ user.name = value" or "⚠️  user.name = current (should be: expected)"
expected_name=""
expected_email=""

# Try to get expected name
name_line=$(echo "$status_output" | grep "user.name" | head -1)
if echo "$name_line" | grep -q "should be:"; then
  expected_name=$(echo "$name_line" | sed 's/.*should be: //' | xargs)
elif echo "$name_line" | grep -q "✓"; then
  expected_name=$(echo "$name_line" | sed 's/.*= //' | xargs)
fi

# Try to get expected email
email_line=$(echo "$status_output" | grep "user.email" | head -1)
if echo "$email_line" | grep -q "should be:"; then
  expected_email=$(echo "$email_line" | sed 's/.*should be: //' | xargs)
elif echo "$email_line" | grep -q "✓"; then
  expected_email=$(echo "$email_line" | sed 's/.*= //' | xargs)
fi

# If we couldn't determine expected values, allow commit (fail open)
if [[ -z "$expected_name" ]] || [[ -z "$expected_email" ]]; then
  exit 0
fi

# Compare current vs expected
if [[ "$current_name" != "$expected_name" ]] || [[ "$current_email" != "$expected_email" ]]; then
  echo "❌ Pre-commit hook: Git identity mismatch!" >&2
  echo "" >&2
  echo "Current identity:" >&2
  echo "  user.name  = $current_name" >&2
  echo "  user.email = $current_email" >&2
  echo "" >&2
  echo "Expected identity for this profile:" >&2
  echo "  user.name  = $expected_name" >&2
  echo "  user.email = $expected_email" >&2
  echo "" >&2
  echo "The identity has been auto-corrected. Please try committing again." >&2
  echo "" >&2
  echo "To bypass this check (not recommended):" >&2
  echo "  git commit --no-verify" >&2
  exit 1
fi

exit 0
HOOK

  chmod +x "$hook_file"
  
  # Set git config to use this template directory
  git config --global init.templateDir "$template_dir"
  
  if has_gum; then
    gum style --foreground 10 "✅ Installed global git hook template"
    gum style "   Location: $hook_file"
    gum style ""
    gum style "This hook will be automatically added to:"
    gum style "  • All new repos (git init, git clone)"
    gum style "  • Existing repos (run 'git init' in them to apply)"
    echo ""
    gum style --foreground 11 "To apply to existing repos, run:"
    gum style "  find ~/work -name .git -type d -execdir git init \\;"
    gum style "  find ~/personal -name .git -type d -execdir git init \\;"
  else
    echo "✅ Installed global git hook template"
    echo "   Location: $hook_file"
    echo ""
    echo "This hook will be automatically added to:"
    echo "  • All new repos (git init, git clone)"
    echo "  • Existing repos (run 'git init' in them to apply)"
    echo ""
    echo ""
    echo "To apply to existing repos, run:"
    echo "  gh account-guard apply-hook-to-repos"
  fi
}

cmd_apply_hook_to_existing_repos() {
  # Apply the global hook template to all existing git repos
  # This scans configured profile paths and applies the hook to repos in those paths
  
  local template_dir
  template_dir=$(git config --global init.templateDir 2>/dev/null || echo "")
  
  if [[ -z "$template_dir" ]] || [[ ! -f "$template_dir/hooks/pre-commit" ]]; then
    if has_gum; then
      gum style --foreground 196 "❌ Global git hook template not found"
      gum style "   Run 'gh account-guard install-git-hook --global' first"
    else
      echo "❌ Global git hook template not found" >&2
      echo "   Run 'gh account-guard install-git-hook --global' first" >&2
    fi
    exit 1
  fi
  
  if [[ ! -f "$CONFIG" ]]; then
    if has_gum; then
      gum style --foreground 196 "❌ No configuration file found"
      gum style "   Run 'gh account-guard setup' first"
    else
      echo "❌ No configuration file found" >&2
      echo "   Run 'gh account-guard setup' first" >&2
    fi
    exit 1
  fi
  
  if has_gum; then
    gum style --foreground 212 --bold "Applying hook to existing repos..."
  else
    echo "Applying hook to existing repos..."
  fi
  
  local applied_count=0
  local scanned_count=0
  local profile_count
  profile_count=$(yaml_get '.profiles | length' "$CONFIG" 2>/dev/null || echo "0")
  
  for ((i=0; i<profile_count; i++)); do
    local profile_name
    profile_name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
    
    if [[ -n "$profile_name" ]]; then
      if has_gum; then
        echo -n "  Scanning $profile_name profile paths... " >&2
      else
        echo "  Scanning $profile_name profile paths..."
      fi
    fi
    # Get profile paths
    local path_type
    path_type=$(yaml_get ".profiles[$i].path | type" "$CONFIG" 2>/dev/null || echo "!!str")
    
    local paths=()
    if [[ "$path_type" == *"seq"* ]] || [[ "$path_type" == *"array"* ]]; then
      # Multiple paths
      local path_count
      path_count=$(yaml_get ".profiles[$i].path | length" "$CONFIG" 2>/dev/null || echo "0")
      for ((j=0; j<path_count; j++)); do
        local path_val
        path_val=$(yaml_get ".profiles[$i].path[$j]" "$CONFIG" 2>/dev/null || echo "")
        if [[ -n "$path_val" ]]; then
          path_val="${path_val/#\~/$HOME}"
          paths+=("$path_val")
        fi
      done
    else
      # Single path
      local path_val
      path_val=$(yaml_get ".profiles[$i].path" "$CONFIG" 2>/dev/null || echo "")
      if [[ -n "$path_val" ]]; then
        path_val="${path_val/#\~/$HOME}"
        paths+=("$path_val")
      fi
    fi
    
    # Apply hook to all git repos in these paths
    for path in "${paths[@]}"; do
      if [[ ! -d "$path" ]]; then
        continue
      fi
      
      # Find all .git directories in this path
      local path_count=0
      while IFS= read -r -d '' git_dir; do
        local repo_dir
        repo_dir=$(dirname "$git_dir")
        
        # Copy hook from template
        if [[ -f "$template_dir/hooks/pre-commit" ]]; then
          cp "$template_dir/hooks/pre-commit" "$git_dir/hooks/pre-commit" 2>/dev/null || true
          chmod +x "$git_dir/hooks/pre-commit" 2>/dev/null || true
          ((applied_count++))
          ((path_count++))
        fi
      done < <(find "$path" -name ".git" -type d -print0 2>/dev/null)
      
      if [[ -n "$profile_name" ]] && [[ $path_count -gt 0 ]]; then
        if has_gum; then
          echo "✓ Found $path_count repos" >&2
        else
          echo "  ✓ Found $path_count repos"
        fi
      fi
    done
  done
  
  if has_gum; then
    gum style --foreground 10 "✅ Applied hook to $applied_count existing repos"
  else
    echo "✅ Applied hook to $applied_count existing repos"
  fi
}

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

cmd_install() {
  # Install both shell hook and git pre-commit hook
  local install_shell=true
  local install_git=true
  local shell_arg=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-shell-hook)
        install_shell=false
        shift
        ;;
      --no-git-hook)
        install_git=false
        shift
        ;;
      --fish|-f|--zsh|-z|--bash|-b)
        shell_arg="$1"
        shift
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: gh account-guard install [--fish|--zsh|--bash] [--no-shell-hook] [--no-git-hook]" >&2
        exit 1
        ;;
    esac
  done
  
  local installed_anything=false
  
  # Install shell hook
  if [[ "$install_shell" == true ]]; then
    echo ""
    if has_gum; then
      gum style --foreground 212 --bold "Installing shell hook..."
    else
      echo "Installing shell hook..."
    fi
    
    local shell_hook_output
    if [[ -n "$shell_arg" ]]; then
      shell_hook_output=$(cmd_install_shell_hook "$shell_arg")
    else
      shell_hook_output=$(cmd_install_shell_hook)
    fi
    
    local shell_config=""
    local current_shell="${SHELL##*/}"
    
    # Detect shell config file
    if [[ -n "$shell_arg" ]]; then
      case "$shell_arg" in
        --fish|-f) shell_config="$HOME/.config/fish/config.fish" ;;
        --zsh|-z) shell_config="$HOME/.zshrc" ;;
        --bash|-b) shell_config="$HOME/.bashrc" ;;
      esac
    else
      case "$current_shell" in
        fish) shell_config="$HOME/.config/fish/config.fish" ;;
        zsh) shell_config="$HOME/.zshrc" ;;
        bash) shell_config="$HOME/.bashrc" ;;
        *)
          echo "⚠️  Could not detect shell. Please specify: --fish, --zsh, or --bash" >&2
          echo "" >&2
          echo "Shell hook code:" >&2
          echo "$shell_hook_output" >&2
          echo "" >&2
          echo "Manually add the above to your shell config file." >&2
          ;;
      esac
    fi
    
    if [[ -n "$shell_config" ]]; then
      # Check if already installed
      if grep -q "gh-account-guard shell hook" "$shell_config" 2>/dev/null; then
        if has_gum; then
          gum style --foreground 11 "⚠️  Shell hook already installed in $shell_config"
        else
          echo "⚠️  Shell hook already installed in $shell_config"
        fi
      else
        echo "$shell_hook_output" >> "$shell_config"
        if has_gum; then
          gum style --foreground 10 "✅ Shell hook installed in $shell_config"
        else
          echo "✅ Shell hook installed in $shell_config"
        fi
        installed_anything=true
      fi
    fi
  fi
  
  # Install git hook
  if [[ "$install_git" == true ]]; then
    echo ""
    if has_gum; then
      gum style --foreground 212 --bold "Installing git pre-commit hook..."
    else
      echo "Installing git pre-commit hook..."
    fi
    
    # Default to global installation (all repos automatically)
    # This matches the user's requirement: all repos should have hooks based on path config
    local install_global=true
    
    # Only prompt if we're in a repo AND have interactive input available
    # Default to global since that's what users want
    if [[ -d .git ]] && [ -t 0 ] 2>/dev/null && [ -t 1 ] 2>/dev/null; then
      # Try to ask, but with very short timeout and default to global
      if has_gum 2>/dev/null; then
        echo ""
        gum style "Install git hook:" 2>/dev/null || true
        local hook_choice
        # Default to global, very short timeout (2 seconds)
        hook_choice=$(timeout 2 gum choose --selected="Global (all repos automatically)" "Global (all repos automatically)" "This repo only" 2>/dev/null || echo "Global (all repos automatically)")
        if [[ "$hook_choice" == *"This repo only"* ]]; then
          install_global=false
        fi
      else
        echo ""
        echo "Install hook:"
        echo "  1) Global (all repos automatically) [recommended]"
        echo "  2) This repo only"
        echo -n "Choose [1-2] (default: 1, auto-selecting in 2s): "
        # Use a very short timeout and default to global
        if read -t 2 hook_choice 2>/dev/null; then
          if [[ "$hook_choice" == "2" ]]; then
            install_global=false
          fi
        fi
        echo ""
      fi
    fi
    
    if [[ "$install_global" == true ]]; then
      if has_gum 2>/dev/null; then
        gum style --foreground 14 "→ Installing globally (all repos automatically)" 2>/dev/null || echo "→ Installing globally (all repos automatically)"
      else
        echo "→ Installing globally (all repos automatically)"
      fi
    fi
    
    if [[ "$install_global" == true ]]; then
      echo ""
      if has_gum; then
        gum style --foreground 212 "Installing global git hook template..."
      else
        echo "Installing global git hook template..."
      fi
      cmd_install_git_hook_global
      installed_anything=true
      
      # Automatically apply to existing repos (with progress)
      echo ""
      if has_gum; then
        gum style --foreground 212 "Applying hook to existing repos in configured paths..."
        gum style "   This may take a moment..."
      else
        echo "Applying hook to existing repos in configured paths..."
        echo "   This may take a moment..."
      fi
      cmd_apply_hook_to_existing_repos 2>/dev/null || {
        if has_gum; then
          gum style --foreground 11 "⚠️  Could not apply to existing repos (this is optional)"
        else
          echo "⚠️  Could not apply to existing repos (this is optional)"
        fi
      }
    elif [[ -d .git ]]; then
      echo ""
      if has_gum; then
        gum style --foreground 212 "Installing hook in current repo..."
      else
        echo "Installing hook in current repo..."
      fi
      cmd_install_git_hook
      installed_anything=true
    else
      if has_gum; then
        gum style --foreground 11 "⚠️  Not in a git repository. Skipping git hook installation."
        gum style "   Run 'gh account-guard install-git-hook' from inside a git repo to install it."
        gum style "   Or run 'gh account-guard install-git-hook --global' to install globally."
      else
        echo "⚠️  Not in a git repository. Skipping git hook installation."
        echo "   Run 'gh account-guard install-git-hook' from inside a git repo to install it."
        echo "   Or run 'gh account-guard install-git-hook --global' to install globally."
      fi
    fi
  fi
  
  # Summary
  echo ""
  if [[ "$installed_anything" == true ]]; then
    if has_gum; then
      gum style --foreground 10 --bold "✅ Installation complete!"
    else
      echo "✅ Installation complete!"
    fi
    echo ""
    echo "What was installed:"
    [[ "$install_shell" == true ]] && echo "  ✓ Shell hook (auto-enforces on directory change)"
    [[ "$install_git" == true && -d .git ]] && echo "  ✓ Git pre-commit hook (validates identity before commits)"
    echo ""
    echo "Next steps:"
    if [[ "$install_shell" == true ]]; then
      echo "  - Open a new terminal or run: source $shell_config"
    fi
    if [[ "$install_git" == true && -d .git ]]; then
      echo "  - Try committing to test the pre-commit hook"
    fi
  else
    if has_gum; then
      gum style --foreground 11 "⚠️  Nothing was installed."
    else
      echo "⚠️  Nothing was installed."
    fi
  fi
}

cmd_install_shell_hook() {
  local shell_arg="${1:-}"
  local current_shell=""
  
  # Check for explicit shell argument
  case "$shell_arg" in
    --fish|-f) current_shell="fish" ;;
    --zsh|-z) current_shell="zsh" ;;
    --bash|-b) current_shell="bash" ;;
    "")
      # Auto-detect shell
      current_shell="${SHELL##*/}"
      
      # If shell not detected or is sh, try to detect from parent process
      if [[ -z "$current_shell" ]] || [[ "$current_shell" == "sh" ]]; then
        local parent_cmd
        parent_cmd=$(ps -p $PPID -o comm= 2>/dev/null || echo "")
        if [[ "$parent_cmd" == *"fish"* ]]; then
          current_shell="fish"
        elif [[ "$parent_cmd" == *"zsh"* ]]; then
          current_shell="zsh"
        elif [[ "$parent_cmd" == *"bash"* ]]; then
          current_shell="bash"
        fi
      fi
      ;;
    *)
      echo "Unknown option: $shell_arg" >&2
      echo "Usage: gh account-guard install-shell-hook [--fish|--zsh|--bash]" >&2
      exit 1
      ;;
  esac
  
  case "$current_shell" in
    fish)
      cat <<'FISH'
# --- gh-account-guard shell hook ---
# This automatically enforces the correct git identity when you change directories.
# Git commits/pushes use git config (per-repo), so this enables automatic commits
# without manual credential switching. Works even when multiple editors are open.
function __gh_account_guard_pwd --on-variable PWD
  command -v gh >/dev/null; or return
  # Set git config per-repo automatically (safe - each repo has its own config)
  gh account-guard auto-enforce >/dev/null 2>&1; or true
end
# Run on shell startup (when opening terminal in editor)
__gh_account_guard_pwd

# Alias for convenience
alias ag='gh account-guard'
# --- end gh-account-guard hook ---
FISH
      ;;
    zsh)
      cat <<'ZSH'
# --- gh-account-guard shell hook ---
# This automatically enforces the correct git identity when you change directories.
# Git commits/pushes use git config (per-repo), so this enables automatic commits
# without manual credential switching. Works even when multiple editors are open.
function __gh_account_guard_chpwd() {
  command -v gh >/dev/null || return
  # Set git config per-repo automatically (safe - each repo has its own config)
  gh account-guard auto-enforce >/dev/null 2>&1 || true
}
autoload -U add-zsh-hook 2>/dev/null && add-zsh-hook chpwd __gh_account_guard_chpwd
# Also run on shell startup (when opening terminal in editor)
__gh_account_guard_chpwd

# Alias for convenience
alias ag='gh account-guard'
# --- end gh-account-guard hook ---
ZSH
      ;;
    bash)
      cat <<'BASH'
# --- gh-account-guard shell hook ---
# This automatically enforces the correct git identity when you change directories.
# Git commits/pushes use git config (per-repo), so this enables automatic commits
# without manual credential switching. Works even when multiple editors are open.
function __gh_account_guard_chpwd() {
  command -v gh >/dev/null || return
  # Set git config per-repo automatically (safe - each repo has its own config)
  gh account-guard auto-enforce >/dev/null 2>&1 || true
}
PROMPT_COMMAND="__gh_account_guard_chpwd; $PROMPT_COMMAND"

# Alias for convenience
alias ag='gh account-guard'
# --- end gh-account-guard hook ---
BASH
      ;;
    *)
      # Unknown shell - show all options
      echo "Unable to detect your shell. Please specify one:" >&2
      echo "" >&2
      echo "For fish:" >&2
      echo "  gh account-guard install-shell-hook --fish >> ~/.config/fish/config.fish" >&2
      echo "" >&2
      echo "For zsh:" >&2
      echo "  gh account-guard install-shell-hook --zsh >> ~/.zshrc" >&2
      echo "" >&2
      echo "For bash:" >&2
      echo "  gh account-guard install-shell-hook --bash >> ~/.bashrc" >&2
      exit 1
      ;;
  esac
}
