#!/usr/bin/env bash
# Path command: Add or remove paths from profiles

cmd_path() {
  local subcmd="${1:-}"
  
  case "$subcmd" in
    add)
      shift
      cmd_path_add "$@"
      ;;
    remove|rm)
      shift
      cmd_path_remove "$@"
      ;;
    "")
      print_path_usage
      exit 1
      ;;
    *)
      echo "Unknown subcommand: $subcmd" >&2
      echo ""
      print_path_usage
      exit 1
      ;;
  esac
}

print_path_usage() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "${BOLD}📁 Path Management${RESET}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Usage:"
  echo "  gh account-guard path add [path] [--profile <name>] [--yes]"
  echo "  gh account-guard path remove [path] [--profile <name>] [--yes]"
  echo ""
  echo "Options:"
  echo "  --profile <name>   Specify profile name (skips interactive selection)"
  echo "  --yes, -y          Skip confirmation prompts"
  echo ""
  echo "Examples:"
  echo "  gh ag path add                          # Add current directory"
  echo "  gh ag path add ~/projects/myrepo        # Add specific path"
  echo "  gh ag path add . --profile personal     # Add to specific profile"
  echo "  gh ag path add . -p work --yes          # Add without confirmation"
  echo "  gh ag path remove                       # Interactive removal"
  echo "  gh ag path rm ~/old/path                # Remove specific path"
}

