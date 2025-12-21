# gh-account-guard

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=flat&logo=linkedin&logoColor=white)](https://www.linkedin.com/feed/update/urn:li:ugcPost:7408420954785210368/)
[![Dev.to](https://img.shields.io/badge/Dev.to-0A0A0A?style=flat&logo=devdotto&logoColor=white)](https://dev.to/adriandarian/how-i-stopped-mixing-personal-and-work-github-accounts-4c2j)
[![Medium](https://img.shields.io/badge/Medium-000000?style=flat&logo=medium&logoColor=white)](https://medium.com/@adrian.the.hactus/how-i-stopped-mixing-personal-and-work-github-accounts-079c82e2acca)
[![X](https://img.shields.io/badge/X-000000?style=flat&logo=x&logoColor=white)](https://x.com/AdrianTheHactus/status/2002655602682835106)

[![CI](https://github.com/adriandarian/gh-account-guard/actions/workflows/ci.yml/badge.svg)](https://github.com/adriandarian/gh-account-guard/actions/workflows/ci.yml)
[![CodeQL](https://github.com/adriandarian/gh-account-guard/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/adriandarian/gh-account-guard/actions/workflows/github-code-scanning/codeql)
[![Version](https://img.shields.io/github/v/release/adriandarian/gh-account-guard)](https://github.com/adriandarian/gh-account-guard/releases/latest)

A GitHub CLI extension that automatically switches your GitHub CLI account and enforces the correct Git identity (name, email, signing) based on the repository path.

## Problem

When working with multiple GitHub accounts (e.g., personal and company), it's easy to:
- Commit with the wrong email/name
- Use the wrong GitHub CLI account for `gh pr`, `gh issue`, etc.
- Accidentally push to the wrong account

This extension solves these issues by automatically matching repositories to profiles based on their path.

## Features

- 🎯 **Auto-switch GitHub CLI account** when you enter a repo
- 🔒 **Enforce correct Git identity** (name, email, signing) per repository
- 📁 **Path-based profile matching** (longest match wins)
- 🛡️ **Optional shell hooks** for automatic enforcement on directory change
- ⚙️ **Simple YAML configuration**
- 🎨 **Beautiful interactive setup** with optional UI enhancements

## Installation

```bash
gh extension install <your-username>/gh-account-guard
```

Or install locally for development:

```bash
gh extension install .
```

## Prerequisites

**Zero external dependencies!** This extension uses pure bash for all operations. Only requires:

- **GitHub CLI** (`gh`) - Already required for GitHub CLI extensions
- **Git** - Standard on most development machines

### Optional UI Enhancements

For a more beautiful and interactive experience, install these optional tools:

- **[gum](https://github.com/charmbracelet/gum)** - Beautiful CLI prompts and interactive menus (highly recommended!)
  - macOS: `brew install gum`
  - Makes prompts, selects, and confirmations much prettier
  - The extension automatically detects and uses `gum` if available

- **[fzf](https://github.com/junegunn/fzf)** - Fuzzy finder for interactive selection (highly recommended for menus!)
  - macOS: `brew install fzf`
  - Provides beautiful arrow-key navigation menus
  - Arrow keys: navigate, Enter: select, Esc: cancel
  - Used for interactive menu selection in `setup` command

- **[bat](https://github.com/sharkdp/bat)** - Syntax highlighting for config files
  - macOS: `brew install bat`
  - Makes config files easier to read

**Note:** All UI enhancements are optional. The extension works perfectly fine without them, but they make the experience much nicer!

**Zero Dependencies:** This extension uses pure bash YAML parsing and requires no external tools beyond `git` and `gh` (which are needed for the tool's core functionality).

## Quick Start

1. **Run the interactive setup:**
   ```bash
   gh account-guard setup
   ```
   
   This will guide you through configuring your profiles interactively. You can:
   - Add multiple profiles (work, personal, clients, etc.)
   - Name profiles whatever you want
   - Add more profiles later without overwriting existing ones
   - Configure GitHub Enterprise patterns

   **If config exists**, you'll be asked to:
   - Add a new profile (keeps existing ones)
   - Start fresh (overwrites existing config)
   - Cancel

   Alternatively, create a template config manually:
   ```bash
   gh account-guard init
   ```
   Then edit `~/.config/gh/account-guard.yml` with your actual:
   - Repository paths
   - GitHub usernames
   - Git names and emails
   - Signing keys (if using commit signing)

2. **Test it:**
   ```bash
   cd ~/work/company/some-repo
   gh account-guard status  # Check which profile matches
   gh account-guard fix     # Apply the profile to this repo
   gh account-guard switch  # Switch gh CLI account
   ```

3. **(Optional) Install shell hook** for automatic enforcement:
   ```bash
   # For zsh
   gh account-guard install-shell-hook >> ~/.zshrc
   
   # For bash
   gh account-guard install-shell-hook >> ~/.bashrc
   
   # For fish
   gh account-guard install-shell-hook >> ~/.config/fish/config.fish
   ```

   This will automatically run `fix` and `switch` when you `cd` into a git repository.

## Commands

- `gh account-guard setup` - Interactive setup wizard to configure profiles (recommended)
- `gh account-guard edit` - Interactive editor to modify existing profile configurations
- `gh account-guard init` - Create example config template file
- `gh account-guard config` - Manage extension settings (default directory, etc.)
- `gh account-guard status` - Show which profile matches current directory and current gh/git identity
- `gh account-guard fix` - Apply matching profile to current repo (git config, signing)
- `gh account-guard switch` - Run `gh auth switch` to the matching profile
- `gh account-guard install` - Install shell hook and git pre-commit hook (recommended)
- `gh account-guard install-shell-hook` - Print shell hook snippet for auto-enforcement
- `gh account-guard install-git-hook` - Install a pre-commit hook (use `--global` for all repos)
- `gh account-guard create-alias` - Create 'gh ag' alias for 'gh account-guard'

## Configuration

The config file is located at `~/.config/gh/account-guard.yml` (or `$XDG_CONFIG_HOME/gh/account-guard.yml`).

Example with multiple profiles:

```yaml
profiles:
  - name: work
    path: ~/work/company/            # any repo under here
    gh_username: yourcompany-username
    git:
      name: "Your Name"
      email: "you@company.com"
      signingkey: "ssh-ed25519 AAAA...company"
      gpgsign: true
      gpgformat: ssh
    remote_match: "github.enterprise.com"  # GitHub Enterprise - matches all orgs
  - name: personal
    path: ~/personal/
    gh_username: yourpersonal-username
    git:
      name: "Your Name (Personal)"
      email: "you+personal@example.com"
      signingkey: "ssh-ed25519 AAAA...personal"
      gpgsign: true
      gpgformat: ssh
  - name: client1
    path: ~/clients/client1/
    gh_username: client1-username
    git:
      name: "Your Name"
      email: "you@client1.com"
      signingkey: ""
      gpgsign: false
      gpgformat: ssh
    remote_match: "github.com/Client1Org/"
```

You can have as many profiles as you need. Profile names are arbitrary - use whatever makes sense for your setup.

### Profile Matching

Profiles are matched by path prefix. The **longest matching path wins**. For example:
- `~/work/company/project/` matches the `work` profile
- `~/personal/project/` matches the `personal` profile
- `~/clients/client1/project/` matches the `client1` profile
- If no specific path matches, the profile with path `~/` (if any) acts as a fallback

### Configuration Fields

- `name`: Profile name (for display)
- `path`: Path prefix to match (supports `~` expansion)
- `gh_username`: GitHub username for `gh auth switch`
- `git.name`: Git `user.name`
- `git.email`: Git `user.email`
- `git.signingkey`: SSH or GPG signing key (optional)
- `git.gpgsign`: Enable commit signing (true/false)
- `git.gpgformat`: Signing format (`ssh` or `gpg`)
- `remote_match`: Optional remote URL pattern to validate (warns if mismatch)
  
  **What is `remote_match`?** This is an optional safety check. If set, the extension will warn you if a repo's remote URL doesn't match the pattern. Examples:
  - **GitHub Enterprise**: `github.enterprise.com` (matches entire enterprise, all orgs)
  - **Specific org**: `github.com/YourOrg/` (matches repos under that org)
  - **User account**: `github.com/username/` (matches repos under that user)
  - If you see a warning, it means the repo's remote doesn't match what you'd expect for that profile
  - Leave empty to skip remote validation

## How It Works

1. When you run `gh account-guard fix`, it:
   - Finds the matching profile for the current directory
   - Sets local git config (`user.name`, `user.email`, signing settings)
   - Validates remote URL if `remote_match` is configured

2. When you run `gh account-guard switch`, it:
   - Finds the matching profile
   - Runs `gh auth switch -u <gh_username>`

3. With the shell hook installed:
   - Automatically runs `fix` and `switch` when you `cd` into a git repository
   - Silently fails if no profile matches (won't interrupt your workflow)

## Notes

- **Git is the source of truth** for commit author/compliance. The extension sets repo-local `user.*` config so commits are correct even outside `gh`.
- **Multiple GitHub accounts**: Make sure both accounts are logged in: `gh auth login -u yourcompany-username` and `gh auth login -u yourpersonal-username`
- **Windows**: Update `path:` globs to Windows paths (e.g., `C:/Users/you/work/company/`)
- **Signing**: Supports both SSH and GPG signing. Configure `gpgformat` accordingly.

## Contributing

Contributions are welcome! Please see:
- [Contributing Guide](CONTRIBUTING.md) - How to contribute and commit message format
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)

## License

MIT

## Documentation

- [Command Reference](docs/USAGE.md) - Complete command reference with all options
- [Quick Start](docs/QUICKSTART.md) - Getting started guide
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Architecture](docs/ARCHITECTURE.md) - How it works (for developers)
- [Changelog](CHANGELOG.md) - Version history and changes
- [Release Process](docs/RELEASES.md) - How releases work

