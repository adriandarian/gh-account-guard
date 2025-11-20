#!/usr/bin/env bash
# Profile matching and management functions for gh-account-guard

# Match a directory path to a profile index
match_profile() {
  local dir="${1:-$PWD}"
  local best=""
  local best_len=0

  # Normalize directory path (remove trailing slash for consistent matching)
  dir="${dir%/}"

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
          # Expand ~ and normalize (remove trailing slash)
          pattern=${pattern/#\~/$HOME}
          pattern="${pattern%/}"
          # Check if directory matches pattern (exact match or starts with pattern/)
          if [[ "$dir" == "$pattern" ]] || [[ "$dir" == "$pattern"/* ]]; then
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
        # Expand ~ and normalize (remove trailing slash)
        pattern=${pattern/#\~/$HOME}
        pattern="${pattern%/}"
        # Check if directory matches pattern (exact match or starts with pattern/)
        if [[ "$dir" == "$pattern" ]] || [[ "$dir" == "$pattern"/* ]]; then
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

# Get profile field value
profile_get_field() {
  local idx="$1"
  local field="$2"
  yaml_get ".profiles[$idx].$field" "$CONFIG" 2>/dev/null || echo ""
}

# Get profile git identity
profile_get_git_identity() {
  local idx="$1"
  local name
  local email
  local signing_key
  local gpg_format
  local gpgsign
  
  name=$(yaml_get ".profiles[$idx].git.name" "$CONFIG" 2>/dev/null || echo "")
  email=$(yaml_get ".profiles[$idx].git.email" "$CONFIG" 2>/dev/null || echo "")
  signing_key=$(yaml_get ".profiles[$idx].git.signingkey" "$CONFIG" 2>/dev/null || echo "")
  gpg_format=$(yaml_get ".profiles[$idx].git.gpgformat" "$CONFIG" 2>/dev/null || echo "")
  gpgsign=$(yaml_get ".profiles[$idx].git.gpgsign" "$CONFIG" 2>/dev/null || echo "")
  
  echo "$name|$email|$signing_key|$gpg_format|$gpgsign"
}

