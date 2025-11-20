# Refactoring Plan: Better Architecture & DRY Principles

## Current Structure
- `lib/commands.sh` - 1506 lines (13 commands)
- `lib/config.sh` - 883 lines (YAML parsing + config management)
- `lib/directory.sh` - 539 lines
- `lib/ui.sh` - 365 lines
- `lib/utils.sh` - 63 lines

## Target Structure

```
lib/
├── helpers/
│   ├── yaml.sh          # YAML parsing functions (extracted from config.sh)
│   ├── git.sh           # Git helper functions (extracted from commands.sh)
│   ├── gh_auth.sh       # GitHub auth helper functions (extracted)
│   └── profile.sh       # Profile matching/management (extracted from config.sh)
├── commands/
│   ├── setup.sh
│   ├── init.sh
│   ├── config.sh
│   ├── status.sh
│   ├── fix.sh
│   ├── switch.sh
│   ├── auto_enforce.sh
│   ├── install.sh
│   ├── install_shell_hook.sh
│   ├── install_git_hook.sh
│   ├── install_git_hook_global.sh
│   ├── apply_hook_to_repos.sh
│   └── create_alias.sh
├── commands.sh          # Loader that sources all command files
├── config.sh            # Config/profile management (simplified)
├── directory.sh         # (unchanged)
├── ui.sh               # (unchanged)
└── utils.sh            # (unchanged)
```

## Refactoring Steps

1. Extract YAML parsing → `lib/yaml.sh`
2. Extract git helpers → `lib/git.sh`
3. Extract gh auth helpers → `lib/gh_auth.sh`
4. Extract profile matching → `lib/profile.sh`
5. Split commands.sh → individual files in `lib/commands/`
6. Create commands.sh loader
7. Update config.sh to use extracted modules
8. Update main entry point
9. Test all commands

## Benefits

- **DRY**: Shared functions extracted and reused
- **Maintainability**: Smaller, focused files
- **Testability**: Easier to test individual modules
- **Clarity**: Clear separation of concerns

