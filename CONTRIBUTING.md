# Contributing to gh-account-guard

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Development Setup

1. **Fork and clone the repository:**
   ```bash
   gh repo fork <your-username>/gh-account-guard
   cd gh-account-guard
   ```

2. **Install the extension locally:**
   ```bash
   gh extension install .
   ```

3. **Install development dependencies:**
   ```bash
   make install-deps
   ```

4. **Run tests:**
   ```bash
   make test
   ```

5. **Run linting:**
   ```bash
   make lint
   ```

## Commit Message Format

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning and changelog generation. Please follow this format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Commit Types

- `feat`: A new feature (triggers minor version release)
- `fix`: A bug fix (triggers patch version release)
- `docs`: Documentation only changes (no release)
- `style`: Code style changes (no release)
- `refactor`: Code refactoring (triggers patch release)
- `perf`: Performance improvements (triggers patch release)
- `test`: Adding or updating tests (no release)
- `build`: Build system changes (no release)
- `ci`: CI configuration changes (no release)
- `chore`: Other changes that don't modify src or test files (no release)

### Examples

```bash
# Feature (minor release)
git commit -m "feat: add support for custom config paths"

# Bug fix (patch release)
git commit -m "fix: handle missing config file gracefully"

# Breaking change (major release)
git commit -m "feat!: change default config location

BREAKING CHANGE: config file moved from ~/.config/gh/account-guard.yml to ~/.gh-account-guard.yml"

# Documentation (no release)
git commit -m "docs: update installation instructions"

# With scope
git commit -m "feat(setup): add interactive profile editor"
```

### Breaking Changes

To indicate a breaking change, add `!` after the type or include `BREAKING CHANGE:` in the footer:

```bash
# Option 1: Using !
git commit -m "feat!: change default config location"

# Option 2: Using BREAKING CHANGE footer
git commit -m "feat: change default config location

BREAKING CHANGE: config file moved from ~/.config/gh/account-guard.yml"
```

## Pull Request Process

1. **Create a feature branch:**
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make your changes** and ensure:
   - Code follows existing style
   - Tests pass (`make test`)
   - Linting passes (`make lint`)
   - Commit messages follow Conventional Commits format

3. **Push your branch:**
   ```bash
   git push origin feat/your-feature-name
   ```

4. **Create a Pull Request** with a clear description of your changes

5. **Wait for review** - maintainers will review your PR

## Testing

- Run all tests: `make test`
- Run linting: `make lint`
- Run CI checks: `make ci`

Tests are located in the `test/` directory and use [bats](https://github.com/bats-core/bats-core).

## Code Style

- Use `shellcheck` for shell script linting
- Follow existing code style and patterns
- Add comments for complex logic
- Keep functions focused and small

## Release Process

Releases are automated using [semantic-release](https://github.com/semantic-release/semantic-release). When you merge a PR to `main`:

1. Commits are analyzed for Conventional Commits format
2. Version is automatically bumped based on commit types
3. Changelog is automatically generated
4. GitHub release is created with release notes
5. Git tag is created

See [docs/RELEASES.md](docs/RELEASES.md) for more details.

## Questions?

- Open an issue for bug reports or feature requests
- Check existing issues and discussions
- Review the [documentation](docs/)

Thank you for contributing! 🎉

