#!/usr/bin/env bash
# Directory browsing functions for gh-account-guard
# Recursive function to get directories (used by prompt_paths)
get_dirs_recursive() {
  local base_dir="$1"
  local max_depth="${2:-3}"
  local current_depth="${3:-0}"
  
  if [[ $current_depth -ge $max_depth ]]; then
    return
  fi
  
  # Output current directory
  echo "$base_dir"
  
  # Get immediate subdirectories only (one level)
  if has_fd; then
    # Use fd - it's faster and handles paths better
    fd -t d --max-depth 1 --base-directory "$base_dir" --hidden=false 2>/dev/null | \
      while IFS= read -r subdir; do
        local full_path="$base_dir/$subdir"
        # Normalize path (remove double slashes)
        full_path=$(echo "$full_path" | sed 's|//|/|g')
        if [[ -d "$full_path" ]]; then
          get_dirs_recursive "$full_path" "$max_depth" $((current_depth + 1))
        fi
      done
  else
    # Fallback to find
    find "$base_dir" -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*' 2>/dev/null | \
      while IFS= read -r subdir; do
        get_dirs_recursive "$subdir" "$max_depth" $((current_depth + 1))
      done
  fi
}
# Pure bash directory browser (cross-platform, no external deps)
# Supports navigation, multi-select, and directory preview
prompt_paths_pure_bash() {
  local prompt_text="$1"
  local start_dir="${2:-}"
  # Use configurable default directory or HOME
  if [[ -z "$start_dir" ]]; then
    start_dir=$(get_default_directory)
  fi
  # Expand ~ if present
  start_dir=${start_dir/#\~/$HOME}
  # Ensure it's a valid directory
  if [[ ! -d "$start_dir" ]]; then
    start_dir="$HOME"
  fi
  
  local current_dir="$start_dir"
  local selected_paths=()
  local nav_stack=("$start_dir")  # Navigation stack for "back" functionality
  local display_lines=0  # Track display state for proper clearing
  
  # Function to get directories in current location
  get_directories() {
    local base="$1"
    local dirs=()
    # Use same debug log location as main function
    local debug_log="/tmp/gh-account-guard-debug.log"
    
    # Debug: log the base directory
    echo "[DEBUG] get_directories called with base: $base" >> "$debug_log" 2>&1
    
    # Add parent directory indicator if not at root
    if [[ "$base" != "/" ]] && [[ -n "$base" ]]; then
      local parent=$(dirname "$base")
      if [[ "$parent" != "$base" ]]; then
        dirs+=("..")
        echo "[DEBUG] Added parent directory: .." >> "$debug_log" 2>&1
      fi
    fi
    
    # Get subdirectories
    if [[ -d "$base" ]]; then
      echo "[DEBUG] Base directory exists and is readable" >> "$debug_log" 2>&1
      
      if has_fd; then
        echo "[DEBUG] Using fd to list directories" >> "$debug_log" 2>&1
        # Use fd to get directories - it returns relative paths when using --base-directory
        # Default behavior excludes hidden directories, so no need for --hidden flag
        local fd_output
        fd_output=$(fd -t d --max-depth 1 --base-directory "$base" 2>&1 | sort)
        echo "[DEBUG] fd output: $fd_output" >> "$debug_log" 2>&1
        
        while IFS= read -r rel_path; do
          if [[ -n "$rel_path" ]]; then
            # fd returns relative paths, so we can use them directly as directory names
            dirs+=("$rel_path")
            echo "[DEBUG] Added directory: $rel_path" >> "$debug_log" 2>&1
          fi
        done <<< "$fd_output"
      else
        echo "[DEBUG] Using find to list directories" >> "$debug_log" 2>&1
        # Fallback to find
        while IFS= read -r dir; do
          if [[ -d "$dir" ]] && [[ "$dir" != "$base" ]]; then
            local dir_name=$(basename "$dir" 2>/dev/null || echo "")
            if [[ -n "$dir_name" ]]; then
              dirs+=("$dir_name")
              echo "[DEBUG] Added directory (find): $dir_name" >> "$debug_log" 2>&1
            fi
          fi
        done < <(find "$base" -mindepth 1 -maxdepth 1 -type d -not -path '*/\.*' 2>/dev/null | sort | head -100)
      fi
    else
      echo "[DEBUG] ERROR: Base directory does not exist or is not readable: $base" >> "$debug_log" 2>&1
    fi
    
    echo "[DEBUG] Total directories found: ${#dirs[@]}" >> "$debug_log" 2>&1
    echo "[DEBUG] Directories: ${dirs[*]}" >> "$debug_log" 2>&1
    
    printf '%s\n' "${dirs[@]}"
  }
  
  # Function to display directory browser
  # Output goes to stderr so it's visible even when stdout is captured
  display_browser() {
    local sel_idx="$1"
    local st_idx="$2"
    local dirs_arr=("${@:3}")
    local num_dirs=${#dirs_arr[@]}
    local max_visible=15
    
    # Get terminal width (default to 80 if tput not available)
    local term_width=80
    if command -v tput >/dev/null 2>&1; then
      term_width=$(tput cols 2>/dev/null || echo 80)
    fi
    
    # Calculate column widths (left: directories, right: selected paths)
    # Use 50/50 split with a separator
    local separator=" │ "
    local sep_width=${#separator}
    local left_width=$(( (term_width - sep_width) / 2 ))
    local right_width=$(( term_width - left_width - sep_width ))
    
    # Clear previous display - move cursor up and clear each line
    # This is more reliable than trying to clear the whole screen
    if [[ $display_lines -gt 0 ]]; then
      local i=0
      # Cap clearing at reasonable maximum to avoid issues
      local max_lines=$((display_lines < 30 ? display_lines : 30))
      while [[ $i -lt $max_lines ]]; do
        echo -n "${CURSOR_UP}${CLEAR_LINE}" >&2
        ((i++))
      done
    fi
    
    # Reset line counter for this display
    local new_display_lines=0
    
    # Header: Current path (full width)
    local header_line=$(printf "%-${term_width}s" "$current_dir")
    echo "${BOLD}${YELLOW}${header_line}${RESET}" >&2
    ((new_display_lines++))
    
    # Column headers
    local left_header="Directories"
    local right_header="Selected Paths"
    printf "%-${left_width}s${separator}%s\n" "${BOLD}${CYAN}${left_header}${RESET}" "${BOLD}${GREEN}${right_header}${RESET}" >&2
    ((new_display_lines++))
    
    # Separator line
    local left_sep=$(printf '%*s' $left_width '' | tr ' ' '─')
    local right_sep=$(printf '%*s' $right_width '' | tr ' ' '─')
    echo "${left_sep}${separator}${right_sep}" >&2
    ((new_display_lines++))
    
    # Display directories in left column, selected paths in right column
    local display_end=$((st_idx + max_visible < num_dirs ? st_idx + max_visible : num_dirs))
    local max_rows=$((display_end - st_idx))
    if [[ $max_rows -lt ${#selected_paths[@]} ]]; then
      max_rows=${#selected_paths[@]}
    fi
    
    for ((row=0; row<max_rows; row++)); do
      local left_content=""
      local right_content=""
      
      # Left column: directory entry
      local dir_idx=$((st_idx + row))
      if [[ $dir_idx -lt $num_dirs ]]; then
        local dir_name="${dirs_arr[$dir_idx]}"
      local full_path
      if [[ "$dir_name" == ".." ]]; then
        full_path=$(dirname "$current_dir")
      else
        full_path="$current_dir/$dir_name"
        full_path=$(echo "$full_path" | sed 's|//|/|g')
      fi
      
      local marker=""
      local is_selected=false
      for sel_path in "${selected_paths[@]}"; do
        if [[ "$full_path" == "$sel_path" ]]; then
          is_selected=true
            marker="✓ "
          break
        fi
      done
      
        # Truncate directory name if too long
        local display_name="$dir_name"
        if [[ ${#display_name} -gt $((left_width - 4)) ]]; then
          display_name="${display_name:0:$((left_width - 7))}..."
        fi
        
        # Build left content with proper padding
        local left_padding="  "
        local left_text="${marker}${display_name}"
        local left_visible_len=$(( ${#left_padding} + ${#marker} + ${#display_name} ))
        local left_pad_needed=$((left_width - left_visible_len))
        
        if [[ $dir_idx -eq $sel_idx ]]; then
          left_content="${left_padding}${REVERSE}${left_text}${RESET}$(printf '%*s' $left_pad_needed '')"
      elif [[ "$is_selected" == true ]]; then
          left_content="${left_padding}${GREEN}${left_text}${RESET}$(printf '%*s' $left_pad_needed '')"
        else
          left_content="${left_padding}${left_text}$(printf '%*s' $left_pad_needed '')"
        fi
      else
        # Empty left cell
        left_content=$(printf '%*s' $left_width '')
      fi
      
      # Right column: selected path
      if [[ $row -lt ${#selected_paths[@]} ]]; then
        local sel_path="${selected_paths[$row]}"
        # Truncate path if too long
        local display_path="$sel_path"
        if [[ ${#display_path} -gt $((right_width - 2)) ]]; then
          display_path="...${display_path: -$((right_width - 5))}"
        fi
        local right_visible_len=${#display_path}
        local right_pad_needed=$((right_width - right_visible_len))
        right_content="${GREEN}${display_path}${RESET}$(printf '%*s' $right_pad_needed '')"
      else
        # Empty right cell
        right_content=$(printf '%*s' $right_width '')
      fi
      
      # Print the row (without printf formatting to avoid ANSI code issues)
      echo -n "${left_content}${separator}${right_content}" >&2
      echo "" >&2
      ((new_display_lines++))
    done
    
    # Footer with instructions
    echo "" >&2
    ((new_display_lines++))
    local footer="${CYAN}↑↓: navigate  →: enter dir  Space: select  Enter: finish  ←: back  Esc: cancel${RESET}"
    printf "%-${term_width}s\n" "$footer" >&2
    ((new_display_lines++))
    
    # Update the persistent display_lines variable
    display_lines=$new_display_lines
  }
  
  # Main navigation loop
  # Always try to show the browser
  # We read from /dev/tty directly to work even when stdin is redirected (command substitution)
  
  # Check if we can read from /dev/tty (more reliable than is_tty check)
  if [[ ! -r /dev/tty ]]; then
    echo "Error: Cannot read from terminal. Please run in an interactive terminal." >&2
    return 1
  fi
  
  # Hide cursor for cleaner UI
  # Write to stderr so it's visible even when stdout is captured
  echo -n "${HIDE_CURSOR}" >&2
  
  local selected_idx=0
  local start_idx=0
  # Use a fixed location that's easier to find
  local debug_log="/tmp/gh-account-guard-debug.log"
  
  # Clear debug log at start and show location to user
  echo "=== Starting file browser ===" > "$debug_log" 2>&1
  echo "Current directory: $current_dir" >> "$debug_log" 2>&1
  echo "Debug log: $debug_log" >&2
  
  local dirs
  dirs=($(get_directories "$current_dir"))
  local num_dirs=${#dirs[@]}
  
  echo "Number of directories found: $num_dirs" >> "$debug_log" 2>&1
  echo "Directories array: ${dirs[*]}" >> "$debug_log" 2>&1
  
  # If no directories found, show error message
  if [[ $num_dirs -eq 0 ]]; then
    echo "Warning: No directories found in $current_dir" >&2
    echo "Check debug log at: $debug_log" >&2
  fi
  
  # Initial display - always show the browser
  # Write display to stderr so it's visible even when stdout is captured (command substitution)
  display_browser "$selected_idx" "$start_idx" "${dirs[@]}" >&2
  
  # Read input from /dev/tty directly to ensure we get keyboard input
  # even when stdin is redirected (command substitution)
    local key
    local key2
    local key3
    
  # Check if /dev/tty is available
  if [[ ! -r /dev/tty ]]; then
    echo "Error: Cannot read from terminal. Please run in an interactive terminal." >&2
    return 1
  fi
  
  # Save terminal settings
  local old_stty
  old_stty=$(stty -g 2>/dev/null || echo "")
  # Configure terminal for single character input
  # Use -icanon with min 1 time 0 for immediate character reads
  # Also set icrnl to convert \r to \n (helps with Enter detection)
  stty -echo -icanon min 1 time 0 icrnl 2>/dev/null || stty -echo -icanon min 1 time 0 2>/dev/null || true
  
  while IFS= read -rs -n1 key < /dev/tty; do
    # Debug: log key presses  
    local key_hex
    local key_len=${#key}
    
    if [[ -z "$key" ]]; then
      echo "[DEBUG] Empty key read detected - this might be Enter on macOS" >> "$debug_log" 2>&1
      # In non-canonical mode on macOS, Enter produces empty read
      # The issue is that with min 1 time 0, Enter doesn't produce \n
      # Solution: treat empty read as Enter if it happens (user intent)
      # But we need to be careful - only treat as Enter if it's a real empty read
      # Check if there's any pending input
      local pending_check
      IFS= read -rs -n1 -t 0.01 pending_check < /dev/tty 2>/dev/null || pending_check=""
      
      if [[ -z "$pending_check" ]]; then
        # No pending input - this empty read is likely Enter
        # On macOS with non-canonical mode, Enter produces empty read
        echo "[DEBUG] No pending input - treating empty read as Enter" >> "$debug_log" 2>&1
        key=$'\n'  # Treat as Enter
        key_hex="0a"
        key_len=1
      else
        # Got some input - not Enter, process the pending char
        echo "[DEBUG] Got pending input after empty read: $(printf '%q' "$pending_check")" >> "$debug_log" 2>&1
        key="$pending_check"
        key_hex=$(printf '%02x' "'$key" 2>/dev/null || echo "00")
        key_len=${#key}
      fi
    fi
    
    key_hex=$(printf '%02x' "'$key" 2>/dev/null || echo "00")
    echo "[DEBUG] Key pressed: $(printf '%q' "$key") (hex: $key_hex, len: $key_len)" >> "$debug_log" 2>&1
    
    # Check for Enter key FIRST (before escape sequence check)
    # In cbreak mode, Enter produces \n (0x0a) or \r (0x0d)
    if [[ "$key" == $'\n' ]] || [[ "$key" == $'\r' ]] || [[ "$key_hex" == "0a" ]] || [[ "$key_hex" == "0d" ]]; then
      # Enter pressed - finish with selections and return
      echo "[DEBUG] Enter key detected! Key: $(printf '%q' "$key"), hex: $key_hex" >> "$debug_log" 2>&1
      echo "[DEBUG] Selected paths count: ${#selected_paths[@]}" >> "$debug_log" 2>&1
      echo "[DEBUG] Selected paths: ${selected_paths[*]}" >> "$debug_log" 2>&1
      echo "[DEBUG] Current directory: $current_dir" >> "$debug_log" 2>&1
      
      # Show a message to user before exiting
      echo "" >&2
      echo "Finishing selection..." >&2
      
      # Restore terminal settings before breaking
      [[ -n "$old_stty" ]] && stty "$old_stty" 2>/dev/null || stty echo icanon 2>/dev/null || true
      break
    elif [[ "$key" == $'\033' ]]; then
      # Read the rest of the escape sequence
      read -rs -n1 key2 < /dev/tty
      if [[ "$key2" == '[' ]]; then
        read -rs -n1 key3 < /dev/tty
        case "$key3" in
          'A') # Up arrow - move selection up
            if [[ $selected_idx -gt 0 ]]; then
              ((selected_idx--))
              if [[ $selected_idx -lt $start_idx ]]; then
                start_idx=$selected_idx
              fi
              # Refresh display to show new selection
              display_browser "$selected_idx" "$start_idx" "${dirs[@]}" >&2
            fi
            ;;
          'B') # Down arrow - move selection down
            if [[ $selected_idx -lt $((num_dirs - 1)) ]]; then
              ((selected_idx++))
              local max_visible=15
              if [[ $selected_idx -ge $((start_idx + max_visible)) ]]; then
                start_idx=$((selected_idx - max_visible + 1))
              fi
              # Refresh display to show new selection
              display_browser "$selected_idx" "$start_idx" "${dirs[@]}" >&2
            fi
            ;;
          'C') # Right arrow - enter directory (refresh directory list)
            if [[ $num_dirs -gt 0 ]]; then
              local dir_name="${dirs[$selected_idx]}"
              if [[ "$dir_name" == ".." ]]; then
                current_dir=$(dirname "$current_dir")
                if [[ ${#nav_stack[@]} -gt 1 ]]; then
                  unset 'nav_stack[-1]'
                fi
              else
                local new_dir="$current_dir/$dir_name"
                new_dir=$(echo "$new_dir" | sed 's|//|/|g')
                if [[ -d "$new_dir" ]]; then
                  nav_stack+=("$current_dir")
                  current_dir="$new_dir"
                fi
              fi
              selected_idx=0
              start_idx=0
              dirs=($(get_directories "$current_dir"))
              num_dirs=${#dirs[@]}
              display_browser "$selected_idx" "$start_idx" "${dirs[@]}" >&2
            fi
            ;;
          'D') # Left arrow - go back to parent (refresh directory list)
            if [[ "$current_dir" != "/" ]] && [[ -n "$current_dir" ]]; then
              local parent_dir=$(dirname "$current_dir")
              if [[ "$parent_dir" != "$current_dir" ]]; then
                nav_stack+=("$current_dir")
                current_dir="$parent_dir"
                selected_idx=0
                start_idx=0
                dirs=($(get_directories "$current_dir"))
                num_dirs=${#dirs[@]}
                display_browser "$selected_idx" "$start_idx" "${dirs[@]}" >&2
              fi
            fi
            ;;
        esac
      elif [[ "$key2" == '' ]]; then
        # Esc pressed - cancel
        [[ -n "$old_stty" ]] && stty "$old_stty" 2>/dev/null || stty echo icanon 2>/dev/null || true
        echo -n "${SHOW_CURSOR}" >&2
        # Clear display
        local lines_to_clear=$((15 + 6))
        local i=0
        while [[ $i -lt $lines_to_clear ]]; do
          echo -n "${CURSOR_UP}${CLEAR_LINE}" >&2
          ((i++))
        done
        return 130
      fi
    elif [[ "$key" == ' ' ]]; then
      # Space - toggle selection of current directory/path
      if [[ $num_dirs -gt 0 ]]; then
          local dir_name="${dirs[$selected_idx]}"
          local full_path
          if [[ "$dir_name" == ".." ]]; then
            full_path=$(dirname "$current_dir")
          else
            full_path="$current_dir/$dir_name"
            full_path=$(echo "$full_path" | sed 's|//|/|g')
          fi
          
          # Toggle selection
          local found=false
          local new_selected=()
          for sel_path in "${selected_paths[@]}"; do
            if [[ "$sel_path" != "$full_path" ]]; then
              new_selected+=("$sel_path")
            else
              found=true
            fi
          done
          
          if [[ "$found" == false ]]; then
            new_selected+=("$full_path")
          fi
          
          selected_paths=("${new_selected[@]}")
          display_browser "$selected_idx" "$start_idx" "${dirs[@]}" >&2
        fi
    elif [[ "$key" == $'\x1b' ]]; then
      # Esc pressed (alternative)
      [[ -n "$old_stty" ]] && stty "$old_stty" 2>/dev/null || stty echo icanon 2>/dev/null || true
      echo -n "${SHOW_CURSOR}" >&2
      # Clear display
      local lines_to_clear=$((15 + 6))
      local i=0
      while [[ $i -lt $lines_to_clear ]]; do
        echo -n "${CURSOR_UP}${CLEAR_LINE}" >&2
        ((i++))
      done
      return 130
    fi
  done
  
  # Restore terminal settings
  [[ -n "$old_stty" ]] && stty "$old_stty" 2>/dev/null || stty echo icanon 2>/dev/null || true
  
  # Show cursor again
  echo -n "${SHOW_CURSOR}" >&2
  
  # Clear display
  local lines_to_clear=$((15 + 6))
  local i=0
  while [[ $i -lt $lines_to_clear ]]; do
    echo -n "${CURSOR_UP}${CLEAR_LINE}" >&2
    ((i++))
  done
  
  # Return selected paths or current directory
  # Display message to stderr, result to stdout (for command substitution)
  echo "[DEBUG] Exiting browser, selected_paths count: ${#selected_paths[@]}" >> "$debug_log" 2>&1
  
  if [[ ${#selected_paths[@]} -gt 0 ]]; then
    result=$(IFS=','; echo "${selected_paths[*]}")
    echo "[DEBUG] Returning selected paths: $result" >> "$debug_log" 2>&1
    echo "✅ Selected: $result" >&2
    echo "$result"  # This goes to stdout for command substitution
    return 0
  else
    # No paths selected, return current directory
    echo "[DEBUG] No paths selected, returning current directory: $current_dir" >> "$debug_log" 2>&1
    echo "✅ Selected: $current_dir" >&2
    echo "$current_dir"  # This goes to stdout for command substitution
    return 0
  fi
}

prompt_paths() {
  local prompt_text="$1"
  local result=""
  
  # Always use pure bash directory browser (custom file tree parser)
  # This provides the arrow key navigation: ↑↓ to navigate, → to enter, ← to go back, Space to select, Enter to finish
  local default_dir
  default_dir=$(get_default_directory)
  prompt_paths_pure_bash "$prompt_text" "$default_dir"
  return $?
}
