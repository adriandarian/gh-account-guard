#!/usr/bin/env bash
# Apply hook to repos command: Apply hook to all existing repos in configured paths

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