cmd_path_add() {
  local path_to_add=""
  local target_profile=""
  local skip_confirm=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile|-p)
        target_profile="$2"
        shift 2
        ;;
      --yes|-y)
        skip_confirm=true
        shift
        ;;
      *)
        if [[ -z "$path_to_add" ]]; then
          path_to_add="$1"
        fi
        shift
        ;;
    esac
  done
  
  # Default to current directory
  [[ -z "$path_to_add" ]] && path_to_add="$PWD"
  
  # Expand ~ and resolve to absolute path
  path_to_add=${path_to_add/#\~/$HOME}
  if [[ ! "$path_to_add" = /* ]]; then
    path_to_add="$PWD/$path_to_add"
  fi
  # Normalize path (remove trailing slash, resolve ..)
  path_to_add=$(cd "$path_to_add" 2>/dev/null && pwd) || {
    echo "${YELLOW}⚠️  Directory does not exist: $path_to_add${RESET}" >&2
    exit 1
  }
  # Ensure trailing slash for consistency
  [[ "$path_to_add" != */ ]] && path_to_add="${path_to_add}/"
  
  # Check if config exists
  if [[ ! -f "$CONFIG" ]]; then
    echo "${YELLOW}⚠️  No configuration found at $CONFIG${RESET}"
    echo ""
    echo "Run 'gh account-guard setup' to create a configuration first."
    exit 1
  fi
  
  # Header
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "${BOLD}➕ Add Path to Profile${RESET}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "${CYAN}📁 Path to add:${RESET} $path_to_add"
  echo ""
  
  # Check if path already belongs to a profile
  local existing_profile_idx
  existing_profile_idx=$(match_profile "$path_to_add") || true
  if [[ -n "$existing_profile_idx" ]]; then
    local existing_name
    existing_name=$(yaml_get ".profiles[$existing_profile_idx].name" "$CONFIG")
    echo "${YELLOW}⚠️  This path is already covered by profile: ${BOLD}$existing_name${RESET}"
    echo ""
    if [[ "$skip_confirm" != true ]]; then
      if ! prompt_yesno "Add it anyway?"; then
        echo "Cancelled."
        exit 0
      fi
      echo ""
    fi
  fi
  
  # Get profiles for selection
  local profile_count
  profile_count=$(yaml_get '.profiles | length' "$CONFIG" 2>/dev/null || echo "0")
  
  if [[ "$profile_count" -eq 0 ]]; then
    echo "${YELLOW}⚠️  No profiles found.${RESET}"
    echo "Run 'gh account-guard setup' to create profiles."
    exit 1
  fi
  
  local profile_name=""
  local profile_idx=-1
  
  # If profile specified via flag, find it
  if [[ -n "$target_profile" ]]; then
    for ((i=0; i<profile_count; i++)); do
      local name
      name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
      if [[ "$name" == "$target_profile" ]]; then
        profile_idx=$i
        profile_name="$name"
        break
      fi
    done
    
    if [[ $profile_idx -eq -1 ]]; then
      echo "${YELLOW}⚠️  Profile not found: $target_profile${RESET}" >&2
      echo ""
      echo "Available profiles:"
      for ((i=0; i<profile_count; i++)); do
        local name
        name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
        echo "  - $name"
      done
      exit 1
    fi
    
    echo "${CYAN}📋 Target profile:${RESET} $profile_name"
    echo ""
  else
    # Interactive profile selection
    local profile_options=()
    for ((i=0; i<profile_count; i++)); do
      local pname
      local gh_username
      pname=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
      gh_username=$(yaml_get ".profiles[$i].gh_username" "$CONFIG" 2>/dev/null || echo "")
      if [[ -n "$gh_username" && "$gh_username" != "null" ]]; then
        profile_options+=("$pname ($gh_username)")
      else
        profile_options+=("$pname")
      fi
    done
    
    local selected_profile
    selected_profile=$(interactive_menu "Select profile to add path to:" "" "${profile_options[@]}")
    local menu_exit=$?
    
    if [[ $menu_exit -eq 130 ]] || [[ -z "$selected_profile" ]]; then
      echo "Cancelled."
      exit 0
    fi
    
    # Extract profile name
    profile_name="${selected_profile%% (*}"
    
    for ((i=0; i<profile_count; i++)); do
      local name
      name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
      if [[ "$name" == "$profile_name" ]]; then
        profile_idx=$i
        break
      fi
    done
  fi
  
  if [[ $profile_idx -eq -1 ]]; then
    echo "${YELLOW}⚠️  Could not find profile.${RESET}" >&2
    exit 1
  fi
  
  # Add path to profile
  yaml_add_path_to_profile "$CONFIG" "$profile_idx" "$path_to_add"
  
  echo ""
  echo "${GREEN}✓${RESET} Added ${BOLD}$path_to_add${RESET} to profile ${BOLD}$profile_name${RESET}"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

cmd_path_remove() {
  local path_to_remove=""
  local target_profile=""
  local skip_confirm=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile|-p)
        target_profile="$2"
        shift 2
        ;;
      --yes|-y)
        skip_confirm=true
        shift
        ;;
      *)
        if [[ -z "$path_to_remove" ]]; then
          path_to_remove="$1"
        fi
        shift
        ;;
    esac
  done
  
  # Check if config exists
  if [[ ! -f "$CONFIG" ]]; then
    echo "${YELLOW}⚠️  No configuration found at $CONFIG${RESET}"
    echo ""
    echo "Run 'gh account-guard setup' to create a configuration first."
    exit 1
  fi
  
  # Header
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "${BOLD}➖ Remove Path from Profile${RESET}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Get profiles
  local profile_count
  profile_count=$(yaml_get '.profiles | length' "$CONFIG" 2>/dev/null || echo "0")
  
  if [[ "$profile_count" -eq 0 ]]; then
    echo "${YELLOW}⚠️  No profiles found.${RESET}"
    exit 1
  fi
  
  # If path provided, find which profile it belongs to
  if [[ -n "$path_to_remove" ]]; then
    # Normalize path
    path_to_remove=${path_to_remove/#\~/$HOME}
    if [[ ! "$path_to_remove" = /* ]]; then
      path_to_remove="$PWD/$path_to_remove"
    fi
    [[ "$path_to_remove" != */ ]] && path_to_remove="${path_to_remove}/"
    
    echo "${CYAN}📁 Path to remove:${RESET} $path_to_remove"
    echo ""
    
    # Find profile containing this path
    local found_profile_idx=-1

    for ((i=0; i<profile_count; i++)); do
      local path_type
      path_type=$(yaml_get ".profiles[$i].path | type" "$CONFIG" 2>/dev/null || echo "!!str")
      
      if [[ "$path_type" == *"seq"* ]] || [[ "$path_type" == *"array"* ]]; then
        local path_count
        path_count=$(yaml_get ".profiles[$i].path | length" "$CONFIG" 2>/dev/null || echo "0")
        for ((j=0; j<path_count; j++)); do
          local path_val
          path_val=$(yaml_get ".profiles[$i].path[$j]" "$CONFIG" 2>/dev/null || echo "")
          # Normalize for comparison
          [[ "$path_val" != */ ]] && path_val="${path_val}/"
          if [[ "$path_val" == "$path_to_remove" ]]; then
            found_profile_idx=$i
            break 2
          fi
        done
      else
        local path_val
        path_val=$(yaml_get ".profiles[$i].path" "$CONFIG" 2>/dev/null || echo "")
        [[ "$path_val" != */ ]] && path_val="${path_val}/"
        if [[ "$path_val" == "$path_to_remove" ]]; then
          found_profile_idx=$i
          break
        fi
      fi
    done
    
    if [[ $found_profile_idx -eq -1 ]]; then
      echo "${YELLOW}⚠️  Path not found in any profile.${RESET}"
      exit 1
    fi
    
    local profile_name
    profile_name=$(yaml_get ".profiles[$found_profile_idx].name" "$CONFIG")
    
    echo "Found in profile: ${BOLD}$profile_name${RESET}"
    echo ""
    
    if [[ "$skip_confirm" != true ]]; then
      if ! prompt_yesno "Remove this path from the profile?"; then
        echo "Cancelled."
        exit 0
      fi
    fi
    
    yaml_remove_path_from_profile "$CONFIG" "$found_profile_idx" "$path_to_remove"
    
    echo ""
    echo "${GREEN}✓${RESET} Removed ${BOLD}$path_to_remove${RESET} from profile ${BOLD}$profile_name${RESET}"
  else
    # Interactive mode - select profile first, then path
    local profile_options=()
    for ((i=0; i<profile_count; i++)); do
      local profile_name
      local gh_username
      profile_name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
      gh_username=$(yaml_get ".profiles[$i].gh_username" "$CONFIG" 2>/dev/null || echo "")
      if [[ -n "$gh_username" && "$gh_username" != "null" ]]; then
        profile_options+=("$profile_name ($gh_username)")
      else
        profile_options+=("$profile_name")
      fi
    done
    
    local selected_profile
    selected_profile=$(interactive_menu "Select profile to remove path from:" "" "${profile_options[@]}")
    local menu_exit=$?
    
    if [[ $menu_exit -eq 130 ]] || [[ -z "$selected_profile" ]]; then
      echo "Cancelled."
      exit 0
    fi
    
    local profile_name="${selected_profile%% (*}"
    local profile_idx=-1
    
    for ((i=0; i<profile_count; i++)); do
      local name
      name=$(yaml_get ".profiles[$i].name" "$CONFIG" 2>/dev/null || echo "")
      if [[ "$name" == "$profile_name" ]]; then
        profile_idx=$i
        break
      fi
    done
    
    if [[ $profile_idx -eq -1 ]]; then
      echo "${YELLOW}⚠️  Could not find profile.${RESET}" >&2
      exit 1
    fi
    
    # Get paths for this profile
    local path_options=()
    local path_type
    path_type=$(yaml_get ".profiles[$profile_idx].path | type" "$CONFIG" 2>/dev/null || echo "!!str")
    
    if [[ "$path_type" == *"seq"* ]] || [[ "$path_type" == *"array"* ]]; then
      local path_count
      path_count=$(yaml_get ".profiles[$profile_idx].path | length" "$CONFIG" 2>/dev/null || echo "0")
      for ((j=0; j<path_count; j++)); do
        local path_val
        path_val=$(yaml_get ".profiles[$profile_idx].path[$j]" "$CONFIG" 2>/dev/null || echo "")
        if [[ -n "$path_val" ]]; then
          path_options+=("$path_val")
        fi
      done
    else
      local path_val
      path_val=$(yaml_get ".profiles[$profile_idx].path" "$CONFIG" 2>/dev/null || echo "")
      if [[ -n "$path_val" && "$path_val" != "null" ]]; then
        path_options+=("$path_val")
      fi
    fi
    
    if [[ ${#path_options[@]} -eq 0 ]]; then
      echo "${YELLOW}⚠️  No paths configured for this profile.${RESET}"
      exit 1
    fi
    
    if [[ ${#path_options[@]} -eq 1 ]] && [[ "$skip_confirm" != true ]]; then
      echo "${YELLOW}⚠️  This profile only has one path. Removing it would leave the profile without any paths.${RESET}"
      echo ""
      if ! prompt_yesno "Remove the only path anyway?"; then
        echo "Cancelled."
        exit 0
      fi
    fi
    
    echo ""
    local selected_path
    selected_path=$(interactive_menu "Select path to remove:" "" "${path_options[@]}")
    menu_exit=$?
    
    if [[ $menu_exit -eq 130 ]] || [[ -z "$selected_path" ]]; then
      echo "Cancelled."
      exit 0
    fi
    
    if [[ "$skip_confirm" != true ]]; then
      echo ""
      if ! prompt_yesno "Remove '$selected_path' from profile '$profile_name'?"; then
        echo "Cancelled."
        exit 0
      fi
    fi
    
    yaml_remove_path_from_profile "$CONFIG" "$profile_idx" "$selected_path"
    
    echo ""
    echo "${GREEN}✓${RESET} Removed ${BOLD}$selected_path${RESET} from profile ${BOLD}$profile_name${RESET}"
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
