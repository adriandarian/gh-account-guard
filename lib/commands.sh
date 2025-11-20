#!/usr/bin/env bash
# Command loader for gh-account-guard
# Sources all individual command files

# Determine script directory for sourcing modules
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Source all command files
# shellcheck source=lib/commands/setup.sh
source "${SCRIPT_DIR}/commands/setup.sh"

# shellcheck source=lib/commands/init.sh
source "${SCRIPT_DIR}/commands/init.sh"

# shellcheck source=lib/commands/config.sh
source "${SCRIPT_DIR}/commands/config.sh"

# shellcheck source=lib/commands/status.sh
source "${SCRIPT_DIR}/commands/status.sh"

# shellcheck source=lib/commands/fix.sh
source "${SCRIPT_DIR}/commands/fix.sh"

# shellcheck source=lib/commands/switch.sh
source "${SCRIPT_DIR}/commands/switch.sh"

# shellcheck source=lib/commands/auto_enforce.sh
source "${SCRIPT_DIR}/commands/auto_enforce.sh"

# shellcheck source=lib/commands/install.sh
source "${SCRIPT_DIR}/commands/install.sh"

# shellcheck source=lib/commands/create_alias.sh
source "${SCRIPT_DIR}/commands/create_alias.sh"

# shellcheck source=lib/commands/install_shell_hook.sh
source "${SCRIPT_DIR}/commands/install_shell_hook.sh"

# shellcheck source=lib/commands/install_git_hook.sh
source "${SCRIPT_DIR}/commands/install_git_hook.sh"

# shellcheck source=lib/commands/install_git_hook_global.sh
source "${SCRIPT_DIR}/commands/install_git_hook_global.sh"

# shellcheck source=lib/commands/apply_hook_to_repos.sh
source "${SCRIPT_DIR}/commands/apply_hook_to_repos.sh"
