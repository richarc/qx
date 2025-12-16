# Release Process

This document describes the automated release process for publishing new versions of the qx quantum computing simulator to Hex.pm.

## Prerequisites

Before creating a release, ensure:

- [x] You have write access to the GitHub repository
- [x] `HEX_API_KEY` is configured in GitHub repository secrets (see [Setup](#setup) below)
- [x] All changes are merged to the `main` branch
- [x] All CI checks pass on `main`

## Setup

### Configure HEX_API_KEY (One-time setup)

If you haven't set up the Hex.pm API key yet:

1. **Generate an API key locally:**
   ```bash
   mix hex.user key generate
   ```

2. **Copy the generated key** (it will only be shown once)

3. **Add to GitHub Secrets:**
   - Navigate to: https://github.com/richarc/qx/settings/secrets/actions
   - Click **"New repository secret"**
   - **Name:** `HEX_API_KEY`
   - **Value:** Paste the key from step 1
   - Click **"Add secret"**

4. **Verify:** The release workflow will automatically check for this secret and provide clear instructions if it's missing.

## Creating a Release

Follow these steps to create a new release:

### 1. Update Version in mix.exs

Edit `/Users/richarc/Development/qx/mix.exs` and update the version (line 7):

```elixir
version: "X.Y.Z"
```

**Versioning guidelines** (following [Semantic Versioning](https://semver.org/)):
- **Major (X.0.0)**: Breaking changes, incompatible API changes
- **Minor (0.X.0)**: New features, backward-compatible
- **Patch (0.0.X)**: Bug fixes, backward-compatible

### 2. Update CHANGELOG.md

Add a new version section following [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features and capabilities

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes
```

**Tips:**
- Use the date when you're creating the release (YYYY-MM-DD format)
- Be specific and user-focused in your descriptions
- Include relevant issue/PR numbers if applicable
- Only include sections that have changes

### 3. Commit Changes

```bash
git add mix.exs CHANGELOG.md
git commit -m "Bump version to X.Y.Z"
```

### 4. Create and Push Tag

```bash
# Create tag (note the 'v' prefix)
git tag vX.Y.Z

# Push commit and tag
git push origin main
git push origin vX.Y.Z
```

**Alternative (one command):**
```bash
git push origin main --tags
```

### 5. Monitor Release

The GitHub Actions workflow will automatically:

1. **Validate** that the tag version matches mix.exs version
2. **Run quality gates:**
   - Compile code (warnings as errors)
   - Run Credo (strict mode)
   - Run all tests
   - Build documentation
   - Security audit (retired packages, vulnerabilities)
3. **Publish** to Hex.pm (package + documentation)
4. **Create** GitHub Release with CHANGELOG notes

**Monitor progress:**
- Visit: https://github.com/richarc/qx/actions
- Look for the "Release to Hex.pm" workflow
- Typical duration: 3-5 minutes

### 6. Verify Publication

After the workflow completes successfully:

- **Package**: https://hex.pm/packages/qx_sim
- **Documentation**: https://hexdocs.pm/qx_sim
- **GitHub Release**: https://github.com/richarc/qx/releases

## Quality Gates

The following checks must pass before publishing:

| Gate | Check | Failure Action |
|------|-------|----------------|
| Version Validation | Tag version matches mix.exs | Fix version mismatch, recreate tag |
| Compilation | Code compiles without warnings | Fix compilation issues |
| Code Quality | Credo strict passes | Address code quality issues |
| Tests | All tests pass | Fix failing tests |
| Documentation | Docs build successfully | Fix documentation errors |
| Security | No vulnerabilities or retired deps | Update vulnerable dependencies |

**Local testing before release:**
```bash
# Run all quality checks locally
mix deps.get
mix compile --warnings-as-errors
mix credo --strict
mix test
mix docs
mix hex.audit
```

## Troubleshooting

### Error: Version Mismatch

**Symptom:**
```
❌ ERROR: Tag version (0.2.4) doesn't match mix.exs version (0.2.3)
```

**Solution:**
```bash
# Delete tag locally
git tag -d vX.Y.Z

# Delete tag remotely
git push origin :refs/tags/vX.Y.Z

# Fix mix.exs version
# Edit mix.exs to update version

# Commit changes
git add mix.exs
git commit -m "Fix version in mix.exs"
git push origin main

# Recreate tag
git tag vX.Y.Z
git push origin vX.Y.Z
```

### Error: Missing CHANGELOG Entry

**Symptom:**
```
❌ ERROR: No CHANGELOG entry found for version 0.2.4
```

**Solution:**
1. Add the missing CHANGELOG section (see step 2 above)
2. Commit: `git commit -am "Add CHANGELOG entry for vX.Y.Z"`
3. Delete and recreate tag (see version mismatch solution)

### Error: Missing HEX_API_KEY

**Symptom:**
```
❌ ERROR: HEX_API_KEY secret is not configured
```

**Solution:**
1. Follow the [HEX_API_KEY setup](#configure-hex_api_key-one-time-setup) instructions
2. Re-run the workflow:
   - Go to: https://github.com/richarc/qx/actions
   - Find the failed workflow run
   - Click "Re-run jobs"

**Or** re-push the tag:
```bash
git push origin :refs/tags/vX.Y.Z  # Delete remote tag
git push origin vX.Y.Z              # Push tag again
```

### Error: Quality Gate Failures

**Symptom:** Tests fail, Credo fails, compilation fails, etc.

**Solution:**
1. Check the Actions log for specific error details
2. Fix the issues locally
3. Test locally: `mix test && mix credo --strict && mix docs`
4. Commit fixes
5. Delete and recreate tag (see version mismatch solution)

### Error: Security Vulnerabilities

**Symptom:**
```
mix deps.audit found vulnerabilities
```

**Solution:**
1. Review the vulnerable dependencies listed in the workflow output
2. Update dependencies:
   ```bash
   mix deps.update <package_name>
   ```
3. Test that everything still works: `mix test`
4. Commit updated mix.lock
5. Delete and recreate tag

### Workflow Stuck or Failed Mid-Publish

If the workflow fails after publishing to Hex.pm but before creating the GitHub Release:

**Don't panic!** The package is published successfully. You can:

1. **Create GitHub Release manually:**
   ```bash
   gh release create vX.Y.Z --title "Release X.Y.Z" --notes-file CHANGELOG.md
   ```

2. **Or extract just the relevant CHANGELOG section** and create via GitHub UI

## What Gets Published

### Hex.pm Package

**Published to:** https://hex.pm/packages/qx_sim

**Includes:**
- `lib/` - All source code
- `mix.exs` - Project configuration
- `README.md` - Project documentation
- `LICENSE` - Apache 2.0 license
- `CHANGELOG.md` - Version history

**Excludes:**
- `test/` - Tests
- `examples/` - Example scripts
- `.github/` - CI/CD workflows
- Build artifacts (`_build/`, `deps/`, `doc/`)

### Documentation

**Published to:** https://hexdocs.pm/qx_sim

**Includes:**
- All module documentation (from `@doc` and `@moduledoc`)
- README.md as overview
- CHANGELOG.md as version history
- Organized by module groups (Quantum Operations, Circuit Building, etc.)

**Note:** Documentation is automatically published by `mix hex.publish` - no separate step needed.

### GitHub Release

**Published to:** https://github.com/richarc/qx/releases

**Includes:**
- Release title: "Release X.Y.Z"
- Release notes extracted from CHANGELOG.md
- Installation instructions
- Links to Hex.pm package and documentation
- Automatic changelog from commits (if enabled)

## Rollback Strategy

If you need to rollback or fix a bad release:

### Option 1: Retire the Package (Recommended for broken packages)

```bash
mix hex.retire qx_sim X.Y.Z --reason "Brief reason for retirement"
```

**Retirement reasons:**
- `other` - Default
- `invalid` - Package is invalid
- `security` - Security issue
- `deprecated` - Use a different package

**Note:** Retired packages remain available but show a warning to users.

### Option 2: Publish a Hotfix Version

This is usually the best approach:

1. Fix the issue
2. Increment patch version (X.Y.Z+1)
3. Release normally
4. Optionally retire the broken version

### Option 3: Delete GitHub Release (Not recommended)

You can delete the GitHub Release, but the package will remain on Hex.pm:

```bash
# Via GitHub CLI
gh release delete vX.Y.Z

# Via GitHub UI
# Go to https://github.com/richarc/qx/releases
# Click "Delete" on the release
```

**Important:** You cannot delete packages from Hex.pm, only retire them.

## Manual Release (Emergency Only)

If GitHub Actions is unavailable, you can publish manually:

```bash
# 1. Run quality checks
mix test
mix credo --strict
mix docs

# 2. Publish to Hex.pm
mix hex.publish

# 3. Create GitHub Release
gh release create vX.Y.Z \
  --title "Release X.Y.Z" \
  --notes "$(sed -n '/## \[X.Y.Z\]/,/## \[/p' CHANGELOG.md | head -n -1)"
```

**Warning:** Manual releases bypass automated quality gates. Use only in emergencies.

## Release Checklist

Use this checklist when creating a release:

- [ ] All changes merged to `main`
- [ ] CI passing on `main` branch
- [ ] Version updated in `mix.exs`
- [ ] CHANGELOG.md updated with new version section
- [ ] Version number follows semantic versioning
- [ ] CHANGELOG follows Keep a Changelog format
- [ ] Committed changes: `git commit -m "Bump version to X.Y.Z"`
- [ ] Created tag: `git tag vX.Y.Z`
- [ ] Pushed tag: `git push origin vX.Y.Z`
- [ ] Monitored workflow at https://github.com/richarc/qx/actions
- [ ] Verified package at https://hex.pm/packages/qx_sim
- [ ] Verified docs at https://hexdocs.pm/qx_sim
- [ ] Verified GitHub Release at https://github.com/richarc/qx/releases

## CI/CD Workflows

This project uses two GitHub Actions workflows:

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Triggers:** Push to `main`, pull requests

**Purpose:** Catch issues early by running quality gates on every code change

**Runs:**
- Code compilation
- Tests
- Code quality checks (Credo)
- Documentation build
- Security audits

**Does NOT publish** - just validates code quality

### 2. Release Workflow (`.github/workflows/release.yml`)

**Triggers:** Git tag push (v*), manual dispatch

**Purpose:** Automated publishing to Hex.pm and GitHub Releases

**Runs:**
- All quality gates (same as CI)
- Version validation
- CHANGELOG extraction
- Hex.pm publishing
- GitHub Release creation

## Additional Resources

- [Hex.pm Documentation](https://hex.pm/docs)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## Questions or Issues?

If you encounter problems with the release process:

1. Check the workflow logs at https://github.com/richarc/qx/actions
2. Review this troubleshooting guide
3. Open an issue at https://github.com/richarc/qx/issues
