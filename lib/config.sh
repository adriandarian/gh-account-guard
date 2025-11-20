#!/usr/bin/env bash
# Config and profile management functions for gh-account-guard

# Determine script directory for sourcing modules
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Source YAML parsing module
# shellcheck source=lib/helpers/yaml.sh
source "${SCRIPT_DIR}/helpers/yaml.sh"

# Source profile matching module
# shellcheck source=lib/helpers/profile.sh
source "${SCRIPT_DIR}/helpers/profile.sh"

# Get default directory for file browser (from config or HOME)
get_default_directory() {
  local default_dir
  if [[ -f "$CONFIG" ]]; then
    default_dir=$(yaml_get '.default_directory' "$CONFIG" 2>/dev/null || echo "")
    if [[ -n "$default_dir" && "$default_dir" != "null" ]]; then
      # Expand ~
      default_dir=${default_dir/#\~/$HOME}
      if [[ -d "$default_dir" ]]; then
        echo "$default_dir"
        return 0
      fi
    fi
  fi
  # Default to HOME
  echo "$HOME"
}

# Set default directory in config
set_default_directory() {
  local default_dir="$1"
  
  # If config doesn't exist, create it
  if [[ ! -f "$CONFIG" ]]; then
    mkdir -p "$(dirname "$CONFIG")"
    echo "# Map local paths (prefix-glob) to profiles." > "$CONFIG"
    echo "# Longest matching path wins." >> "$CONFIG"
    echo "# Path can be a string (single path) or array (multiple paths)." >> "$CONFIG"
    echo "default_directory: \"$default_dir\"" >> "$CONFIG"
    echo "profiles: []" >> "$CONFIG"
    return 0
  fi
  
  # Read file into array
  local lines=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done < "$CONFIG"
  
  # Write to temp file
  local temp_file
  temp_file=$(mktemp)
  local found=false
  
  for line in "${lines[@]}"; do
    if [[ "$line" =~ ^default_directory: ]]; then
      echo "default_directory: \"$default_dir\"" >> "$temp_file"
      found=true
    else
      echo "$line" >> "$temp_file"
    fi
  done
  
  # If not found, add it at the top (after comments)
  if [[ "$found" == false ]]; then
    local temp_file2
    temp_file2=$(mktemp)
    local added=false
    for line in "${lines[@]}"; do
      if [[ "$added" == false ]] && [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "${line// }" ]]; then
        echo "default_directory: \"$default_dir\"" >> "$temp_file2"
        added=true
      fi
      echo "$line" >> "$temp_file2"
    done
    mv "$temp_file2" "$temp_file"
  fi
  
  mv "$temp_file" "$CONFIG"
}

# match_profile() is now in lib/profile.sh (sourced above)

