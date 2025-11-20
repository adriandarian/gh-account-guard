#!/usr/bin/env bash
# Edit command: Interactive editor to modify existing profile configurations

cmd_edit() {
  # Check if config exists
  if [[ ! -f "$CONFIG" ]]; then
    echo "No config found at $CONFIG"
    echo "Run 'gh account-guard setup' to create a configuration first."
    exit 1
  fi
  
  # Get profile count
  local profile_count
  profile_count=$(yaml_get ".profiles | length" "$CONFIG" 2>/dev/null || echo "0")
  
  if [[ "$profile_count" -eq 0 ]]; then
    echo "No profiles found in config."
    echo "Run 'gh account-guard setup' to add profiles."
    exit 1
  fi
  
  # Build profile selection menu
  local profile_options=()
  local profile_names=()
  for ((i=0; i<profile_count; i++)); do
    local profile_name
    profile_name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
    if [[ -n "$profile_name" && "$profile_name" != "null" ]]; then
      profile_names+=("$profile_name")
      # Get some details for display
      local gh_username
      gh_username=$(yaml_get ".profiles[$i].gh_username" "$CONFIG" 2>/dev/null || echo "")
      local display_name="$profile_name"
      if [[ -n "$gh_username" && "$gh_username" != "null" ]]; then
        display_name="$profile_name ($gh_username)"
      fi
      profile_options+=("$display_name")
    fi
  done
  
  # Select profile to edit
  echo ""
  if has_gum; then
    gum style --foreground 212 --bold "✏️  Edit Profile Configuration"
    echo ""
  else
    echo "✏️  Edit Profile Configuration"
    echo ""
  fi
  
  local selected_profile
  selected_profile=$(interactive_menu "Select a profile to edit:" "" "${profile_options[@]}")
  local menu_exit=$?
  
  if [[ $menu_exit -eq 130 ]] || [[ -z "$selected_profile" ]]; then
    echo "Cancelled."
    exit 0
  fi
  
  # Extract profile name from selection (remove username if present)
  local profile_name="${selected_profile%% (*}"
  local profile_idx=-1
  
  # Find the index of the selected profile
  for ((i=0; i<profile_count; i++)); do
    local name
    name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
    if [[ "$name" == "$profile_name" ]]; then
      profile_idx=$i
      break
    fi
  done
  
  if [[ $profile_idx -eq -1 ]]; then
    echo "Error: Could not find profile index." >&2
    exit 1
  fi
  
  # Get current values for display
  local current_name
  local current_gh_username
  local current_path
  local current_git_name
  local current_git_email
  local current_signing_key
  local current_gpgsign
  local current_gpgformat
  local current_remote_match
  
  current_name=$(yaml_get ".profiles[$profile_idx].name" "$CONFIG" 2>/dev/null || echo "")
  current_gh_username=$(yaml_get ".profiles[$profile_idx].gh_username" "$CONFIG" 2>/dev/null || echo "")
  current_git_name=$(yaml_get ".profiles[$profile_idx].git.name" "$CONFIG" 2>/dev/null || echo "")
  current_git_email=$(yaml_get ".profiles[$profile_idx].git.email" "$CONFIG" 2>/dev/null || echo "")
  current_signing_key=$(yaml_get ".profiles[$profile_idx].git.signingkey" "$CONFIG" 2>/dev/null || echo "")
  current_gpgsign=$(yaml_get ".profiles[$profile_idx].git.gpgsign" "$CONFIG" 2>/dev/null || echo "false")
  current_gpgformat=$(yaml_get ".profiles[$profile_idx].git.gpgformat" "$CONFIG" 2>/dev/null || echo "ssh")
  current_remote_match=$(yaml_get ".profiles[$profile_idx].remote_match" "$CONFIG" 2>/dev/null || echo "")
  
  # Get path - handle both string and array
  local path_type
  path_type=$(yaml_get ".profiles[$profile_idx].path | type" "$CONFIG" 2>/dev/null || echo "!!str")
  if [[ "$path_type" == *"seq"* ]] || [[ "$path_type" == *"array"* ]]; then
    # Path is an array - get first one for display, or combine them
    local path_count
    path_count=$(yaml_get ".profiles[$profile_idx].path | length" "$CONFIG" 2>/dev/null || echo "0")
    if [[ $path_count -gt 0 ]]; then
      current_path=$(yaml_get ".profiles[$profile_idx].path[0]" "$CONFIG" 2>/dev/null || echo "")
      if [[ $path_count -gt 1 ]]; then
        current_path="$current_path (+ $((path_count - 1)) more)"
      fi
    fi
  else
    current_path=$(yaml_get ".profiles[$profile_idx].path" "$CONFIG" 2>/dev/null || echo "")
  fi
  
  # Build field selection menu
  local field_options=(
    "Profile name: $current_name"
    "GitHub username: ${current_gh_username:-<not set>}"
    "Path: ${current_path:-<not set>}"
    "Git name: ${current_git_name:-<not set>}"
    "Git email: ${current_git_email:-<not set>}"
    "Signing key: ${current_signing_key:-<not set>}"
    "Enable GPG signing: $current_gpgsign"
    "GPG format: $current_gpgformat"
    "Remote match: ${current_remote_match:-<not set>}"
  )
  
  # Select field to edit
  echo ""
  if has_gum; then
    gum style --foreground 212 --bold "Editing profile: $profile_name"
    echo ""
  else
    echo "Editing profile: $profile_name"
    echo ""
  fi
  
  local selected_field
  selected_field=$(interactive_menu "Select a field to edit:" "" "${field_options[@]}")
  local field_menu_exit=$?
  
  if [[ $field_menu_exit -eq 130 ]] || [[ -z "$selected_field" ]]; then
    echo "Cancelled."
    exit 0
  fi
  
  # Determine which field was selected and get new value
  local field_name=""
  local field_key=""
  local current_value=""
  local prompt_text=""
  local is_optional=false
  local is_boolean=false
  local is_choice=false
  local choice_options=()
  
  if [[ "$selected_field" =~ ^Profile\ name: ]]; then
    field_name="name"
    field_key="name"
    current_value="$current_name"
    prompt_text="Profile name"
  elif [[ "$selected_field" =~ ^GitHub\ username: ]]; then
    field_name="GitHub username"
    field_key="gh_username"
    current_value="$current_gh_username"
    prompt_text="GitHub username"
  elif [[ "$selected_field" =~ ^Path: ]]; then
    field_name="path"
    field_key="path"
    # Get actual path value(s) for editing
    if [[ "$path_type" == *"seq"* ]] || [[ "$path_type" == *"array"* ]]; then
      # For arrays, show all paths comma-separated
      local path_count
      path_count=$(yaml_get ".profiles[$profile_idx].path | length" "$CONFIG" 2>/dev/null || echo "0")
      local paths=()
      for ((i=0; i<path_count; i++)); do
        local p
        p=$(yaml_get ".profiles[$profile_idx].path[$i]" "$CONFIG" 2>/dev/null || echo "")
        if [[ -n "$p" ]]; then
          paths+=("$p")
        fi
      done
      current_value=$(IFS=','; echo "${paths[*]}")
    else
      current_value="$current_path"
    fi
    prompt_text="Repository path(s) (comma-separated for multiple)"
    is_optional=false
  elif [[ "$selected_field" =~ ^Git\ name: ]]; then
    field_name="Git name"
    field_key="git.name"
    current_value="$current_git_name"
    prompt_text="Git name"
  elif [[ "$selected_field" =~ ^Git\ email: ]]; then
    field_name="Git email"
    field_key="git.email"
    current_value="$current_git_email"
    prompt_text="Git email"
  elif [[ "$selected_field" =~ ^Signing\ key: ]]; then
    field_name="Signing key"
    field_key="git.signingkey"
    current_value="$current_signing_key"
    prompt_text="Signing key (SSH key or GPG key ID)"
    is_optional=true
  elif [[ "$selected_field" =~ ^Enable\ GPG\ signing: ]]; then
    field_name="Enable GPG signing"
    field_key="git.gpgsign"
    current_value="$current_gpgsign"
    prompt_text="Enable commit signing"
    is_boolean=true
  elif [[ "$selected_field" =~ ^GPG\ format: ]]; then
    field_name="GPG format"
    field_key="git.gpgformat"
    current_value="$current_gpgformat"
    prompt_text="GPG format"
    is_choice=true
    choice_options=("ssh" "gpg")
  elif [[ "$selected_field" =~ ^Remote\ match: ]]; then
    field_name="Remote match"
    field_key="remote_match"
    current_value="$current_remote_match"
    prompt_text="Remote URL pattern (leave empty to skip)"
    is_optional=true
  fi
  
  # Get new value
  echo ""
  local new_value=""
  
  if [[ "$is_boolean" == true ]]; then
    if prompt_yesno "$prompt_text?" "$current_value"; then
      new_value="true"
    else
      new_value="false"
    fi
  elif [[ "$is_choice" == true ]]; then
    local choice_menu_options=()
    for opt in "${choice_options[@]}"; do
      if [[ "$opt" == "$current_value" ]]; then
        choice_menu_options+=("$opt (current)")
      else
        choice_menu_options+=("$opt")
      fi
    done
    new_value=$(interactive_menu "Select $prompt_text:" "" "${choice_menu_options[@]}")
    local choice_exit=$?
    if [[ $choice_exit -eq 130 ]] || [[ -z "$new_value" ]]; then
      echo "Cancelled."
      exit 0
    fi
    # Remove "(current)" suffix if present
    new_value="${new_value% (current)}"
  elif [[ "$field_key" == "path" ]]; then
    # For path editing, use regular prompt but allow directory browser option
    echo ""
    echo "Current path: $current_value"
    echo "You can:"
    echo "  1. Type a new path directly"
    echo "  2. Press Enter to use directory browser"
    echo ""
    local path_input
    path_input=$(prompt_optional "$prompt_text" "$current_value")
    
    if [[ -z "$path_input" ]]; then
      # User wants to use directory browser
      path_input=$(prompt_paths "$prompt_text")
      local paths_exit=$?
      if [[ $paths_exit -eq 130 ]]; then
        echo "Cancelled."
        exit 0
      fi
      # Filter out status messages
      path_input=$(echo "$path_input" | grep -v "^✅ Selected:" | grep -v "^Debug log:" | tail -1)
      if [[ -z "$path_input" ]]; then
        echo "Error: No path was selected." >&2
        exit 1
      fi
      # If multiple paths comma-separated, take the first one for now
      # TODO: Support multiple paths in edit
      if [[ "$path_input" == *,* ]]; then
        path_input=$(echo "$path_input" | cut -d',' -f1 | xargs)
      fi
    fi
    new_value="$path_input"
  else
    if [[ "$is_optional" == true ]]; then
      new_value=$(prompt_optional "$prompt_text" "$current_value")
    else
      new_value=$(prompt "$prompt_text" "$current_value")
    fi
  fi
  
  # Validate new value
  if [[ -z "$new_value" && "$is_optional" != true && "$field_key" != "remote_match" ]]; then
    echo "Error: Value cannot be empty." >&2
    exit 1
  fi
  
  # Update the config
  echo ""
  if has_gum; then
    gum spin --spinner dot --title "Updating configuration..." -- sleep 0.3 2>/dev/null || true
  fi
  
  if yaml_update_profile_field "$CONFIG" "$profile_idx" "$field_key" "$new_value"; then
    if has_gum; then
      gum style --foreground 10 "✅ Updated $field_name successfully!"
    else
      echo "✅ Updated $field_name successfully!"
    fi
    echo ""
    echo "Updated: $field_name = $new_value"
  else
    echo "Error: Failed to update configuration." >&2
    exit 1
  fi
}

