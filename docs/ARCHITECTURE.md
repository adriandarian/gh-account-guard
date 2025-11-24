# Architecture

This document describes the internal architecture and design decisions of `gh-account-guard`.

## Project Structure

```
gh-account-guard/
├── gh-account-guard          # Main entry point
├── install                   # Installation script
├── lib/
│   ├── commands/            # Individual command implementations
│   │   ├── setup.sh
│   │   ├── init.sh
│   │   ├── status.sh
│   │   ├── fix.sh
│   │   ├── switch.sh
│   │   └── ...
│   ├── helpers/             # Reusable helper modules
│   │   ├── yaml.sh          # YAML parsing utilities
│   │   ├── git.sh           # Git operations
│   │   ├── gh_auth.sh       # GitHub CLI auth operations
│   │   └── profile.sh       # Profile matching logic
│   ├── commands.sh          # Command loader
│   ├── config.sh            # Configuration management
│   ├── directory.sh         # Directory/file browser utilities
│   ├── ui.sh                # UI/UX functions (gum/fzf integration)
│   └── utils.sh             # General utilities
├── test/                    # Test suite (bats)
└── docs/                    # Documentation
```

## Core Components

### Entry Point (`gh-account-guard`)

The main script that:
- Sources all modules in dependency order
- Parses command-line arguments
- Routes to appropriate command handlers
- Provides usage information

### Command System (`lib/commands/`)

Each command is implemented as a separate file:
- `cmd_<command_name>()` function convention
- Commands are sourced by `lib/commands.sh`
- Commands can use helper functions from `lib/helpers/`

### Helper Modules (`lib/helpers/`)

Reusable functionality extracted into focused modules:

- **`yaml.sh`**: Pure bash YAML parsing (zero dependencies)
  - Reading values from config
  - Writing/updating config
  - YAML structure manipulation
  - No external tools required

- **`git.sh`**: Git operations
  - Setting git config
  - Reading git config
  - Git repository detection
  - Remote URL validation

- **`gh_auth.sh`**: GitHub CLI operations
  - Account switching
  - Auth status checking
  - Account validation

- **`profile.sh`**: Profile matching logic
  - Path-based matching
  - Longest match algorithm
  - Profile validation

### Configuration Management (`lib/config.sh`)

Handles:
- Config file location (`~/.config/gh/account-guard.yml`)
- Default directory settings
- Profile CRUD operations
- Config file validation

### UI Layer (`lib/ui.sh`)

Provides:
- Detection of optional tools (`gum`, `fzf`, `bat`)
- Fallback to basic prompts when tools unavailable
- Interactive menus and prompts
- Consistent user experience

### Directory Utilities (`lib/directory.sh`)

File browser functionality:
- Interactive directory selection
- Path validation
- File system operations

## Data Flow

### Profile Matching

```
Current Directory
    ↓
lib/helpers/profile.sh::match_profile()
    ↓
lib/helpers/yaml.sh::yaml_get() (reads config)
    ↓
Returns matching profile index
    ↓
Command uses profile data
```

### Configuration Updates

```
User Input (via setup/edit)
    ↓
lib/config.sh::add_profile() / update_profile()
    ↓
lib/helpers/yaml.sh::yaml_set() / yaml_add()
    ↓
Writes to ~/.config/gh/account-guard.yml
```

### Git Identity Application

```
gh account-guard fix
    ↓
lib/helpers/profile.sh::match_profile()
    ↓
lib/helpers/git.sh::apply_profile_to_repo()
    ↓
git config --local user.name/email/signingkey
```

## Design Principles

### 1. Modularity

- Each command is self-contained
- Helper functions are reusable
- Clear separation of concerns

### 2. Graceful Degradation

- Works without optional tools (`gum`, `fzf`, `bat`)
- Falls back to basic prompts
- No hard dependencies on optional tools

### 3. Path-Based Matching

- Longest matching path wins
- Supports `~` expansion
- Simple and predictable

### 4. Local Git Config

- Uses `git config --local` (repo-specific)
- Doesn't modify global git config
- Each repo maintains its own identity

### 5. Silent Failures

- Shell hooks fail silently if no profile matches
- Doesn't interrupt workflow
- Only warns on actual issues

## Configuration Format

The config file uses YAML:

```yaml
default_directory: "~/work"  # Optional: default for file browser
profiles:
  - name: work
    path: ~/work/company/     # Can be string or array
    gh_username: work-user
    git:
      name: "Name"
      email: "email@example.com"
      signingkey: "ssh-ed25519 ..."
      gpgsign: true
      gpgformat: ssh
    remote_match: "github.com/Org/"  # Optional validation
```

## Extension Points

### Adding New Commands

1. Create `lib/commands/new_command.sh`
2. Implement `cmd_new_command()` function
3. Add to `lib/commands.sh` loader
4. Add to `gh-account-guard` usage and routing

### Adding New Helpers

1. Create `lib/helpers/new_helper.sh`
2. Implement helper functions
3. Source in dependent modules
4. Document usage

### UI Enhancements

- Detect new tools in `lib/ui.sh`
- Add fallback logic
- Use in commands via UI functions

## Testing

Tests are located in `test/` and use [bats](https://github.com/bats-core/bats-core):

- `test_utils.sh` - Utility function tests
- `test_config.sh` - Configuration and profile matching tests
- `test_commands.sh` - Command implementation tests

Run tests with:
```bash
make test
# or
./test/run_tests.sh
```

## Dependencies

### Required

- **bash** - Shell interpreter (standard on Unix systems)
- **git** - Git operations (required for the tool's core functionality)
- **gh** - GitHub CLI (required for GitHub CLI extensions)

**Zero external dependencies!** All YAML parsing is done in pure bash.

### Optional

- **gum** - Enhanced UI prompts (has fallback to basic prompts)
- **fzf** - Interactive selection (has fallback to basic menu)
- **bat** - Syntax highlighting (has fallback to `cat`)

## Performance Considerations

- Profile matching is O(n) where n = number of profiles
- YAML parsing uses pure bash (no external processes)
- Git operations are minimal (config reads/writes)
- Shell hooks run asynchronously to avoid blocking

## Security Considerations

- No credentials stored in code
- Config file contains user-provided data only
- Git config is local to repositories
- GitHub auth handled by `gh` CLI

## Future Improvements

Potential areas for enhancement:

- Caching profile matches for performance
- Profile templates for common setups
- Migration tools for existing git configs
- Integration with git credential helpers
- Support for more git config options

## Related Documentation

- [Contributing Guide](../CONTRIBUTING.md) - Development guidelines
- [Quick Start](QUICKSTART.md) - Getting started
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues

