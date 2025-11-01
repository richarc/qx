# Hex.pm Publishing Checklist for Qx v0.2.0

## ✅ Pre-Publication Tasks (COMPLETED)

- [x] **Fixed EMLX dependency** - Changed from GitHub to Hex (~> 0.2, optional: true)
- [x] **Created CHANGELOG.md** - Complete version history for 0.2.0
- [x] **Updated mix.exs**:
  - [x] Added `files` list to package/0
  - [x] Added extras to docs/0 (README.md, CHANGELOG.md)
  - [x] Added Changelog link
- [x] **Removed backup file** - Deleted lib/qx/qubit.ex.backup
- [x] **Tests passing** - All 551 tests pass (198 doctests + 353 tests)
- [x] **Documentation builds** - Successfully generated docs at doc/index.html
- [x] **Package validates** - `mix hex.build` passes without errors

## 📋 Ready to Publish!

Your package is now ready to publish to Hex.pm. Follow these steps:

### Step 1: Authenticate with Hex (if not already done)

```bash
mix hex.user auth
```

Enter your Hex.pm username and password when prompted.

### Step 2: Review the Package

```bash
mix hex.build
```

This shows you exactly what will be published. Review the output carefully.

### Step 3: Publish to Hex.pm

```bash
mix hex.publish
```

You'll see a summary and be asked to confirm:
- Package name and version
- Dependencies
- Files to be published
- License

Type `Y` to confirm and publish.

### Step 4: Verify Publication

1. **Check Hex.pm**: Visit https://hex.pm/packages/qx
2. **Check HexDocs**: Visit https://hexdocs.pm/qx (may take a few minutes)

### Step 5: Tag the Release

```bash
git add .
git commit -m "Release v0.2.0"
git tag v0.2.0
git push origin main
git push origin v0.2.0
```

### Step 6: Create GitHub Release

1. Go to https://github.com/richarc/qx/releases/new
2. Choose tag: v0.2.0
3. Release title: "Qx v0.2.0"
4. Copy content from CHANGELOG.md for the description
5. Publish release

### Step 7: Update README (Optional)

Add Hex.pm badges to the top of README.md:

```markdown
[![Hex.pm](https://img.shields.io/hexpm/v/qx.svg)](https://hex.pm/packages/qx)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/qx)
[![License](https://img.shields.io/hexpm/l/qx.svg)](https://github.com/richarc/qx/blob/main/LICENSE)
```

---

## 📦 Package Summary

**Name**: qx
**Version**: 0.2.0
**License**: Apache-2.0
**Maintainer**: Craig Richards

**Dependencies**:
- nx ~> 0.10
- exla ~> 0.10
- emlx ~> 0.2 (optional)
- vega_lite ~> 0.1
- complex ~> 0.6
- usage_rules ~> 0.1

**Installation** (users will add to their mix.exs):
```elixir
def deps do
  [
    {:qx, "~> 0.2.0"}
  ]
end
```

**For Apple Silicon GPU** (optional):
```elixir
def deps do
  [
    {:qx, "~> 0.2.0"},
    {:emlx, "~> 0.2"}  # Optional: for GPU acceleration
  ]
end
```

---

## 🚨 Important Notes

### You Can't Unpublish

Once published to Hex.pm, you **cannot** unpublish or modify a version. If you discover an issue:
- Publish a new version (e.g., 0.2.1) with the fix
- Update CHANGELOG.md with the fix

### First-Time Publishing

If this is your first package on Hex.pm:
- The package name `qx` will be permanently claimed by your account
- Make sure you're happy with the package name before publishing

### Documentation

Documentation is automatically published to HexDocs.pm when you run `mix hex.publish`. You don't need to do anything extra.

---

## 📚 What Happens After Publishing

1. **Hex.pm listing** appears immediately at https://hex.pm/packages/qx
2. **HexDocs** builds within a few minutes at https://hexdocs.pm/qx
3. **Users can install** with `mix deps.get` after adding to their mix.exs
4. **Search integration** - Your package becomes searchable on Hex.pm
5. **Statistics tracking** - Hex.pm tracks downloads and usage

---

## 🎉 Post-Publication

Share your package:
- Tweet about it (mention @elixirlang)
- Post in Elixir Forum: https://elixirforum.com/c/elixir-questions/libraries/45
- Reddit: r/elixir
- LinkedIn
- Elixir Slack

Consider:
- Writing a blog post about Qx
- Creating example projects
- Recording tutorial videos
- Submitting to Awesome Elixir list

---

## 🔄 Publishing Future Updates

When you're ready to publish v0.2.1 or v0.3.0:

1. Update `version` in mix.exs
2. Add entry to CHANGELOG.md
3. Commit changes
4. Run `mix hex.publish`
5. Tag the release: `git tag v0.2.1 && git push origin v0.2.1`
6. Create GitHub release

---

## ❓ Questions?

- Hex.pm docs: https://hex.pm/docs/publish
- Elixir Forum: https://elixirforum.com
- Elixir Slack: https://elixir-slackin.herokuapp.com

---

## ✨ You're Ready!

Everything is prepared. When you're ready to publish, simply run:

```bash
mix hex.publish
```

Good luck! 🚀
