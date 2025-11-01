# Publishing Qx to Hex.pm

Complete step-by-step guide to publish Qx to Hex.pm.

---

## Prerequisites

### 1. Create Hex.pm Account

If you don't have one already:
1. Go to https://hex.pm/signup
2. Create your account
3. Verify your email

### 2. Authenticate Hex Locally

```bash
mix hex.user auth
```

This will prompt you to enter your Hex.pm credentials and create a local API key.

---

## Pre-Publication Checklist

### Required Files ✅
- [x] **LICENSE** - Apache-2.0 (present)
- [x] **README.md** - Documentation (present)
- [ ] **CHANGELOG.md** - Version history (needs to be created)

### Package Configuration ✅
- [x] `package/0` function in mix.exs
- [x] `description` field
- [x] Valid version number (0.2.0)
- [x] License specified
- [x] Links to repository

---

## Issues to Fix Before Publishing

### 1. Fix EMLX Dependency

**Current (won't work on Hex.pm)**:
```elixir
{:emlx, github: "elixir-nx/emlx", branch: "main"}
```

**Change to**:
```elixir
{:emlx, "~> 0.2", optional: true}
```

This makes EMLX optional since:
- It's only for Apple Silicon users
- Not all users will need GPU acceleration
- Users can still install it by adding it to their deps

### 2. Create CHANGELOG.md

Create a `CHANGELOG.md` file documenting version 0.2.0:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-11-01

### Added
- Full quantum circuit API with chainable operations
- Support for 20+ quantum gates (H, X, Y, Z, RX, RY, RZ, CNOT, CZ, etc.)
- Measurement operations with classical bit storage
- Conditional operations based on classical bits
- Circuit visualization using VegaLite
- Statevector simulation using Nx tensors
- EXLA backend support for CPU acceleration
- EMLX backend support for Apple Silicon GPU acceleration
- Comprehensive benchmarking suite using Benchee
- GHZ state scaling benchmarks
- Backend comparison benchmarks
- Example files demonstrating key features

### Changed
- Updated to use Complex64 (:c64) tensor format
- Improved error handling with specific error types
- Enhanced documentation with guides and examples

### Performance
- ~100x speedup with EXLA CPU backend vs Binary
- Additional 2-10x speedup with GPU acceleration (hardware dependent)

## [0.1.0] - Initial Release

Initial development version.
```

### 3. Update mix.exs docs/extras

Add guides to documentation:

```elixir
extras: [
  "README.md",
  "CHANGELOG.md",
  "BENCHMARK_IMPLEMENTATION_SUMMARY.md",
  "TELEPORTATION_EXAMPLE.md"
]
```

### 4. Add files field to package/0

Tell Hex which files to include:

```elixir
defp package do
  [
    name: "qx",
    files: [
      "lib",
      "mix.exs",
      "README.md",
      "LICENSE",
      "CHANGELOG.md"
    ],
    licenses: ["Apache-2.0"],
    links: %{
      "GitHub" => "https://github.com/richarc/qx"
    },
    maintainers: ["Craig Richards"]
  ]
end
```

---

## Publishing Steps

### Step 1: Make Required Changes

Apply all the fixes mentioned above.

### Step 2: Run Tests

Ensure all tests pass:

```bash
mix test
```

### Step 3: Build Documentation

Generate docs to verify they look good:

```bash
mix docs
```

Then open `doc/index.html` in your browser to review.

### Step 4: Run Hex Validation

Check if your package is ready:

```bash
mix hex.build
```

This will:
- Validate your package configuration
- Check for common issues
- Create a `.tar` file locally (don't publish this manually)

### Step 5: Publish to Hex.pm

```bash
mix hex.publish
```

This will:
1. Show you what will be published
2. Ask you to review the files
3. Ask you to confirm
4. Publish to Hex.pm
5. Automatically publish documentation to HexDocs

**Important**: You'll be asked to confirm. Review carefully!

---

## After Publishing

### 1. Verify on Hex.pm

Visit https://hex.pm/packages/qx to see your package.

### 2. Check Documentation

Visit https://hexdocs.pm/qx to see your published docs.

### 3. Update README Badge

Add a Hex.pm badge to your README:

```markdown
[![Hex.pm](https://img.shields.io/hexpm/v/qx.svg)](https://hex.pm/packages/qx)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/qx)
```

### 4. Tag the Release

```bash
git tag v0.2.0
git push origin v0.2.0
```

### 5. Create GitHub Release

Go to your GitHub repository and create a release for v0.2.0 with the changelog content.

---

## Publishing Updates

When you want to publish a new version:

### 1. Update Version

In `mix.exs`:
```elixir
version: "0.2.1"  # or whatever the new version is
```

### 2. Update CHANGELOG.md

Add a new section for the new version.

### 3. Commit Changes

```bash
git add mix.exs CHANGELOG.md
git commit -m "Bump version to 0.2.1"
```

### 4. Publish

```bash
mix hex.publish
```

### 5. Tag

```bash
git tag v0.2.1
git push origin v0.2.1
```

---

## Common Issues

### "Package has dependencies that are not available via Hex"

**Problem**: You're using GitHub dependencies.

**Solution**: Either publish those dependencies first, make them optional, or remove them.

### "Package is missing required field: files"

**Problem**: No `files` list in `package/0`.

**Solution**: Add the `files` field as shown above.

### "Cannot find LICENSE file"

**Problem**: LICENSE file missing or not in root directory.

**Solution**: Ensure LICENSE file is in project root.

### "Authentication required"

**Problem**: Not logged in to Hex.

**Solution**: Run `mix hex.user auth`

### "Version already published"

**Problem**: You already published this version.

**Solution**: You can't republish. If you made a mistake, publish a new version (e.g., 0.2.1).

---

## Hex.pm Package Metadata

After publishing, your package will appear at:

**URL**: https://hex.pm/packages/qx

**Installation** (users will add to their `mix.exs`):
```elixir
def deps do
  [
    {:qx, "~> 0.2.0"}
  ]
end
```

**For Apple Silicon GPU acceleration** (optional):
```elixir
def deps do
  [
    {:qx, "~> 0.2.0"},
    {:emlx, "~> 0.2"}  # Optional: Apple Silicon GPU acceleration
  ]
end
```

---

## Versioning Guide

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0): Breaking API changes
- **MINOR** (0.2.0): New features, backward compatible
- **PATCH** (0.2.1): Bug fixes, backward compatible

Examples:
- Added new gate → **0.3.0** (new feature)
- Fixed bug in measurement → **0.2.1** (bug fix)
- Changed API significantly → **1.0.0** (breaking change)

---

## Checklist

Before running `mix hex.publish`, verify:

- [ ] All tests pass (`mix test`)
- [ ] Documentation builds (`mix docs`)
- [ ] CHANGELOG.md updated
- [ ] Version bumped in mix.exs
- [ ] No GitHub dependencies (or they're optional)
- [ ] LICENSE file present
- [ ] README.md is up to date
- [ ] Committed all changes to git
- [ ] Authenticated with Hex (`mix hex.user auth`)

---

## Resources

- [Hex.pm Documentation](https://hex.pm/docs)
- [Publishing Packages Guide](https://hex.pm/docs/publish)
- [Package Configuration](https://hexdocs.pm/mix/Mix.Tasks.Hex.Build.html)
- [Semantic Versioning](https://semver.org/)
