# Quick Start Guide

Get up and running with `gh-account-guard` in minutes!

## Prerequisites

Before you begin, ensure you have:

1. **GitHub CLI** installed and configured
   ```bash
   gh --version
   ```

2. **yq** installed (required dependency)
   ```bash
   # macOS
   brew install yq
   
   # Linux (Ubuntu/Debian)
   sudo apt-get install yq
   
   # Or download from: https://github.com/mikefarah/yq#install
   ```

3. **Multiple GitHub accounts** logged in (if applicable)
   ```bash
   gh auth login -u your-work-username
   gh auth login -u your-personal-username
   ```

## Installation

### Install from GitHub

```bash
gh extension install <your-username>/gh-account-guard
```

### Install Locally (Development)

```bash
git clone https://github.com/<your-username>/gh-account-guard.git
cd gh-account-guard
gh extension install .
```

## Initial Setup

### Step 1: Run Interactive Setup

The easiest way to get started is with the interactive setup wizard:

```bash
gh account-guard setup
```

This will guide you through:
- Creating your first profile (work, personal, etc.)
- Setting repository paths
- Configuring GitHub usernames
- Setting Git identity (name, email)
- Optional: Commit signing configuration

### Step 2: Add Additional Profiles

You can add more profiles anytime:

```bash
gh account-guard setup
# Choose "Add a new profile" when prompted
```

Or edit existing profiles:

```bash
gh account-guard edit
```

## Basic Usage

### Check Current Status

See which profile matches your current directory:

```bash
cd ~/work/company/my-repo
gh account-guard status
```

### Apply Profile to Repository

Set the correct Git identity for the current repository:

```bash
gh account-guard fix
```

### Switch GitHub CLI Account

Switch to the matching GitHub account:

```bash
gh account-guard switch
```

## Automatic Enforcement (Recommended)

### Install Shell Hook

Automatically apply profiles when you change directories:

```bash
# For zsh
gh account-guard install-shell-hook >> ~/.zshrc

# For bash
gh account-guard install-shell-hook >> ~/.bashrc

# For fish
gh account-guard install-shell-hook >> ~/.config/fish/config.fish
```

After installation, restart your shell or run:

```bash
source ~/.zshrc  # or ~/.bashrc or ~/.config/fish/config.fish
```

### Install Git Hooks (Optional)

Add pre-commit hooks to enforce identity:

```bash
# For current repository
gh account-guard install-git-hook

# For all repositories globally
gh account-guard install-git-hook --global
```

## Example Workflow

### Scenario: Working with Work and Personal Repos

1. **Setup profiles:**
   ```bash
   gh account-guard setup
   # Add "work" profile for ~/work/company/
   # Add "personal" profile for ~/personal/
   ```

2. **Work on company repo:**
   ```bash
   cd ~/work/company/my-project
   # Shell hook automatically applies work profile
   git commit -m "feat: add new feature"
   # Commit uses work email automatically
   ```

3. **Switch to personal repo:**
   ```bash
   cd ~/personal/my-project
   # Shell hook automatically applies personal profile
   gh pr create
   # Uses personal GitHub account automatically
   ```

## Configuration File

Your configuration is stored at:

```
~/.config/gh/account-guard.yml
```

Example configuration:

```yaml
profiles:
  - name: work
    path: ~/work/company/
    gh_username: work-username
    git:
      name: "Your Name"
      email: "you@company.com"
      signingkey: "ssh-ed25519 AAAA..."
      gpgsign: true
      gpgformat: ssh
    remote_match: "github.com/CompanyOrg/"
  - name: personal
    path: ~/personal/
    gh_username: personal-username
    git:
      name: "Your Name"
      email: "you@example.com"
      signingkey: "ssh-ed25519 AAAA..."
      gpgsign: true
      gpgformat: ssh
```

## Common Commands

| Command | Description |
|---------|-------------|
| `gh account-guard setup` | Interactive setup wizard |
| `gh account-guard status` | Show current profile match |
| `gh account-guard fix` | Apply profile to current repo |
| `gh account-guard switch` | Switch GitHub CLI account |
| `gh account-guard edit` | Edit existing profiles |
| `gh account-guard install` | Install shell and git hooks |

## Troubleshooting

### Profile not matching

- Check that your current directory matches a configured path
- Verify paths in config file use `~` expansion correctly
- Run `gh account-guard status` to see which profile matches

### GitHub account not switching

- Ensure both accounts are logged in: `gh auth status`
- Verify `gh_username` in config matches logged-in accounts
- Check that you're in a directory that matches a profile path

### Git identity not applying

- Run `gh account-guard fix` manually
- Check that you're in a git repository
- Verify profile configuration is correct

## Next Steps

- Read the [full documentation](../README.md) for advanced features
- Check [troubleshooting guide](TROUBLESHOOTING.md) for common issues
- Review [architecture docs](ARCHITECTURE.md) for developers

## Getting Help

- Open an [issue](https://github.com/<your-username>/gh-account-guard/issues) for bugs
- Check existing [discussions](https://github.com/<your-username>/gh-account-guard/discussions)
- Review the [changelog](CHANGELOG.md) for recent changes

