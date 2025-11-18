# Quick Start Guide

## 1. Install Prerequisites

```bash
brew install yq
```

## 2. Install the Extension

```bash
cd /Users/dariana/personal/gh-account-guard
gh extension install .
```

## 3. Run Interactive Setup

```bash
gh account-guard setup
```

This will guide you through configuring:
- **Company profile**: path, GitHub username, git name/email
- **Personal profile**: path, GitHub username, git name/email
- **Optional**: commit signing configuration

The wizard will prompt you for all necessary information and create the config file automatically.

## 5. Test It

```bash
# In a company repo
cd ~/work/company/some-repo
gh account-guard status   # Should show "company" profile
gh account-guard fix      # Apply company identity
gh account-guard switch   # Switch to company GitHub account

# In a personal repo
cd ~/personal/some-repo
gh account-guard status   # Should show "personal" profile
gh account-guard fix      # Apply personal identity
gh account-guard switch   # Switch to personal GitHub account
```

## 6. (Optional) Auto-enforce on Directory Change

For Fish shell (your current shell):
```bash
gh account-guard install-shell-hook >> ~/.config/fish/config.fish
```

This will automatically run `fix` and `switch` when you `cd` into a git repository.

## Current Setup Status

✅ Extension script created (`gh-account-guard`)
✅ Interactive setup command added (`gh account-guard setup`)
✅ No hardcoded credentials - safe to publish!
⚠️  `yq` needs to be installed: `brew install yq`

## Next Steps

1. Install `yq`: `brew install yq`
2. Run `gh account-guard setup` to configure your profiles
3. Test in a repo: `gh account-guard status`
4. (Optional) Add shell hook for auto-enforcement

