# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Interactive `setup` command for guided configuration
- Generic template in `init` command (no hardcoded credentials)
- Safe to publish - no user-specific data in the codebase
- `edit` command for modifying existing profile configurations
- `config` command for managing extension settings
- `install` command for installing shell and git hooks
- `create-alias` command for creating 'gh ag' alias
- Support for GitHub Enterprise via `remote_match` configuration
- Optional UI enhancements with `gum`, `fzf`, and `bat`

### Changed
- `init` command now creates a generic template with placeholders
- `status` command now suggests `setup` instead of `init`

### Security
- Removed all hardcoded credentials from the extension
- Users configure their own profiles via interactive setup

