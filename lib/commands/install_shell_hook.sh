#!/usr/bin/env bash
# Install shell hook command: Prints a shell snippet for auto-enforcement

cmd_install_shell_hook() {
  local shell_arg="${1:-}"
  local current_shell=""
  
  # Check for explicit shell argument
  case "$shell_arg" in
    --fish|-f) current_shell="fish" ;;
    --zsh|-z) current_shell="zsh" ;;
    --bash|-b) current_shell="bash" ;;
    "")
      # Auto-detect shell
      current_shell="${SHELL##*/}"
      
      # If shell not detected or is sh, try to detect from parent process
      if [[ -z "$current_shell" ]] || [[ "$current_shell" == "sh" ]]; then
        local parent_cmd
        parent_cmd=$(ps -p $PPID -o comm= 2>/dev/null || echo "")
        if [[ "$parent_cmd" == *"fish"* ]]; then
          current_shell="fish"
        elif [[ "$parent_cmd" == *"zsh"* ]]; then
          current_shell="zsh"
        elif [[ "$parent_cmd" == *"bash"* ]]; then
          current_shell="bash"
        fi
      fi
      ;;
    *)
      echo "Unknown option: $shell_arg" >&2
      echo "Usage: gh account-guard install-shell-hook [--fish|--zsh|--bash]" >&2
      exit 1
      ;;
  esac
  
  case "$current_shell" in
    fish)
      cat <<'FISH'
# --- gh-account-guard shell hook ---
# This automatically enforces the correct git identity when you change directories.
# Git commits/pushes use git config (per-repo), so this enables automatic commits
# without manual credential switching. Works even when multiple editors are open.
function __gh_account_guard_pwd --on-variable PWD
  command -v gh >/dev/null; or return
  # Set git config per-repo automatically (safe - each repo has its own config)
  gh account-guard auto-enforce >/dev/null 2>&1; or true
end
# Run on shell startup (when opening terminal in editor)
__gh_account_guard_pwd

# Alias for convenience
alias ag='gh account-guard'
# --- end gh-account-guard hook ---
FISH
      ;;
    zsh)
      cat <<'ZSH'
# --- gh-account-guard shell hook ---
# This automatically enforces the correct git identity when you change directories.
# Git commits/pushes use git config (per-repo), so this enables automatic commits
# without manual credential switching. Works even when multiple editors are open.
function __gh_account_guard_chpwd() {
  command -v gh >/dev/null || return
  # Set git config per-repo automatically (safe - each repo has its own config)
  gh account-guard auto-enforce >/dev/null 2>&1 || true
}
autoload -U add-zsh-hook 2>/dev/null && add-zsh-hook chpwd __gh_account_guard_chpwd
# Also run on shell startup (when opening terminal in editor)
__gh_account_guard_chpwd

# Alias for convenience
alias ag='gh account-guard'
# --- end gh-account-guard hook ---
ZSH
      ;;
    bash)
      cat <<'BASH'
# --- gh-account-guard shell hook ---
# This automatically enforces the correct git identity when you change directories.
# Git commits/pushes use git config (per-repo), so this enables automatic commits
# without manual credential switching. Works even when multiple editors are open.
function __gh_account_guard_chpwd() {
  command -v gh >/dev/null || return
  # Set git config per-repo automatically (safe - each repo has its own config)
  gh account-guard auto-enforce >/dev/null 2>&1 || true
}
PROMPT_COMMAND="__gh_account_guard_chpwd; $PROMPT_COMMAND"

# Alias for convenience
alias ag='gh account-guard'
# --- end gh-account-guard hook ---
BASH
      ;;
    *)
      # Unknown shell - show all options
      echo "Unable to detect your shell. Please specify one:" >&2
      echo "" >&2
      echo "For fish:" >&2
      echo "  gh account-guard install-shell-hook --fish >> ~/.config/fish/config.fish" >&2
      echo "" >&2
      echo "For zsh:" >&2
      echo "  gh account-guard install-shell-hook --zsh >> ~/.zshrc" >&2
      echo "" >&2
      echo "For bash:" >&2
      echo "  gh account-guard install-shell-hook --bash >> ~/.bashrc" >&2
      exit 1
      ;;
  esac
}
