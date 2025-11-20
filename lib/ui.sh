#!/usr/bin/env bash
# UI functions for gh-account-guard
# Source utils first for ANSI codes and utility functions
# Pure bash interactive menu with arrow key support (cross-platform, no external deps)
# Works on macOS, Linux, and Windows (Git Bash/WSL)
interactive_menu_pure_bash() {
  local prompt_text="$1"
  local header_text="${2:-}"
  shift 2 2>/dev/null || shift 1
  local options=("$@")
  local selected_idx=0
  local confirmed_idx=-1  # Track which option is selected with space
  local num_options=${#options[@]}
  
  if [[ $num_options -eq 0 ]]; then
    return 1
  fi
  
  # Display header if provided
  if [[ -n "$header_text" ]]; then
    echo "$header_text"
    echo ""
  fi
  
  # Function to display menu with bullet points
  display_menu() {
    echo "$prompt_text"
    echo ""
    local i=0
    for opt in "${options[@]}"; do
      local bullet="○"
      local prefix="  "
      
      # Show filled bullet if this option is confirmed (space was pressed)
      if [[ $i -eq $confirmed_idx ]]; then
        bullet="●"
      fi
      
      # Highlight current selection
      if [[ $i -eq $selected_idx ]]; then
        echo "${CYAN}${prefix}${bullet} ${BOLD}${opt}${RESET}"
      else
        echo "${prefix}${bullet} ${opt}"
      fi
      ((i++))
    done
    echo ""
    if [[ $confirmed_idx -ge 0 ]]; then
      echo "${CYAN}Use ↑↓ to navigate, Space to select, Enter to confirm, Esc to cancel${RESET}"
    else
      echo "${CYAN}Use ↑↓ to navigate, Space to select, Enter to confirm, Esc to cancel${RESET}"
    fi
  }
  
  # Function to clear menu (move cursor up)
  clear_menu() {
    local lines=$((num_options + 5))
    local i=0
    while [[ $i -lt $lines ]]; do
      echo -n "${CURSOR_UP}${CLEAR_LINE}"
      ((i++))
    done
  }
  
  # Initial display
  # Try to use interactive menu if we have a TTY or can access /dev/tty
  local use_tty=false
  if [ -t 0 ] && [ -t 1 ]; then
    use_tty=true
  elif [ -r /dev/tty ] 2>/dev/null && [ -w /dev/tty ] 2>/dev/null; then
    use_tty=true
  fi
  
  if [[ "$use_tty" == true ]]; then
    display_menu
    
    # Determine input source - use /dev/tty if stdin is not a TTY
    local input_source
    if [ -t 0 ]; then
      input_source="/dev/stdin"
    else
      input_source="/dev/tty"
    fi
    
    # Read arrow keys (works on macOS, Linux, Windows Git Bash)
    local key
    local key2
    local key3
    
    while IFS= read -rs -n1 key < "$input_source"; do
      # Handle escape sequences (arrow keys)
      if [[ "$key" == $'\033' ]]; then
        read -rs -n1 key2 < "$input_source"
        if [[ "$key2" == '[' ]]; then
          read -rs -n1 key3 < "$input_source"
          case "$key3" in
            'A') # Up arrow
              if [[ $selected_idx -gt 0 ]]; then
                ((selected_idx--))
                clear_menu
                display_menu
              fi
              ;;
            'B') # Down arrow
              if [[ $selected_idx -lt $((num_options - 1)) ]]; then
                ((selected_idx++))
                clear_menu
                display_menu
              fi
              ;;
          esac
        elif [[ "$key2" == '' ]]; then
          # Esc pressed
          echo "${SHOW_CURSOR}"
          return 130
        fi
      elif [[ "$key" == $' ' ]]; then
        # Space pressed - select current option
        confirmed_idx=$selected_idx
        clear_menu
        display_menu
      elif [[ "$key" == $'\n' ]] || [[ "$key" == $'\r' ]]; then
        # Enter pressed - confirm selection
        echo "${SHOW_CURSOR}"
        # If space was pressed, use that selection, otherwise use current highlighted option
        local final_idx=$selected_idx
        if [[ $confirmed_idx -ge 0 ]]; then
          final_idx=$confirmed_idx
        fi
        echo "${options[$final_idx]}"
        return 0
      elif [[ "$key" == $'\x1b' ]]; then
        # Esc pressed (alternative)
        echo "${SHOW_CURSOR}"
        return 130
      fi
    done
  else
    # Not a TTY - fall back to bullet point menu with number input
    # Output menu to stderr so it's visible when called via command substitution
    # Only the selected choice goes to stdout
    if [[ -n "$header_text" ]]; then
      echo "$header_text" >&2
      echo "" >&2
    fi
    echo "$prompt_text" >&2
    echo "" >&2
    local i=0
    for opt in "${options[@]}"; do
      echo "  ○ $opt" >&2
      ((i++))
    done
    echo "" >&2
    echo "${CYAN}Enter the number (1-$num_options) to select, or press Enter for option 1${RESET}" >&2
    local choice
    while true; do
      echo -n "Choose [1-$num_options]: " >&2
      read -r choice
      # Default to option 1 if Enter pressed with no input
      if [[ -z "$choice" ]]; then
        choice=1
      fi
      if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $num_options ]]; then
        echo "${options[$((choice-1))]}"
        return 0
      else
        echo "Invalid choice. Please enter a number between 1 and $num_options" >&2
        continue
      fi
    done
  fi
}

