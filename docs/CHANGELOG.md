# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-11-23

### Added
- **Initial release** of gh-account-guard extension
- Interactive `setup` command for guided configuration
- Generic template in `init` command (no hardcoded credentials)
- Safe to publish - no user-specific data in the codebase
- `edit` command for modifying existing profile configurations
- `config` command for managing extension settings
- `install` command for installing shell and git hooks
- `create-alias` command for creating 'gh ag' alias
- Support for GitHub Enterprise via `remote_match` configuration
- Optional UI enhancements with `gum`, `fzf`, and `bat`
- Path-based profile matching with longest match wins algorithm
- Automatic Git identity enforcement (name, email, signing)
- Shell hooks for automatic enforcement on directory change
- Git pre-commit hooks for identity validation
- Support for SSH and GPG commit signing
- Comprehensive test suite with bats
- CI/CD infrastructure with GitHub Actions
- Complete documentation including architecture, usage, and troubleshooting guides

### Changed
- `init` command now creates a generic template with placeholders
- `status` command now suggests `setup` instead of `init`

### Security
- Removed all hardcoded credentials from the extension
- Users configure their own profiles via interactive setup
- No sensitive data stored in the codebase

[1.0.0]: https://github.com/adriandarian/gh-account-guard/releases/tag/v1.0.0

