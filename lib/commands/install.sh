#!/usr/bin/env bash
# Install command: Install shell hook and git pre-commit hook

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
    if git_is_repo && [ -t 0 ] 2>/dev/null && [ -t 1 ] 2>/dev/null; then
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
    elif git_is_repo; then
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
    if [[ "$install_git" == true ]] && git rev-parse --git-dir >/dev/null 2>&1; then
      echo "  ✓ Git pre-commit hook (validates identity before commits)"
    fi
    echo ""
    echo "Next steps:"
    if [[ "$install_shell" == true ]]; then
      echo "  - Open a new terminal or run: source $shell_config"
    fi
    if [[ "$install_git" == true ]] && git rev-parse --git-dir >/dev/null 2>&1; then
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
