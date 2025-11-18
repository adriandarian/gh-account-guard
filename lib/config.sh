#!/usr/bin/env bash
# Config and profile management functions for gh-account-guard

# Pure bash YAML parser - handles our specific structure
# Query syntax: .key, .key[0], .key[0].subkey, etc.
yaml_get() {
  local query="$1"
  local file="$2"
  
  [[ -f "$file" ]] || return 1
  
  # Remove leading dot
  query="${query#.}"
  
  # Handle profile path length queries FIRST (before general field queries)
  # This must come before the general profiles[0] pattern
  if [[ "$query" =~ ^profiles\[([0-9]+)\]\.path[[:space:]]*\|[[:space:]]*length$ ]]; then
    local idx="${BASH_REMATCH[1]}"
    _yaml_get_path_length "$file" "$idx"
    return $?
  fi
  
  # Handle profile field type queries like profiles[0].path | type
  if [[ "$query" =~ ^profiles\[([0-9]+)\]\.path[[:space:]]*\|[[:space:]]*type$ ]]; then
    local idx="${BASH_REMATCH[1]}"
    _yaml_get_path_type "$file" "$idx"
    return $?
  fi
  
  # Handle array length queries like profiles | length
  if [[ "$query" =~ ^([^|]+)[[:space:]]*\|[[:space:]]*length$ ]]; then
    local key="${BASH_REMATCH[1]}"
    key=$(echo "$key" | xargs)  # trim whitespace
    if [[ "$key" == "profiles" ]]; then
      _yaml_count_profiles "$file"
      return $?
    fi
  fi
  
  # Handle array select queries like profiles[] | select(.name == "x") | .gh_username
  if [[ "$query" =~ ^profiles\[\]\s*\|\s*select\(\.name\s*==\s*\"([^\"]+)\"\)\s*\|\s*\.(.+)$ ]]; then
    local name="${BASH_REMATCH[1]}"
    local field="${BASH_REMATCH[2]}"
    _yaml_find_profile_by_name "$file" "$name" "$field"
    return $?
  fi
  
  # Handle array index queries like profiles[0]
  if [[ "$query" =~ ^([^[]+)\[([0-9]+)\]\.?(.*)$ ]]; then
    local key="${BASH_REMATCH[1]}"
    local idx="${BASH_REMATCH[2]}"
    local rest="${BASH_REMATCH[3]}"
    
    if [[ "$key" == "profiles" ]]; then
      _yaml_get_profile_field "$file" "$idx" "$rest"
      return $?
    fi
  fi
  
  # Handle simple key queries like default_directory
  if [[ "$query" == "default_directory" ]]; then
    _yaml_get_simple_value "$file" "default_directory"
    return $?
  fi
  
  return 1
}

# Get a simple top-level value
_yaml_get_simple_value() {
  local file="$1"
  local key="$2"
  grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}:\s*//" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/"
}

# Count profiles in the config
_yaml_count_profiles() {
  local file="$1"
  local count=0
  local in_profiles=false
  local profile_indent=-1
  
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    if [[ "$line" =~ ^profiles:[[:space:]]*$ ]]; then
      in_profiles=true
      continue
    fi
    
    if [[ "$in_profiles" == true ]]; then
      # Check if we've left the profiles section (top-level key)
      if [[ "$line" =~ ^[^[:space:]] ]] && [[ ! "$line" =~ ^[[:space:]]*- ]]; then
        break
      fi
      
      # Count only profile entries (lines starting with - at profile level, indent 2)
      # Profile entries are at indent 2 (2 spaces), path array items are deeper
      if [[ "$line" =~ ^[[:space:]]{2}- ]]; then
        ((count++))
        # Track the indent level of profile entries
        profile_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
        ((profile_indent--))
      fi
    fi
  done < "$file"
  
  echo "$count"
}

# Get a field from a profile by index
_yaml_get_profile_field() {
  local file="$1"
  local idx="$2"
  local field="$3"
  
  # Read file into array
  local lines=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done < "$file"
  
  local current_idx=-1
  local in_profile=false
  local indent_level=0
  local result=""
  local i=0
  
  while [[ $i -lt ${#lines[@]} ]]; do
    local line="${lines[$i]}"
    
    # Skip comments
    [[ "$line" =~ ^[[:space:]]*# ]] && { ((i++)); continue; }
    
    # Check if we're entering profiles section
    if [[ "$line" =~ ^profiles:[[:space:]]*$ ]]; then
      ((i++))
      continue
    fi
    
    # Check if we're starting a new profile
    if [[ "$line" =~ ^[[:space:]]*- ]]; then
      ((current_idx++))
      if [[ $current_idx -eq $idx ]]; then
        in_profile=true
        indent_level=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
        ((indent_level--))
        # Check if name field is on the same line as - (e.g., "- name: value")
        if [[ "$field" == "name" ]] && [[ "$line" =~ name:[[:space:]]*(.+)$ ]]; then
          result="${BASH_REMATCH[1]}"
          result=$(echo "$result" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
          echo "$result"
          return 0
        fi
      else
        in_profile=false
      fi
      ((i++))
      continue
    fi
    
    if [[ "$in_profile" == true ]]; then
      # Check if we've left this profile (less indentation)
      local line_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
      ((line_indent--))
      if [[ $line_indent -le $indent_level ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
        break
      fi
      
      # Skip over path arrays when looking for other fields (like git.name)
      # Path arrays start with "path:" followed by array items
      if [[ ! "$field" =~ ^path ]] && [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*$ ]]; then
        # Skip the entire path array
        local path_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
        ((i++))
        while [[ $i -lt ${#lines[@]} ]]; do
          local path_line="${lines[$i]}"
          local path_line_indent=$(echo "$path_line" | sed 's/[^ ].*//' | wc -c)
          ((path_line_indent--))
          if [[ $path_line_indent -le $path_indent ]] && [[ ! "$path_line" =~ ^[[:space:]]*$ ]]; then
            # Reached end of path array, process this line in next iteration
            ((i--))
            break
          fi
          ((i++))
        done
        ((i++))
        continue
      fi
      
      # Profile-level fields should be at indent_level+2 (4 spaces for standard YAML)
      # Nested fields like git.name are at indent_level+4 (6 spaces)
      # Only match profile-level fields if they're at the right indentation
      local profile_field_indent=$((indent_level + 2))
      
      # Extract field value
      if [[ "$field" == "name" ]] && [[ "$line" =~ ^[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
        # Only match if at profile level (not nested in git:)
        # Profile fields are at indent_level+2, git fields are deeper
        if [[ $line_indent -le $profile_field_indent ]] && [[ $line_indent -gt $indent_level ]]; then
          result="${BASH_REMATCH[1]}"
          result=$(echo "$result" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
          echo "$result"
          return 0
        fi
      elif [[ "$field" == "gh_username" ]] && [[ "$line" =~ ^[[:space:]]*gh_username:[[:space:]]*(.+)$ ]]; then
        if [[ $line_indent -le $profile_field_indent ]]; then
          result="${BASH_REMATCH[1]}"
          result=$(echo "$result" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
          echo "$result"
          return 0
        fi
      elif [[ "$field" == "path" ]] && [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.+)$ ]]; then
        if [[ $line_indent -le $profile_field_indent ]]; then
          result="${BASH_REMATCH[1]}"
          result=$(echo "$result" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
          echo "$result"
          return 0
        fi
      elif [[ "$field" == "remote_match" ]] && [[ "$line" =~ ^[[:space:]]*remote_match:[[:space:]]*(.+)$ ]]; then
        if [[ $line_indent -le $profile_field_indent ]]; then
          result="${BASH_REMATCH[1]}"
          result=$(echo "$result" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
          echo "$result"
          return 0
        fi
      elif [[ "$field" =~ ^git\.(.+)$ ]]; then
        local git_field="${BASH_REMATCH[1]}"
        if [[ "$line" =~ ^[[:space:]]*git:[[:space:]]*$ ]]; then
          # Entering git section, read next indented lines
          local git_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
          ((i++))
          while [[ $i -lt ${#lines[@]} ]]; do
            local git_line="${lines[$i]}"
            local git_line_indent=$(echo "$git_line" | sed 's/[^ ].*//' | wc -c)
            ((git_line_indent--))
            if [[ $git_line_indent -le $git_indent ]] && [[ ! "$git_line" =~ ^[[:space:]]*$ ]]; then
              break
            fi
            if [[ "$git_line" =~ ^[[:space:]]*${git_field}:[[:space:]]*(.+)$ ]]; then
              result="${BASH_REMATCH[1]}"
              result=$(echo "$result" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
              echo "$result"
              return 0
            fi
            ((i++))
          done
        fi
      elif [[ "$field" =~ ^path\[([0-9]+)\]$ ]]; then
        local path_idx="${BASH_REMATCH[1]}"
        # Check if path is an array
        if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*$ ]]; then
          local path_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
          local array_idx=0
          ((i++))
          while [[ $i -lt ${#lines[@]} ]]; do
            local path_line="${lines[$i]}"
            local path_line_indent=$(echo "$path_line" | sed 's/[^ ].*//' | wc -c)
            ((path_line_indent--))
            if [[ $path_line_indent -le $path_indent ]] && [[ ! "$path_line" =~ ^[[:space:]]*$ ]]; then
              # Reached end of path array, but don't advance i yet - let main loop handle next line
              ((i--))
              break
            fi
            if [[ "$path_line" =~ ^[[:space:]]*-[[:space:]]*\"(.+)\"$ ]] || [[ "$path_line" =~ ^[[:space:]]*-[[:space:]]*(.+)$ ]]; then
              if [[ $array_idx -eq $path_idx ]]; then
                result="${BASH_REMATCH[1]}"
                result=$(echo "$result" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
                echo "$result"
                return 0
              fi
              ((array_idx++))
            fi
            ((i++))
          done
          # Continue processing - don't skip the next line
          continue
        fi
      elif [[ "$field" =~ ^path[[:space:]]*\|\s*length$ ]]; then
        # Count path array length
        if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*$ ]]; then
          local path_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
          local count=0
          ((i++))
          while [[ $i -lt ${#lines[@]} ]]; do
            local path_line="${lines[$i]}"
            local path_line_indent=$(echo "$path_line" | sed 's/[^ ].*//' | wc -c)
            ((path_line_indent--))
            if [[ $path_line_indent -le $path_indent ]] && [[ ! "$path_line" =~ ^[[:space:]]*$ ]]; then
              break
            fi
            if [[ "$path_line" =~ ^[[:space:]]*- ]]; then
              ((count++))
            fi
            ((i++))
          done
          echo "$count"
          return 0
        fi
      fi
    fi
    
    ((i++))
  done
  
  return 1
}

# Get path type (string vs array)
_yaml_get_path_type() {
  local file="$1"
  local idx="$2"
  
  # Read file into array
  local lines=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done < "$file"
  
  local current_idx=-1
  local in_profile=false
  local indent_level=0
  local i=0
  
  while [[ $i -lt ${#lines[@]} ]]; do
    local line="${lines[$i]}"
    [[ "$line" =~ ^[[:space:]]*# ]] && { ((i++)); continue; }
    
    if [[ "$line" =~ ^profiles:[[:space:]]*$ ]]; then
      ((i++))
      continue
    fi
    
    if [[ "$line" =~ ^[[:space:]]*- ]]; then
      ((current_idx++))
      if [[ $current_idx -eq $idx ]]; then
        in_profile=true
        indent_level=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
        ((indent_level--))
      else
        in_profile=false
      fi
      ((i++))
      continue
    fi
    
    if [[ "$in_profile" == true ]]; then
      local line_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
      ((line_indent--))
      if [[ $line_indent -le $indent_level ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
        break
      fi
      
      if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*$ ]]; then
        echo "!!seq"
        return 0
      elif [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*\"(.+)\"$ ]] || [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.+)$ ]]; then
        echo "!!str"
        return 0
      fi
    fi
    
    ((i++))
  done
  
  echo "!!str"
}

# Get path array length
_yaml_get_path_length() {
  local file="$1"
  local idx="$2"
  
  # Read file into array
  local lines=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done < "$file"
  
  local current_idx=-1
  local in_profile=false
  local indent_level=0
  local i=0
  
  while [[ $i -lt ${#lines[@]} ]]; do
    local line="${lines[$i]}"
    [[ "$line" =~ ^[[:space:]]*# ]] && { ((i++)); continue; }
    
    if [[ "$line" =~ ^profiles:[[:space:]]*$ ]]; then
      ((i++))
      continue
    fi
    
    if [[ "$line" =~ ^[[:space:]]*- ]]; then
      ((current_idx++))
      if [[ $current_idx -eq $idx ]]; then
        in_profile=true
        indent_level=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
        ((indent_level--))
      else
        in_profile=false
      fi
      ((i++))
      continue
    fi
    
    if [[ "$in_profile" == true ]]; then
      local line_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
      ((line_indent--))
      if [[ $line_indent -le $indent_level ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
        break
      fi
      
      # Check if path is an array
      if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*$ ]]; then
        local path_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
        local count=0
        ((i++))
        while [[ $i -lt ${#lines[@]} ]]; do
          local path_line="${lines[$i]}"
          local path_line_indent=$(echo "$path_line" | sed 's/[^ ].*//' | wc -c)
          ((path_line_indent--))
          if [[ $path_line_indent -le $path_indent ]] && [[ ! "$path_line" =~ ^[[:space:]]*$ ]]; then
            break
          fi
          if [[ "$path_line" =~ ^[[:space:]]*- ]]; then
            ((count++))
          fi
          ((i++))
        done
        echo "$count"
        return 0
      elif [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*\"(.+)\"$ ]] || [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.+)$ ]]; then
        # Single path, return 1 (or could return 0, but 1 makes more sense)
        echo "1"
        return 0
      fi
    fi
    
    ((i++))
  done
  
  echo "0"
}

# Find profile by name and return a field
_yaml_find_profile_by_name() {
  local file="$1"
  local name="$2"
  local field="$3"
  
  local count=$(_yaml_count_profiles "$file")
  for ((i=0; i<count; i++)); do
    local profile_name=$(_yaml_get_profile_field "$file" "$i" "name")
    if [[ "$profile_name" == "$name" ]]; then
      _yaml_get_profile_field "$file" "$i" "$field"
      return $?
    fi
  done
  
  return 1
}

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

match_profile() {
  local dir="${1:-$PWD}"
  local best=""
  local best_len=0

  # Iterate profiles and choose the longest matching glob
  local n
  n=$(yaml_get '.profiles | length' "$CONFIG" 2>/dev/null || echo 0)
  for ((i=0; i<n; i++)); do
    # Check if path is an array (multiple paths) or a string (single path)
    local path_type
    path_type=$(yaml_get ".profiles[$i].path | type" "$CONFIG" 2>/dev/null || echo "!!str")
    
    if [[ "$path_type" == *"seq"* ]] || [[ "$path_type" == *"array"* ]]; then
      # Multiple paths - check each one
      local path_count
      path_count=$(yaml_get ".profiles[$i].path | length" "$CONFIG" 2>/dev/null || echo 0)
      for ((j=0; j<path_count; j++)); do
        local pattern
        pattern=$(yaml_get ".profiles[$i].path[$j]" "$CONFIG")
        if [[ -n "$pattern" ]]; then
          # Expand ~
          pattern=${pattern/#\~/$HOME}
          if [[ "$dir" == $pattern* ]]; then
            local len=${#pattern}
            if (( len > best_len )); then
              best_len=$len
              best=$i
            fi
          fi
        fi
      done
    else
      # Single path (backward compatibility)
      local pattern
      pattern=$(yaml_get ".profiles[$i].path" "$CONFIG")
      if [[ -n "$pattern" ]]; then
        # Expand ~
        pattern=${pattern/#\~/$HOME}
        if [[ "$dir" == $pattern* ]]; then
          local len=${#pattern}
          if (( len > best_len )); then
            best_len=$len
            best=$i
          fi
        fi
      fi
    fi
  done

  echo "${best:-}"
}

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
