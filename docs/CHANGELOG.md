# Changelog

## [Unreleased]

### Added
- Interactive `setup` command for guided configuration
- Generic template in `init` command (no hardcoded credentials)
- Safe to publish - no user-specific data in the codebase

### Changed
- `init` command now creates a generic template with placeholders
- `status` command now suggests `setup` instead of `init`

### Security
- Removed all hardcoded credentials from the extension
- Users configure their own profiles via interactive setup