add_profile_to_config() {
  local profile_name="$1"
  local profile_path="$2"  # Can be "__MULTIPLE__" or a single path
  local gh_username="$3"
  local git_name="$4"
  local git_email="$5"
  local signing_key="$6"
  local gpgsign="$7"
  local gpgformat="$8"
  local remote_match="$9"
  shift 9
  local profile_paths_array=("$@")  # Array of paths if multiple

  # If config doesn't exist, create it with empty profiles array
  if [[ ! -f "$CONFIG" ]]; then
    mkdir -p "$(dirname "$CONFIG")"
    echo "# Map local paths (prefix-glob) to profiles." > "$CONFIG"
    echo "# Longest matching path wins." >> "$CONFIG"
    echo "# Path can be a string (single path) or array (multiple paths)." >> "$CONFIG"
    echo "profiles:" >> "$CONFIG"
  fi

  # Read existing config
  local lines=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done < "$CONFIG"

  # Write to temp file
  local temp_file
  temp_file=$(mktemp)
  
  # Copy existing content including profiles section
  local in_profiles=false
  for line in "${lines[@]}"; do
    if [[ "$line" =~ ^profiles:[[:space:]]*$ ]]; then
      echo "$line" >> "$temp_file"
      in_profiles=true
    else
      echo "$line" >> "$temp_file"
    fi
  done
  
  # If profiles: line doesn't exist, add it
  if [[ "$in_profiles" == false ]]; then
    echo "profiles:" >> "$temp_file"
  fi
  
  # Append new profile
  echo "  - name: \"$profile_name\"" >> "$temp_file"
  echo "    gh_username: \"$gh_username\"" >> "$temp_file"
  
  # Handle paths - single or multiple
  if [[ "$profile_path" == "__MULTIPLE__" && ${#profile_paths_array[@]} -gt 0 ]]; then
    # Multiple paths - store as YAML array
    echo "    path:" >> "$temp_file"
    for path in "${profile_paths_array[@]}"; do
      echo "      - \"$path\"" >> "$temp_file"
    done
  else
    # Single path
    echo "    path: \"$profile_path\"" >> "$temp_file"
  fi
  
  # Git config
  echo "    git:" >> "$temp_file"
  echo "      name: \"$git_name\"" >> "$temp_file"
  echo "      email: \"$git_email\"" >> "$temp_file"
  echo "      signingkey: \"$signing_key\"" >> "$temp_file"
  echo "      gpgsign: $gpgsign" >> "$temp_file"
  echo "      gpgformat: \"$gpgformat\"" >> "$temp_file"
  
  # Remote match (optional)
  if [[ -n "$remote_match" ]]; then
    echo "    remote_match: \"$remote_match\"" >> "$temp_file"
  fi

  mv "$temp_file" "$CONFIG"
}

collect_profile_info() {
  local profile_num="$1"
  local default_name="$2"
  
  echo ""
  if has_gum; then
    gum style --foreground 212 --bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    gum style --foreground 212 --bold "📋 Profile $profile_num"
    gum style --foreground 212 --bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Profile $profile_num"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi
  
  local profile_name
  profile_name=$(prompt "Profile name (e.g., work, personal, client1)" "$default_name")
  
  echo ""
  echo "Enter paths for this profile. You can specify:"
  echo "  - Parent folders (e.g., ~/work/company/) - matches all repos inside"
  echo "  - Individual repos (e.g., ~/work/company/specific-repo)"
  echo ""
  echo "💡 To add multiple paths, separate them with commas:"
  echo "   Example: ~/work/company/,~/work/client/,~/personal/project"
  echo ""
  local profile_paths_input
  # Capture stdout (the actual path value), stderr displays normally for user feedback
  # The "✅ Selected:" message goes to stderr and will display in real-time
  profile_paths_input=$(prompt_paths "Repos paths (comma-separated for multiple)")
  local paths_exit=$?
  
  # Handle Esc cancellation
  if [[ $paths_exit -eq 130 ]]; then
    echo "Cancelled."
    exit 0
  fi
  
  # Filter out any status messages that might have been captured
  profile_paths_input=$(echo "$profile_paths_input" | grep -v "^✅ Selected:" | grep -v "^Debug log:" | tail -1)
  
  # Validate we got a path
  if [[ -z "$profile_paths_input" ]]; then
    echo "Error: No path was selected." >&2
    exit 1
  fi
  
  # Convert comma-separated paths to array
  local profile_paths=()
  IFS=',' read -ra ADDR <<< "$profile_paths_input"
  for path in "${ADDR[@]}"; do
    # Trim whitespace
    path=$(echo "$path" | xargs)
    if [[ -n "$path" ]]; then
      profile_paths+=("$path")
    fi
  done
  
  # If only one path, use it as string for backward compatibility
  # If multiple paths, we'll store as array
  local profile_path
  if [[ ${#profile_paths[@]} -eq 1 ]]; then
    profile_path="${profile_paths[0]}"
  elif [[ ${#profile_paths[@]} -gt 1 ]]; then
    # Multiple paths - will be stored as YAML array
    profile_path="__MULTIPLE__"
  else
    echo "Error: At least one path is required." >&2
    exit 1
  fi
  
  # Get list of logged-in GitHub accounts
  local gh_accounts=()
  local current_account=""
  while IFS= read -r line; do
    if [[ "$line" =~ Logged[[:space:]]in[[:space:]]to[[:space:]]github\.com[[:space:]]account[[:space:]]([^[:space:]]+) ]]; then
      gh_accounts+=("${BASH_REMATCH[1]}")
    fi
    if [[ "$line" =~ Active[[:space:]]account:[[:space:]]true ]]; then
      # Get the account from the previous line
      if [[ "${#gh_accounts[@]}" -gt 0 ]]; then
        current_account="${gh_accounts[-1]}"
      fi
    fi
  done < <(gh auth status 2>&1)
  
  local gh_username=""
  local git_name=""
  local git_email=""
  
  if [[ ${#gh_accounts[@]} -gt 0 ]]; then
    # Show account selection menu
    echo ""
    if has_gum; then
      gum style "Select GitHub account for this profile:"
    else
      echo "Select GitHub account for this profile:"
    fi
    
    local account_options=()
    for account in "${gh_accounts[@]}"; do
      local display="$account"
      if [[ "$account" == "$current_account" ]]; then
        display="$account (current)"
      fi
      account_options+=("$display")
    done
    
    local selected_account
    selected_account=$(interactive_menu "Choose GitHub account" "" "${account_options[@]}")
    local menu_exit=$?
    
    if [[ $menu_exit -eq 130 ]] || [[ -z "$selected_account" ]]; then
      echo "Cancelled."
      exit 0
    fi
    
    # Extract username from selection (remove "(current)" if present)
    gh_username=$(echo "$selected_account" | sed 's/ (current)$//')
    
    # Fetch GitHub profile info for the selected account
    echo ""
    local original_account="$current_account"
    
    if has_gum; then
      gum spin --spinner dot --title "Fetching GitHub profile info..." -- \
        bash -c "gh auth switch -u '$gh_username' >/dev/null 2>&1" || true
    else
      echo "Fetching GitHub profile info..."
      gh auth switch -u "$gh_username" >/dev/null 2>&1 || true
    fi
    
    # Get user info from GitHub API
    # Note: email might be null if user has it private
    git_name=$(gh api user --jq '.name // ""' 2>/dev/null || echo "")
    git_email=$(gh api user --jq '.email // ""' 2>/dev/null || echo "")
    
    # If email is null or empty, try to get it from the user's public email list
    if [[ -z "$git_email" ]]; then
      git_email=$(gh api user/emails --jq '.[0].email // ""' 2>/dev/null || echo "")
    fi
    
    # Switch back to original account if it was different
    if [[ -n "$original_account" && "$original_account" != "$gh_username" ]]; then
      gh auth switch -u "$original_account" >/dev/null 2>&1 || true
    fi
    
    # Use defaults if we got info from GitHub
    if [[ -z "$git_name" ]]; then
      git_name="$gh_username"
    fi
    
    # Show what we found
    if [[ -n "$git_name" ]] || [[ -n "$git_email" ]]; then
      echo ""
      if has_gum; then
        gum style --foreground 10 "✓ Found GitHub profile info:"
        [[ -n "$git_name" ]] && gum style "   Name: $git_name"
        [[ -n "$git_email" ]] && gum style "   Email: $git_email"
      else
        echo "✓ Found GitHub profile info:"
        [[ -n "$git_name" ]] && echo "   Name: $git_name"
        [[ -n "$git_email" ]] && echo "   Email: $git_email"
      fi
    fi
  else
    # No accounts logged in, prompt manually
    echo ""
    if has_gum; then
      gum style --foreground 11 "⚠️  No GitHub accounts found. Please log in first:"
      gum style "   gh auth login"
    else
      echo "⚠️  No GitHub accounts found. Please log in first:"
      echo "   gh auth login"
    fi
    gh_username=$(prompt "GitHub username for this profile" "")
  git_name=$(prompt "Git name" "$gh_username")
    git_email=$(prompt "Git email" "")
  fi
  
  # Allow user to override the auto-detected values
  echo ""
  git_name=$(prompt "Git name" "$git_name")
  git_email=$(prompt "Git email" "$git_email")
  
  echo ""
  echo "Remote URL pattern helps validate repos match the expected account/organization."
  echo "Examples:"
  echo "  - For GitHub Enterprise: 'github.enterprise.com' (matches entire enterprise)"
  echo "  - For specific org: 'github.com/YourOrg/'"
  echo "  - Leave empty to skip remote validation"
  local remote_match
  remote_match=$(prompt_optional "Remote URL pattern" "")
  
  local signing_key=""
  local gpgsign="false"
  local gpgformat="ssh"
  if prompt_yesno "Enable commit signing for this profile?" "n"; then
    signing_key=$(prompt_optional "Signing key (SSH key or GPG key ID)" "")
    if prompt_yesno "Use GPG format instead of SSH?" "n"; then
      gpgformat="gpg"
    fi
    gpgsign="true"
  fi

  # Pass paths array if multiple, otherwise single path
  if [[ "$profile_path" == "__MULTIPLE__" ]]; then
    add_profile_to_config "$profile_name" "$profile_path" "$gh_username" "$git_name" "$git_email" "$signing_key" "$gpgsign" "$gpgformat" "$remote_match" "${profile_paths[@]}"
  else
    add_profile_to_config "$profile_name" "$profile_path" "$gh_username" "$git_name" "$git_email" "$signing_key" "$gpgsign" "$gpgformat" "$remote_match"
  fi
  
  echo "$profile_name"
}
