# Publishing Qx via GitHub

Since the `qx` name is already taken on Hex.pm, we'll publish via GitHub instead. This is a perfectly valid approach used by many Elixir packages.

---

## Quick Start

Users can install your package directly from GitHub:

```elixir
def deps do
  [
    {:qx, github: "richarc/qx", tag: "v0.2.0"}
  ]
end
```

---

## Publishing Steps

### 1. Commit Your Changes

```bash
cd /Users/richarc/Development/qx

# Add all changes
git add .

# Commit
git commit -m "Release v0.2.0

- Full quantum circuit API with 20+ gates
- EXLA CPU acceleration (~100x speedup)
- EMLX GPU support for Apple Silicon
- Comprehensive benchmarking suite
- Circuit visualization with VegaLite
- See CHANGELOG.md for full details
"
```

### 2. Tag the Release

```bash
# Create version tag
git tag -a v0.2.0 -m "Release v0.2.0"

# Push commits and tags
git push origin main
git push origin v0.2.0
```

### 3. Create GitHub Release

1. **Go to your repository**: https://github.com/richarc/qx

2. **Navigate to Releases**: Click "Releases" on the right sidebar

3. **Create new release**: Click "Create a new release" or "Draft a new release"

4. **Fill in the details**:
   - **Choose a tag**: Select `v0.2.0` (should appear after you pushed it)
   - **Release title**: `Qx v0.2.0 - Quantum Computing Simulator`
   - **Description**: Copy the content from CHANGELOG.md for v0.2.0

5. **Publish**: Click "Publish release"

---

## Installation Instructions for Users

Add to your README (already done ✅):

```markdown
## Installation

Add `qx` to your list of dependencies in `mix.exs`:

\`\`\`elixir
def deps do
  [
    {:qx, github: "richarc/qx", tag: "v0.2.0"}
  ]
end
\`\`\`

Then run:

\`\`\`bash
mix deps.get
\`\`\`
```

---

## Alternative Installation Options

Users can also:

### Install from main branch (latest development)

```elixir
{:qx, github: "richarc/qx"}
```

### Install from a specific branch

```elixir
{:qx, github: "richarc/qx", branch: "develop"}
```

### Install from a specific commit

```elixir
{:qx, github: "richarc/qx", ref: "abc123def"}
```

---

## Advantages of GitHub Distribution

✅ **Full control**: You own the package name and distribution
✅ **No name conflicts**: Don't need to find an available Hex.pm name
✅ **Easy updates**: Just push tags and create releases
✅ **Free hosting**: GitHub provides unlimited bandwidth
✅ **Private repos**: Can have private packages (with GitHub auth)
✅ **Works everywhere**: Standard Mix dependency system

---

## Documentation

Since you're not on Hex.pm, you won't have automatic HexDocs hosting. Options:

### Option 1: GitHub Pages (Recommended)

Host your documentation on GitHub Pages:

```bash
# Generate docs
mix docs

# Create gh-pages branch
git checkout --orphan gh-pages
git rm -rf .
cp -r doc/* .
git add .
git commit -m "Initial documentation"
git push origin gh-pages

# Return to main
git checkout main
```

Your docs will be at: `https://richarc.github.io/qx/`

### Option 2: README-only

Keep comprehensive documentation in your README.md (current approach).

### Option 3: Wiki

Use GitHub Wiki for additional documentation.

---

## Version Management

### Semantic Versioning

Follow [SemVer](https://semver.org/):

- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.2.0): New features, backward compatible
- **PATCH** (0.2.1): Bug fixes, backward compatible

### Releasing New Versions

For version 0.2.1:

```bash
# Update version in mix.exs
# Edit: version: "0.2.1"

# Update CHANGELOG.md
# Add new section for 0.2.1

# Commit, tag, push
git add mix.exs CHANGELOG.md
git commit -m "Bump version to 0.2.1"
git tag v0.2.1
git push origin main
git push origin v0.2.1

# Create GitHub release
# Go to GitHub and create release for v0.2.1
```

---

## Badges for README

Add these badges to show project status:

```markdown
[![GitHub Release](https://img.shields.io/github/v/release/richarc/qx)](https://github.com/richarc/qx/releases)
[![License](https://img.shields.io/github/license/richarc/qx)](https://github.com/richarc/qx/blob/main/LICENSE)
[![Elixir CI](https://github.com/richarc/qx/workflows/CI/badge.svg)](https://github.com/richarc/qx/actions)
```

---

## Promoting Your Package

### Share on:

1. **Elixir Forum**: https://elixirforum.com/c/elixir-questions/libraries/45
   - Create a post announcing your quantum computing package

2. **Reddit**: r/elixir
   - Post: "Show and Tell: Quantum Computing Simulator in Elixir"

3. **Twitter/X**: Tag @elixirlang

4. **Awesome Elixir**: Submit PR to add Qx
   - https://github.com/h4cc/awesome-elixir

5. **ElixirWeekly**: Submit your project
   - https://elixirweekly.net/

---

## Comparison: GitHub vs Hex.pm

| Feature | GitHub | Hex.pm |
|---------|--------|--------|
| **Package name** | Any name you want | Must be unique |
| **Installation** | `github: "user/repo"` | `"~> 0.2.0"` |
| **Documentation** | Self-hosted | Automatic HexDocs |
| **Discovery** | Manual promotion | Hex.pm search |
| **Trust** | Your GitHub reputation | Hex.pm verified |
| **Dependencies** | Can use GitHub deps | Must use Hex packages |
| **Cost** | Free | Free |
| **Update speed** | Instant (on push) | Publish command |

---

## Future: Moving to Hex.pm

If you later want to move to Hex.pm, you could:

1. **Choose a new name**: e.g., `quantum_ex`, `quex`, `elixir_quantum`
2. **Publish to Hex**: With the new name
3. **Deprecate GitHub**: Add notice in README pointing to Hex package
4. **Keep both**: GitHub can point to the Hex version

---

## Ready to Publish!

You're all set. Just run these commands:

```bash
cd /Users/richarc/Development/qx

# Commit everything
git add .
git commit -m "Release v0.2.0"

# Tag the release
git tag -a v0.2.0 -m "Release v0.2.0"

# Push to GitHub
git push origin main
git push origin v0.2.0
```

Then go to https://github.com/richarc/qx/releases/new and create the release!

Users can then install with:
```elixir
{:qx, github: "richarc/qx", tag: "v0.2.0"}
```

🚀 **You're ready to share your quantum computing simulator with the world!**
