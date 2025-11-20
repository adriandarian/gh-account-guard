# Command Reference

Complete reference for all `gh-account-guard` commands, options, and usage examples.

## Table of Contents

- [Setup & Configuration](#setup--configuration)
- [Profile Management](#profile-management)
- [Identity Management](#identity-management)
- [Hook Installation](#hook-installation)
- [Utility Commands](#utility-commands)

## Setup & Configuration

### `setup`

Interactive setup wizard to configure profiles.

**Usage:**
```bash
gh account-guard setup
```

**Description:**
- Guides you through creating your first profile or adding new profiles
- Prompts for all necessary information:
  - Profile name
  - Repository paths
  - GitHub username
  - Git name and email
  - Commit signing configuration (optional)
- If config already exists, offers to:
  - Add a new profile (keeps existing)
  - Start fresh (overwrites existing)
  - Cancel

**Examples:**
```bash
# First-time setup
gh account-guard setup

# Add another profile to existing config
gh account-guard setup
# Select "Add a new profile" when prompted
```

**Options:**
- None (fully interactive)

---

### `init`

Create an example config template file.

**Usage:**
```bash
gh account-guard init
```

**Description:**
- Creates a template config file at `~/.config/gh/account-guard.yml`
- Includes example profiles with placeholders
- Safe to run multiple times (won't overwrite existing config)

**Examples:**
```bash
# Create template config
gh account-guard init

# Then edit manually
vim ~/.config/gh/account-guard.yml
```

**Options:**
- None

---

### `config`

Manage extension settings.

**Usage:**
```bash
gh account-guard config                    # Show all settings
gh account-guard config get <key>          # Get a setting value
gh account-guard config set <key> <value>   # Set a setting value
```

**Subcommands:**

#### `config` (no subcommand)
Show all current settings in a formatted display.

**Examples:**
```bash
gh account-guard config
```

#### `config get <key>`
Get the value of a specific setting.

**Available keys:**
- `default_directory` - Default directory for file browser

**Examples:**
```bash
gh account-guard config get default_directory
# Output: /Users/you/work
```

#### `config set <key> <value>`
Set a configuration value.

**Available keys:**
- `default_directory` - Default directory for file browser (must exist)

**Examples:**
```bash
gh account-guard config set default_directory ~/work
gh account-guard config set default_directory /Users/you/work
```

**Options:**
- None

---

## Profile Management

### `edit`

Interactive editor to modify existing profile configurations.

**Usage:**
```bash
gh account-guard edit
```

**Description:**
- Lists all configured profiles
- Allows you to select a profile to edit
- Prompts for new values (press Enter to keep existing)
- Updates the config file

**Examples:**
```bash
# Edit an existing profile
gh account-guard edit
# Select profile from menu, then update fields
```

**Options:**
- None (fully interactive)

---

### `status`

Show which profile matches the current directory and current gh/git identity.

**Usage:**
```bash
gh account-guard status
```

**Description:**
- Displays:
  - Matched profile name
  - Expected GitHub username
  - Current GitHub CLI auth status
  - Current git identity (name, email, signing)
  - Comparison indicators (✓ or ⚠️) for each field

**Examples:**
```bash
cd ~/work/company/my-repo
gh account-guard status

# Output:
# Matched profile: work
# Expected gh user: work-username
# 
# Current gh auth:
# github.com
#   ✓ Logged in as work-username
# 
# Current git identity:
#   ✓ user.name  = Your Name
#   ✓ user.email = you@company.com
#   ✓ gpgsign    = true
```

**Options:**
- None

---

## Identity Management

### `fix`

Apply matching profile to current repository (git config, signing).

**Usage:**
```bash
gh account-guard fix
```

**Description:**
- Finds the matching profile for current directory
- Sets local git config:
  - `user.name`
  - `user.email`
  - `user.signingkey` (if configured)
  - `commit.gpgsign`
  - `gpg.format`
- Validates remote URL if `remote_match` is configured
- Configures git remote URL with username for authentication
- Warns if GitHub CLI auth doesn't match profile

**Examples:**
```bash
cd ~/work/company/my-repo
gh account-guard fix

# Output:
# ✅ Set repo identity to: Your Name <you@company.com>; signing=true
# ⚠️  Note: gh auth is 'personal-username' but profile expects 'work-username'
#    For git push to work, run: gh account-guard switch
```

**Options:**
- None

**Note:** This only sets git config (per-repository). To switch GitHub CLI account, use `switch`.

---

### `switch`

Switch GitHub CLI account to the matching profile.

**Usage:**
```bash
gh account-guard switch
```

**Description:**
- Finds matching profile for current directory
- Runs `gh auth switch -u <gh_username>`
- Switches the active GitHub CLI account globally

**Examples:**
```bash
cd ~/work/company/my-repo
gh account-guard switch

# Output:
# Switched active account on github.com to work-username
```

**Options:**
- None

**Important:** This affects all terminals/editors globally. Use with caution when working on multiple projects simultaneously.

---

### `auto-enforce`

Silently enforce profile settings (used by shell hooks).

**Usage:**
```bash
gh account-guard auto-enforce
```

**Description:**
- Automatically called by shell hooks
- Silently applies git identity if profile matches
- Only sets git config (per-repo), does NOT switch gh auth
- Fails silently if no profile matches or not in git repo
- Designed to run on every directory change

**Examples:**
```bash
# Usually called automatically by shell hook
# Can also be called manually
gh account-guard auto-enforce
```

**Options:**
- None

**Note:** This command produces no output unless there's an error. It's designed for use in shell hooks.

---

## Hook Installation

### `install`

Install shell hook and git pre-commit hook (recommended).

**Usage:**
```bash
gh account-guard install [options]
```

**Description:**
- Installs both shell hook and git pre-commit hook
- Shell hook: Auto-enforces identity on directory change
- Git hook: Validates identity before commits

**Options:**

| Option | Description |
|--------|-------------|
| `--fish`, `-f` | Install shell hook for fish shell |
| `--zsh`, `-z` | Install shell hook for zsh shell |
| `--bash`, `-b` | Install shell hook for bash shell |
| `--no-shell-hook` | Skip shell hook installation |
| `--no-git-hook` | Skip git hook installation |

**Examples:**
```bash
# Install both hooks (auto-detects shell)
gh account-guard install

# Install for specific shell
gh account-guard install --fish

# Install only shell hook
gh account-guard install --no-git-hook

# Install only git hook
gh account-guard install --no-shell-hook
```

**What it does:**
1. Detects your shell (or uses specified option)
2. Appends shell hook to your shell config file
3. Installs git pre-commit hook in current repository
4. Provides instructions for reloading shell

---

### `install-shell-hook`

Print shell hook snippet for auto-enforcement on directory change.

**Usage:**
```bash
gh account-guard install-shell-hook [--fish|--zsh|--bash]
```

**Description:**
- Outputs shell hook code to stdout
- You need to append it to your shell config file
- Auto-detects shell if not specified

**Options:**

| Option | Description |
|--------|-------------|
| `--fish`, `-f` | Generate hook for fish shell |
| `--zsh`, `-z` | Generate hook for zsh shell |
| `--bash`, `-b` | Generate hook for bash shell |

**Examples:**
```bash
# Auto-detect shell
gh account-guard install-shell-hook >> ~/.zshrc

# Specify shell explicitly
gh account-guard install-shell-hook --fish >> ~/.config/fish/config.fish
gh account-guard install-shell-hook --zsh >> ~/.zshrc
gh account-guard install-shell-hook --bash >> ~/.bashrc

# Then reload shell
source ~/.zshrc  # or ~/.bashrc or ~/.config/fish/config.fish
```

**What the hook does:**
- Automatically runs `gh account-guard auto-enforce` when you `cd` into a directory
- Only runs in git repositories
- Fails silently if no profile matches
- Also creates `ag` alias for `gh account-guard`

---

### `install-git-hook`

Install a pre-commit hook to validate git identity.

**Usage:**
```bash
gh account-guard install-git-hook [--global|-g]
```

**Description:**
- Installs pre-commit hook in current repository
- Hook validates git identity matches profile before commit
- Blocks commits if identity doesn't match (after auto-correction)

**Options:**

| Option | Description |
|--------|-------------|
| `--global`, `-g` | Install globally via git template directory |

**Examples:**
```bash
# Install in current repository
cd ~/work/company/my-repo
gh account-guard install-git-hook

# Install globally (for all new repos)
gh account-guard install-git-hook --global
```

**What the hook does:**
1. Runs `gh account-guard auto-enforce` before commit
2. Validates git identity matches expected profile
3. Blocks commit if identity doesn't match (with helpful error)
4. Allows commit if identity matches or no profile matches

**Note:** After installing globally, use `apply-hook-to-repos` to apply to existing repos.

---

### `apply-hook-to-repos`

Apply git hook to all existing repositories in configured paths.

**Usage:**
```bash
gh account-guard apply-hook-to-repos
```

**Description:**
- Scans all profile paths in config
- Finds all git repositories in those paths
- Applies pre-commit hook from global template to each repo
- Requires global hook to be installed first

**Examples:**
```bash
# First install global hook
gh account-guard install-git-hook --global

# Then apply to all existing repos
gh account-guard apply-hook-to-repos

# Output:
# Applying hook to existing repos...
#   Scanning work profile paths... ✓ Found 5 repos
#   Scanning personal profile paths... ✓ Found 3 repos
# ✅ Applied hook to 8 existing repos
```

**Options:**
- None

**Prerequisites:**
- Global git hook must be installed: `gh account-guard install-git-hook --global`
- Config file must exist: `gh account-guard setup`

---

## Utility Commands

### `create-alias`

Create `gh ag` alias for `gh account-guard`.

**Usage:**
```bash
gh account-guard create-alias
```

**Description:**
- Creates a shell alias `ag` for `gh account-guard`
- Adds alias to your shell config file
- Detects shell automatically

**Examples:**
```bash
gh account-guard create-alias

# Then you can use:
gh ag status
gh ag fix
gh ag switch
```

**Options:**
- None

**Note:** The shell hook also creates this alias automatically.

---

## Command Summary

| Command | Purpose | Options |
|---------|---------|---------|
| `setup` | Interactive profile setup | None |
| `edit` | Edit existing profiles | None |
| `init` | Create config template | None |
| `config` | Manage settings | `get`, `set` subcommands |
| `status` | Show current profile match | None |
| `fix` | Apply profile to repo | None |
| `switch` | Switch GitHub account | None |
| `auto-enforce` | Silent enforcement (hooks) | None |
| `install` | Install hooks | `--fish`, `--zsh`, `--bash`, `--no-shell-hook`, `--no-git-hook` |
| `install-shell-hook` | Print shell hook | `--fish`, `--zsh`, `--bash` |
| `install-git-hook` | Install git hook | `--global`, `-g` |
| `apply-hook-to-repos` | Apply hook to repos | None |
| `create-alias` | Create `ag` alias | None |

## Common Workflows

### Initial Setup

```bash
# 1. Install extension
gh extension install <username>/gh-account-guard

# 2. Run setup
gh account-guard setup

# 3. Install hooks (recommended)
gh account-guard install

# 4. Reload shell
source ~/.zshrc  # or your shell config
```

### Daily Usage

```bash
# Check current status
gh account-guard status

# Apply profile to current repo
gh account-guard fix

# Switch GitHub account (if needed)
gh account-guard switch
```

### Adding New Profile

```bash
# Option 1: Interactive setup
gh account-guard setup
# Select "Add a new profile"

# Option 2: Edit config manually
gh account-guard edit
```

### Working with Multiple Projects

```bash
# Project 1 (work)
cd ~/work/company/project1
gh account-guard fix    # Sets git identity
gh account-guard switch # Switches gh auth (global!)

# Project 2 (personal) - in another terminal
cd ~/personal/project2
gh account-guard fix    # Sets git identity (per-repo, safe)
# Note: gh auth is global, so be careful with switch
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `XDG_CONFIG_HOME` | Config directory | `~/.config` |
| `CONFIG` | Config file path | `$XDG_CONFIG_HOME/gh/account-guard.yml` |

## Exit Codes

- `0` - Success
- `1` - Error (invalid command, missing config, etc.)
- `130` - Cancelled by user (Ctrl+C)

## Related Documentation

- [Quick Start Guide](QUICKSTART.md) - Getting started
- [Architecture](ARCHITECTURE.md) - How it works
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
- [Main README](../README.md) - Overview and features

