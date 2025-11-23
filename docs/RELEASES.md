# Release Process

This project uses [semantic-release](https://github.com/semantic-release/semantic-release) for automated version management and releases.

## How It Works

Releases are triggered manually via GitHub Actions workflow dispatch. When you run the release workflow, semantic-release:

1. **Analyzes commits** - Reads commit messages following [Conventional Commits](https://www.conventionalcommits.org/) format
2. **Determines version bump** - Calculates the next version based on commit types:
   - `feat:` → Minor version bump (e.g., 1.0.0 → 1.1.0)
   - `fix:` → Patch version bump (e.g., 1.0.0 → 1.0.1)
   - `feat!:` or `BREAKING CHANGE:` → Major version bump (e.g., 1.0.0 → 2.0.0)
3. **Generates changelog** - Automatically updates `CHANGELOG.md` with release notes
4. **Creates Git tag** - Tags the release with the version number
5. **Creates GitHub release** - Publishes release notes on GitHub

## Commit Types and Version Impact

| Commit Type | Version Impact | Example |
|------------|----------------|---------|
| `feat:` | Minor (1.0.0 → 1.1.0) | New feature added |
| `fix:` | Patch (1.0.0 → 1.0.1) | Bug fix |
| `perf:` | Patch (1.0.0 → 1.0.1) | Performance improvement |
| `refactor:` | Patch (1.0.0 → 1.0.1) | Code refactoring |
| `feat!:` or `BREAKING CHANGE:` | Major (1.0.0 → 2.0.0) | Breaking change |
| `docs:`, `style:`, `test:`, `build:`, `ci:`, `chore:` | No release | Documentation, formatting, tests, etc. |

## Release Rules

The release configuration (`.releaserc.json`) defines:

- **Branches**: Only `main` branch triggers releases
- **Preset**: Uses `conventionalcommits` preset
- **Changelog**: Automatically generated and committed to `CHANGELOG.md`
- **GitHub**: Creates releases with release notes

## Manual Release Process

Releases are triggered manually when you're ready to publish a stable version:

1. **Ensure all commits follow Conventional Commits format**
2. **Go to GitHub Actions** → Select "Release" workflow
3. **Click "Run workflow"** → Select the branch (usually `main`) → Click "Run workflow"
4. **Monitor the workflow** - semantic-release will analyze commits and create a release if needed

## Release Notes

Release notes are automatically generated from commit messages. The format includes:

- **Features** - New functionality added
- **Bug Fixes** - Issues resolved
- **Performance** - Performance improvements
- **Breaking Changes** - Incompatible changes (major versions)

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/) (SemVer):

- **MAJOR** (X.0.0): Breaking changes
- **MINOR** (0.X.0): New features (backward compatible)
- **PATCH** (0.0.X): Bug fixes (backward compatible)

## CI/CD Integration

Releases are triggered manually via the GitHub Actions workflow (`.github/workflows/release.yml`):

- Manual workflow dispatch only (no automatic releases)
- Executes semantic-release when triggered
- Publishes to GitHub Releases
- Updates changelog automatically

## Testing Locally

To test what would be released without actually creating a release:

```bash
bun install
bunx semantic-release --dry-run
```

This will show you:
- What version would be released
- What commits would be included
- What the changelog would look like
- But won't actually create a release or tag

## Troubleshooting

### Release didn't trigger

- Check that commits follow Conventional Commits format
- Verify commits are on `main` branch
- Check GitHub Actions logs for errors
- Ensure semantic-release has necessary permissions

### Wrong version bump

- Review commit messages - they must follow the format exactly
- Check `.releaserc.json` for release rules
- Breaking changes require `!` or `BREAKING CHANGE:` footer

### Changelog not updating

- Check that `CHANGELOG.md` exists
- Verify semantic-release has write permissions
- Check CI logs for errors

## Related Documentation

- [Contributing Guide](../CONTRIBUTING.md) - How to write commit messages
- [Changelog](../CHANGELOG.md) - Version history
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message format
