# Release Setup Summary

This document summarizes the automated release setup for `gh-account-guard`.

## What Was Set Up

### 1. GitHub Actions Release Workflow
- **File**: `.github/workflows/release.yml`
- **Triggers**: Runs on every push to `main` branch
- **Actions**:
  - Checks out repository with full git history
  - Installs Bun and semantic-release dependencies
  - Analyzes commits and creates releases automatically

### 2. Semantic Release Configuration
- **File**: `.releaserc.json`
- **Features**:
  - Conventional Commits analysis
  - Automatic version bumping (major/minor/patch)
  - Changelog generation in `docs/CHANGELOG.md`
  - GitHub release creation
  - Git tag creation

### 3. Package Configuration
- **File**: `package.json`
- **Purpose**: Required for semantic-release to work
- **Note**: Update the repository URL with your actual GitHub username/organization

### 4. Documentation
- **CONTRIBUTING.md**: Guidelines for contributors including commit message format
- **docs/RELEASES.md**: Detailed release process documentation
- **.gitignore**: Added to ignore node_modules and other build artifacts

## Next Steps

1. **Update package.json repository URL:**
   ```json
   "repository": {
     "type": "git",
     "url": "https://github.com/YOUR_USERNAME/gh-account-guard.git"
   }
   ```

2. **Make your first release:**
   - Use Conventional Commits format for your commits
   - Push to `main` branch
   - The release workflow will automatically:
     - Analyze commits
     - Determine version bump
     - Generate changelog
     - Create GitHub release
     - Tag the release

3. **Example first release commit:**
   ```bash
   git commit -m "feat: initial release of gh-account-guard"
   git push origin main
   ```

## How It Works

1. **Commit Analysis**: semantic-release analyzes commits since the last release
2. **Version Bumping**:
   - `feat:` → minor version (1.0.0 → 1.1.0)
   - `fix:` → patch version (1.0.0 → 1.0.1)
   - `BREAKING CHANGE:` → major version (1.0.0 → 2.0.0)
3. **Changelog**: Automatically generated from commit messages
4. **Release**: GitHub release created with release notes
5. **Tag**: Git tag created with version number

## Testing Locally

To test what would be released without actually creating a release:

```bash
bun install
bunx semantic-release --dry-run
```

## Skipping Releases

To skip a release for a specific commit, add `[skip release]` to the commit message:

```bash
git commit -m "docs: update README [skip release]"
```

## Troubleshooting

- **Release not triggered**: Check that commits follow Conventional Commits format
- **Wrong version**: Review commit types (`feat`, `fix`, etc.)
- **Changelog issues**: Check GitHub Actions logs for errors
- **Permissions**: Ensure `GITHUB_TOKEN` has write permissions for contents, issues, and pull-requests

## Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Release](https://github.com/semantic-release/semantic-release)
- [Keep a Changelog](https://keepachangelog.com/)

