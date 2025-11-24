# Troubleshooting Guide

Common issues and solutions for `gh-account-guard`.

## Installation Issues

### Extension Not Found

**Problem:** `gh account-guard` command not found after installation.

**Solutions:**
1. Verify installation:
   ```bash
   gh extension list
   ```

2. Reinstall the extension:
   ```bash
   gh extension remove account-guard
   gh extension install <your-username>/gh-account-guard
   ```

3. Check GitHub CLI version:
   ```bash
   gh --version  # Should be 2.0.0 or later
   ```

## Configuration Issues

### Profile Not Matching

**Problem:** `gh account-guard status` shows "No matching profile" or wrong profile.

**Solutions:**
1. Check your current directory:
   ```bash
   pwd
   ```

2. Verify path in config matches:
   ```bash
   cat ~/.config/gh/account-guard.yml
   ```

3. Remember: longest matching path wins
   - `~/work/company/` matches before `~/work/`
   - Paths are prefix-matched (directory must start with path)

4. Check `~` expansion:
   ```bash
   # In config, ~/work/company/ expands to /Users/you/work/company/
   # Make sure the full path matches
   ```

### Config File Not Found

**Problem:** Error about missing config file.

**Solutions:**
1. Create config using setup:
   ```bash
   gh account-guard setup
   ```

2. Or create manually:
   ```bash
   gh account-guard init
   ```

3. Check config location:
   ```bash
   echo ~/.config/gh/account-guard.yml
   # Or if XDG_CONFIG_HOME is set:
   echo $XDG_CONFIG_HOME/gh/account-guard.yml
   ```

### Invalid YAML Syntax

**Problem:** Error parsing config file.

**Solutions:**
1. Check for common YAML issues:
   - Missing colons after keys
   - Incorrect indentation (use spaces, not tabs)
   - Unquoted strings with special characters
   - Missing quotes around email addresses

3. Use `gh account-guard edit` to fix via interactive editor

## Git Identity Issues

### Wrong Email/Name in Commits

**Problem:** Commits show wrong author information.

**Solutions:**
1. Apply profile manually:
   ```bash
   gh account-guard fix
   ```

2. Verify git config:
   ```bash
   git config --local user.name
   git config --local user.email
   ```

3. Check profile configuration:
   ```bash
   gh account-guard status
   ```

4. Remember: local config overrides global
   ```bash
   # Check what's actually set
   git config --list --local
   ```

### Commit Signing Not Working

**Problem:** Commits not being signed or wrong key used.

**Solutions:**
1. Verify signing key format:
   ```yaml
   git:
     signingkey: "ssh-ed25519 AAAA..."  # Full key, not just fingerprint
     gpgsign: true
     gpgformat: ssh  # or "gpg"
   ```

2. Check key exists:
   ```bash
   # For SSH keys
   ssh-add -l
   
   # For GPG keys
   gpg --list-secret-keys
   ```

3. Test signing manually:
   ```bash
   git config --local commit.gpgsign true
   git commit --allow-empty -m "test"
   ```

4. Verify signing key matches:
   ```bash
   git config --local user.signingkey
   ```

## GitHub CLI Issues

### Account Not Switching

**Problem:** `gh account-guard switch` doesn't change GitHub account.

**Solutions:**
1. Verify account is logged in:
   ```bash
   gh auth status
   ```

2. Check `gh_username` in config:
   ```bash
   cat ~/.config/gh/account-guard.yml | grep gh_username
   ```

3. Ensure username matches logged-in account:
   ```bash
   gh auth status | grep "Logged in"
   ```

4. Switch manually to test:
   ```bash
   gh auth switch -u <username>
   ```

### Multiple Accounts Not Configured

**Problem:** Only one GitHub account available.

**Solutions:**
1. Login with additional accounts:
   ```bash
   gh auth login -u work-username
   gh auth login -u personal-username
   ```

2. Verify all accounts:
   ```bash
   gh auth status
   ```

3. Use different hosts if needed:
   ```bash
   gh auth login --hostname github.enterprise.com
   ```

## Shell Hook Issues

### Hook Not Running

**Problem:** Profile not applied automatically on `cd`.

**Solutions:**
1. Verify hook is installed:
   ```bash
   # Check your shell config file
   grep "gh-account-guard" ~/.zshrc  # or ~/.bashrc or ~/.config/fish/config.fish
   ```

2. Reinstall hook:
   ```bash
   gh account-guard install-shell-hook >> ~/.zshrc
   source ~/.zshrc
   ```

3. Check hook output (temporarily remove `>/dev/null`):
   ```bash
   # Edit your shell config and remove redirects to see errors
   ```

4. Verify you're in a git repo:
   ```bash
   git rev-parse --is-inside-work-tree
   ```

### Hook Too Slow

**Problem:** Shell prompt is slow after installing hook.

**Solutions:**
1. Hook runs on every `cd` - this is expected
2. It should be fast (< 100ms) if profile matches
3. If slow, check:
   - Network connectivity (for `gh auth switch`)
   - Number of profiles (more profiles = slower matching)

4. Consider running manually instead:
   ```bash
   # Remove hook and use:
   gh account-guard fix && gh account-guard switch
   ```

## Remote Validation Issues

### Remote Match Warning

**Problem:** Warning about remote URL not matching `remote_match`.

**Solutions:**
1. This is just a warning - not an error
2. Check actual remote URL:
   ```bash
   git remote get-url origin
   ```

3. Update `remote_match` in config if needed:
   ```yaml
   remote_match: "github.com/YourOrg/"  # Should match remote URL
   ```

4. Or remove `remote_match` to disable validation

## Performance Issues

### Slow Profile Matching

**Problem:** Commands take too long to execute.

**Solutions:**
1. Reduce number of profiles (if possible)
2. Profile matching uses pure bash YAML parsing (no external dependencies)
3. Consider caching (future feature)

## Platform-Specific Issues

### Windows Path Issues

**Problem:** Paths not matching on Windows.

**Solutions:**
1. Use Windows-style paths in config:
   ```yaml
   path: "C:/Users/you/work/company/"
   ```

2. Or use forward slashes:
   ```yaml
   path: "C:/Users/you/work/company/"
   ```

3. Avoid `~` expansion on Windows (use full paths)

### macOS Permission Issues

**Problem:** Can't write to config directory.

**Solutions:**
1. Check directory permissions:
   ```bash
   ls -la ~/.config/gh/
   ```

2. Create directory if needed:
   ```bash
   mkdir -p ~/.config/gh/
   ```

3. Check write permissions:
   ```bash
   touch ~/.config/gh/test && rm ~/.config/gh/test
   ```

## Getting More Help

If you're still experiencing issues:

1. **Check logs:**
   - Run commands with verbose output
   - Check shell hook output (remove redirects)

2. **Verify setup:**
   ```bash
   gh account-guard status
   gh auth status
   git config --list --local
   ```

3. **Open an issue:**
   - Include error messages
   - Share relevant config (sanitized)
   - Describe steps to reproduce

4. **Review documentation:**
   - [Quick Start](QUICKSTART.md)
   - [Architecture](ARCHITECTURE.md)
   - [Main README](../README.md)

## Common Error Messages

### "No matching profile for /path/to/repo"

- Check that a profile path matches your current directory
- Verify path format in config file
- Remember: longest match wins

### "Not a git repo"

- Ensure you're in a git repository
- Run `git init` if starting a new repo

### "No gh_username configured for this profile"

- Add `gh_username` to your profile in config
- Or use `gh account-guard edit` to add it interactively

