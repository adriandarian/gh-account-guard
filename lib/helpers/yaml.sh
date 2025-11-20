#!/usr/bin/env bash
# YAML parsing functions for gh-account-guard
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

# Update a profile field value in YAML
yaml_update_profile_field() {
  local file="$1"
  local profile_idx="$2"
  local field="$3"
  local new_value="$4"
  
  [[ -f "$file" ]] || return 1
  
  # Read file into array
  local lines=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done < "$file"
  
  local temp_file
  temp_file=$(mktemp)
  
  local current_idx=-1
  local in_profile=false
  local indent_level=0
  local i=0
  local field_updated=false
  
  while [[ $i -lt ${#lines[@]} ]]; do
    local line="${lines[$i]}"
    
    # Copy comments and empty lines as-is
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
      echo "$line" >> "$temp_file"
      ((i++))
      continue
    fi
    
    # Check if we're entering profiles section
    if [[ "$line" =~ ^profiles:[[:space:]]*$ ]]; then
      echo "$line" >> "$temp_file"
      ((i++))
      continue
    fi
    
    # Check if we're starting a new profile
    if [[ "$line" =~ ^[[:space:]]*- ]]; then
      ((current_idx++))
      if [[ $current_idx -eq $profile_idx ]]; then
        in_profile=true
        indent_level=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
        ((indent_level--))
      else
        in_profile=false
      fi
      echo "$line" >> "$temp_file"
      ((i++))
      continue
    fi
    
    if [[ "$in_profile" == true ]]; then
      # Check if we've left this profile
      local line_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
      ((line_indent--))
      if [[ $line_indent -le $indent_level ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
        # We've left the profile, but field wasn't updated - add it
        if [[ "$field_updated" == false ]]; then
          _yaml_add_missing_field "$temp_file" "$indent_level" "$field" "$new_value"
        fi
        echo "$line" >> "$temp_file"
        ((i++))
        continue
      fi
      
      local profile_field_indent=$((indent_level + 2))
      
      # Handle different field types
      if [[ "$field" == "name" ]] && [[ "$line" =~ ^[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
        if [[ $line_indent -le $profile_field_indent ]]; then
          echo "    name: \"$new_value\"" >> "$temp_file"
          field_updated=true
          ((i++))
          continue
        fi
      elif [[ "$field" == "gh_username" ]] && [[ "$line" =~ ^[[:space:]]*gh_username:[[:space:]]*(.+)$ ]]; then
        if [[ $line_indent -le $profile_field_indent ]]; then
          echo "    gh_username: \"$new_value\"" >> "$temp_file"
          field_updated=true
          ((i++))
          continue
        fi
      elif [[ "$field" == "remote_match" ]]; then
        if [[ "$line" =~ ^[[:space:]]*remote_match:[[:space:]]*(.+)$ ]] && [[ $line_indent -le $profile_field_indent ]]; then
          if [[ -n "$new_value" ]]; then
            echo "    remote_match: \"$new_value\"" >> "$temp_file"
          fi
          field_updated=true
          ((i++))
          continue
        elif [[ "$line" =~ ^[[:space:]]*git:[[:space:]]*$ ]] && [[ "$field_updated" == false ]]; then
          # Insert remote_match before git section if it doesn't exist
          if [[ -n "$new_value" ]]; then
            echo "    remote_match: \"$new_value\"" >> "$temp_file"
            field_updated=true
          fi
          echo "$line" >> "$temp_file"
          ((i++))
          continue
        fi
      elif [[ "$field" =~ ^git\.(.+)$ ]]; then
        local git_field="${BASH_REMATCH[1]}"
        if [[ "$line" =~ ^[[:space:]]*git:[[:space:]]*$ ]]; then
          echo "$line" >> "$temp_file"
          local git_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
          ((i++))
          local git_field_found=false
          while [[ $i -lt ${#lines[@]} ]]; do
            local git_line="${lines[$i]}"
            local git_line_indent=$(echo "$git_line" | sed 's/[^ ].*//' | wc -c)
            ((git_line_indent--))
            if [[ $git_line_indent -le $git_indent ]] && [[ ! "$git_line" =~ ^[[:space:]]*$ ]]; then
              # End of git section, add field if not found
              if [[ "$git_field_found" == false ]]; then
                if [[ "$git_field" == "gpgsign" ]]; then
                  echo "      ${git_field}: $new_value" >> "$temp_file"
                else
                  echo "      ${git_field}: \"$new_value\"" >> "$temp_file"
                fi
              fi
              ((i--))
              break
            fi
            if [[ "$git_line" =~ ^[[:space:]]*${git_field}:[[:space:]]*(.+)$ ]]; then
              # Update the git field
              if [[ "$git_field" == "gpgsign" ]]; then
                echo "      ${git_field}: $new_value" >> "$temp_file"
              else
                echo "      ${git_field}: \"$new_value\"" >> "$temp_file"
              fi
              git_field_found=true
            else
              echo "$git_line" >> "$temp_file"
            fi
            ((i++))
          done
          field_updated=true
          ((i++))
          continue
        fi
      elif [[ "$field" == "path" ]]; then
        # Path is complex - handle both string and array cases
        if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*$ ]]; then
          # It's an array - skip the entire array and replace
          local path_indent=$(echo "$line" | sed 's/[^ ].*//' | wc -c)
          echo "    path: \"$new_value\"" >> "$temp_file"
          ((i++))
          # Skip all array items
          while [[ $i -lt ${#lines[@]} ]]; do
            local path_line="${lines[$i]}"
            local path_line_indent=$(echo "$path_line" | sed 's/[^ ].*//' | wc -c)
            ((path_line_indent--))
            if [[ $path_line_indent -le $path_indent ]] && [[ ! "$path_line" =~ ^[[:space:]]*$ ]]; then
              ((i--))
              break
            fi
            ((i++))
          done
          field_updated=true
          ((i++))
          continue
        elif [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.+)$ ]] && [[ $line_indent -le $profile_field_indent ]]; then
          # It's a string - replace it
          echo "    path: \"$new_value\"" >> "$temp_file"
          field_updated=true
          ((i++))
          continue
        fi
      fi
    fi
    
    echo "$line" >> "$temp_file"
    ((i++))
  done
  
  # If field wasn't found and updated, add it at the end of the profile
  if [[ "$field_updated" == false ]] && [[ $current_idx -eq $profile_idx ]]; then
    _yaml_add_missing_field "$temp_file" "$indent_level" "$field" "$new_value"
  fi
  
  mv "$temp_file" "$file"
}

# Helper to add a missing field to a profile
_yaml_add_missing_field() {
  local temp_file="$1"
  local indent_level="$2"
  local field="$3"
  local new_value="$4"
  
  local indent_spaces=""
  for ((j=0; j<$((indent_level + 2)); j++)); do
    indent_spaces="${indent_spaces} "
  done
  
  if [[ "$field" == "name" ]] || [[ "$field" == "gh_username" ]] || [[ "$field" == "remote_match" ]]; then
    if [[ "$field" == "remote_match" && -z "$new_value" ]]; then
      return 0
    fi
    echo "${indent_spaces}${field}: \"$new_value\"" >> "$temp_file"
  elif [[ "$field" =~ ^git\.(.+)$ ]]; then
    local git_field="${BASH_REMATCH[1]}"
    # Check if git section exists - if not, we need to add it
    # For now, assume git section exists and add the field
    local git_indent_spaces="${indent_spaces}  "
    if [[ "$git_field" == "gpgsign" ]]; then
      echo "${git_indent_spaces}${git_field}: $new_value" >> "$temp_file"
    else
      echo "${git_indent_spaces}${git_field}: \"$new_value\"" >> "$temp_file"
    fi
  elif [[ "$field" == "path" ]]; then
    echo "${indent_spaces}path: \"$new_value\"" >> "$temp_file"
  fi
}