# Interactive menu with arrow keys support (tries fzf/gum first, falls back to pure bash)
interactive_menu() {
  local prompt_text="$1"
  local header_text="${2:-}"
  # If second arg looks like an option (doesn't contain "exists" or looks like menu text), treat as header
  # Otherwise, it's the first option
  if [[ -n "$header_text" && ("$header_text" == *"exists"* || ${#@} -gt 3) ]]; then
    shift 2
  else
    # No header provided, second arg is actually first option
    header_text=""
    shift 1
  fi
  local options=("$@")
  
  # Combine prompt and header if header provided
  local full_header="$prompt_text"
  if [[ -n "$header_text" ]]; then
    full_header="$header_text

$prompt_text"
  fi
  
  # Try fzf first if available (it handles TTY checks internally)
  if has_fzf && is_tty; then
    # Use fzf for beautiful interactive selection
    # Arrow keys: navigate, Enter: select, Esc: cancel
    local selected
    # Try to run fzf - it will fail gracefully if not in a TTY
    # Exit code 130 = Esc pressed, 1 = other error
    selected=$(printf '%s\n' "${options[@]}" | fzf --height=10 --header="$full_header" --reverse --no-multi 2>/dev/null)
    local exit_code=$?
    if [[ $exit_code -eq 0 && -n "$selected" ]]; then
      echo "$selected"
      return 0
    elif [[ $exit_code -eq 130 ]]; then
      # User pressed Esc - cancel
      return 130
    fi
    # fzf failed for other reasons (not in a TTY) - fall through to next option
  fi
  
  if has_gum && is_tty; then
    # Try gum choose as fallback
    local selected
    selected=$(gum choose "${options[@]}" 2>&1)
    local exit_code=$?
    if [[ $exit_code -eq 0 && -n "$selected" ]]; then
      echo "$selected"
      return 0
    elif [[ $exit_code -eq 130 ]]; then
      # User pressed Esc/Ctrl+C - cancel
      return 130
    else
      return 1
    fi
  fi
  
  # Use pure bash menu (works everywhere, no dependencies)
  interactive_menu_pure_bash "$prompt_text" "$header_text" "${options[@]}"
}

show_banner() {
  if [ -t 1 ]; then
    echo "${CYAN}"
    cat << "EOF"
   ____  _   _    _    ____  
  / ___|| | | |  / \  / ___| 
 | |  _ | |_| | / _ \| |  _  
 | |_| ||  _  |/ ___ \ |_| | 
  \____||_| |_/_/   \_\____| 
  ACCOUNT GUARD
EOF
    echo "${RESET}"
    echo ""
  fi
}

prompt() {
  local prompt_text="$1"
  local default_value="${2:-}"
  local result=""
  
  if has_gum; then
    if [[ -n "$default_value" ]]; then
      if ! result=$(gum input --placeholder "$default_value" --prompt "$prompt_text: " --value "$default_value" 2>&1) || [[ -z "$result" ]]; then
        # gum failed, fall back to basic prompt
        read -r -p "$prompt_text [$default_value]: " result
        echo "${result:-$default_value}"
      else
        echo "${result:-$default_value}"
      fi
    else
      if ! result=$(gum input --prompt "$prompt_text: " 2>&1) || [[ -z "$result" ]]; then
        # gum failed, fall back to basic prompt
        while [[ -z "$result" ]]; do
          read -r -p "$prompt_text: " result
        done
        echo "$result"
      else
        while [[ -z "$result" ]]; do
          if ! result=$(gum input --prompt "$prompt_text: " 2>&1) || [[ -z "$result" ]]; then
            read -r -p "$prompt_text: " result
          fi
        done
        echo "$result"
      fi
    fi
  else
    # Fallback to basic prompt
    if [[ -n "$default_value" ]]; then
      read -r -p "$prompt_text [$default_value]: " result
      echo "${result:-$default_value}"
    else
      while [[ -z "$result" ]]; do
        read -r -p "$prompt_text: " result
      done
      echo "$result"
    fi
  fi
}
prompt_optional() {
  local prompt_text="$1"
  local default_value="${2:-}"
  local result=""
  
  if has_gum; then
    if [[ -n "$default_value" ]]; then
      if ! result=$(gum input --placeholder "Press Enter to skip" --prompt "$prompt_text: " --value "$default_value" 2>&1); then
        # gum failed, fall back to basic prompt
        read -r -p "$prompt_text [$default_value] (press Enter to skip): " result
        echo "${result:-$default_value}"
      else
        echo "${result:-$default_value}"
      fi
    else
      if ! result=$(gum input --placeholder "Press Enter to skip" --prompt "$prompt_text: " 2>&1); then
        # gum failed, fall back to basic prompt
        read -r -p "$prompt_text (press Enter to skip): " result
        echo "${result:-}"
      else
        echo "${result:-}"
      fi
    fi
  else
    # Fallback to basic prompt
    if [[ -n "$default_value" ]]; then
      read -r -p "$prompt_text [$default_value] (press Enter to skip): " result
      echo "${result:-$default_value}"
    else
      read -r -p "$prompt_text (press Enter to skip): " result
      echo "${result:-}"
    fi
  fi
}

prompt_yesno() {
  local prompt_text="$1"
  local default="${2:-n}"
  
  if has_gum; then
    if [[ "$default" == "y" ]]; then
      gum confirm "$prompt_text" --default=true 2>&1
      local exit_code=$?
      if [[ $exit_code -ne 0 && $exit_code -ne 1 ]]; then
        # gum failed (not just user said no), fall back to basic prompt
        local result=""
        read -r -p "$prompt_text [Y/n]: " result
        [[ "${result:-y}" =~ ^[Yy] ]]
      else
        return $exit_code
      fi
    else
      gum confirm "$prompt_text" --default=false 2>&1
      local exit_code=$?
      if [[ $exit_code -ne 0 && $exit_code -ne 1 ]]; then
        # gum failed (not just user said no), fall back to basic prompt
        local result=""
        read -r -p "$prompt_text [y/N]: " result
        [[ "${result:-n}" =~ ^[Yy] ]]
      else
        return $exit_code
      fi
    fi
  else
    # Fallback to basic prompt
    local result=""
    if [[ "$default" == "y" ]]; then
      read -r -p "$prompt_text [Y/n]: " result
      if [[ "${result:-y}" =~ ^[Yy] ]]; then
        return 0
      else
        return 1
      fi
    else
      read -r -p "$prompt_text [y/N]: " result
      if [[ "${result:-n}" =~ ^[Yy] ]]; then
        return 0
      else
        return 1
      fi
    fi
  fi
}
