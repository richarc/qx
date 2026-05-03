<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below. 
Before attempting to use any of these packages or to discover if you should use them, review their 
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->

<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->

## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**
```bash
bd ready --json
```

**Create new issues:**
```bash
bd create "Issue title" -t bug|feature|task -p 0-4 --json
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
bd create "Subtask" --parent <epic-id> --json  # Hierarchical subtask (gets ID like epic-id.1)
```

**Claim and update:**
```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**
```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`
6. **Commit together**: Always commit the `.beads/issues.jsonl` file together with the code changes so issue state stays in sync with code state

### Auto-Sync

bd automatically syncs with git:
- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### GitHub Copilot Integration

If using GitHub Copilot, also create `.github/copilot-instructions.md` for automatic instruction loading.
Run `bd onboard` to get the content, or see step 2 of the onboard instructions.

### MCP Server (Recommended)

If using Claude or MCP-compatible clients, install the beads MCP server:

```bash
pip install beads-mcp
```

Add to MCP config (e.g., `~/.config/claude/config.json`):
```json
{
  "beads": {
    "command": "beads-mcp",
    "args": []
  }
}
```

Then use `mcp__beads__*` functions instead of CLI commands.

### Managing AI-Generated Planning Documents

AI assistants often create planning and design documents during development:
- PLAN.md, IMPLEMENTATION.md, ARCHITECTURE.md
- DESIGN.md, CODEBASE_SUMMARY.md, INTEGRATION_PLAN.md
- TESTING_GUIDE.md, TECHNICAL_DESIGN.md, and similar files

**Best Practice: Use a dedicated directory for these ephemeral files**

**Recommended approach:**
- Create a `history/` directory in the project root
- Store ALL AI-generated planning/design docs in `history/`
- Keep the repository root clean and focused on permanent project files
- Only access `history/` when explicitly asked to review past planning

**Example .gitignore entry (optional):**
```
# AI planning documents (ephemeral)
history/
```

**Benefits:**
- ✅ Clean repository root
- ✅ Clear separation between ephemeral and permanent documentation
- ✅ Easy to exclude from version control if desired
- ✅ Preserves planning history for archeological research
- ✅ Reduces noise when browsing the project

### CLI Help

Run `bd <command> --help` to see all available flags for any command.
For example: `bd create --help` shows `--parent`, `--deps`, `--assignee`, etc.

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ✅ Store AI planning docs in `history/` directory
- ✅ Run `bd <cmd> --help` to discover available flags
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems
- ❌ Do NOT clutter repo root with planning documents

For more details, see README.md and QUICKSTART.md.

## Development Workflow

| Phase | Command | What it does |
|-------|---------|--------------|
| Planning | `/plan [description]` | Requirements gathering → bd issues |
| Implementation | `/implement [issue-id]` | TDD implementation of a bd issue |
| PR Review | `/pr [issue-id]` | Create PR, automated review, close issue |
| Release | release-manager agent | Publish to Hex.pm + GitHub |

### TDD Rules (enforced by hook + instruction)

1. Tests written before implementation code — always
2. Existing tests never modified without explicit human approval (PreToolUse hook enforces this)
3. Newly written tests must fail before implementation begins

### Branch Strategy

- One branch per bd issue: `bd-<issue-id>/<short-description>`
- All branches PR into main; deleted after squash merge

### Issue Lifecycle

`open` → `in_progress` (claim) → [implement] → PR created → PR merged → `closed`

### Hook: Test File Guard

A `PreToolUse` hook in `.claude/settings.local.json` hard-blocks any `Edit` or `Write` tool call
targeting a file matching `*_test.exs` or `*/test/*`. If you see a block message, stop, explain
the intended change to the user, and wait for explicit approval before proceeding.

Note: The hook does not cover `Bash` tool calls (e.g. `sed -i`). The instruction above is the
backstop for that path.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->

<!-- ELIXIR-PHOENIX-PLUGIN:START -->
<!-- Tailored for Qx (pure Elixir library, no Phoenix/Ecto/LiveView/Oban). Edit /phx:init template manually before re-running --update or it will be overwritten with the full Phoenix-flavoured version. -->

# Elixir Plugin — Mandatory Procedures (Qx-tailored)

## SKILL EXECUTION ENFORCEMENT

These rules govern ALL `/phx:*` command execution. Violations invalidate the session output.

1. Skills are PROCEDURES, not suggestions. Every numbered step MUST execute.
2. Agent spawning is MANDATORY when a skill says "spawn" or "always run". Zero agents spawned when required = skill failure.
3. Every skill MUST produce its required artifact file (`.claude/plans/{slug}/`, etc.). Chat-only output without the artifact = skill failure.
4. "Already implemented" is a FINDING, not an exit. Document it in the artifact; do not bail out of the workflow.
5. Read SKILL.md BEFORE executing. Do not improvise a different workflow.
6. No unauthorized judgment calls. If the skill defines no early-exit, there is no early exit.
7. Agent output MUST be saved to `.claude/plans/{slug}/research/{agent-name}-report.md` before synthesis.

## EXECUTE BEFORE EVERY RESPONSE

### STEP 1: CLASSIFY
- Bug fix → score 0–2, skip to STEP 5
- Review/analysis → skip to response
- Feature → continue

### STEP 2: COMPLEXITY SCORE

| Factor | Points |
|--------|--------|
| Single file change | 0 |
| 2–3 files | +2 |
| 4+ files or crosses module boundaries (Calc / Operations / Simulation / Draw / Remote) | +3 |
| New domain concept (new gate, new sim mode, new visualization) | +3 |
| Follows existing pattern | -2 |
| Touches `defn` / Nx kernels in `lib/qx/calc*.ex` | +3 |
| Changes public API of `Qx`, `Qx.QuantumCircuit`, `Qx.Operations`, `Qx.Simulation`, `Qx.SimulationResult` | +3 |
| External API or new dependency | +2 |

Show the calculation: `Complexity: {score} ({factors}) → {level}`.

### STEP 3: ROUTE

| Score | Action |
|-------|--------|
| ≤ 2 | Proceed directly, or offer `/phx:quick` |
| 3–6 | Ask 1–2 questions, then `/phx:plan` |
| 7–10 | Ask 2–4 questions, recommend `/phx:plan --detail comprehensive` |
| > 10 | Strongly recommend `/phx:full` |

### STEP 4: INTERVIEW (if score ≥ 3)

| Task type | Questions |
|-----------|-----------|
| New feature / gate / op | "What's in scope / out of scope?" |
| Public API change | "Breaking change? CHANGELOG entry? Major-version bump?" |
| Nx kernel work | "Reshape/contract or gather/select? Backend-agnostic? Benchmarked?" |

### STEP 5: LOAD references silently

| Pattern | Load |
|---------|------|
| `lib/qx/calc*.ex`, anything with `defn` | elixir-idioms (Nx/defn discipline) |
| `*_test.exs` | testing, exunit-patterns |
| Any other `.ex` | elixir-idioms |

### STEP 6: SPAWN agents

| Trigger | Agent | When |
|---------|-------|------|
| `/phx:plan` invoked | hex-library-researcher | ALWAYS (evaluate hex deps before adding) |
| `/phx:review` invoked | elixir-reviewer, testing-reviewer, iron-law-judge | ALWAYS (parallel) |

(`phoenix-patterns-analyst`, `liveview-architect`, `oban-specialist`, `ecto-schema-designer`, `security-analyzer` for web auth — all skipped: not applicable.)

### STEP 7: PROCEED

Respond. Honour the verification rules below.

---

## IRON LAWS — STOP if violated

If code would violate ANY of these:
1. STOP. 2. Show the problematic code. 3. Show the correct pattern. 4. Ask permission to apply the fix.

**Elixir / OTP**
1. NO `String.to_atom/1` on caller-supplied strings — atom-table exhaustion. Use `String.to_existing_atom/1` or keep strings.
2. NO process (GenServer / Agent / Task started under a supervisor) without a runtime reason. Qx is a *library*; processes force callers to supervise. Justify with: concurrency, isolated state, or fault isolation.

**Nx kernels (`lib/qx/calc*.ex`, any `defn`)**
3. PREFER reshape + tensor contraction over `Nx.take` + `Nx.select` gather/mask patterns. Gathers don't fuse and double the work. If gather is unavoidable, leave a one-line comment saying why.
4. `defn` functions MUST be correct on `Nx.BinaryBackend` (the default when EXLA isn't loaded). No EXLA-only assumptions.
5. NO host-side loops over `2^n` amplitudes. Vectorise with Nx primitives.

**Public API surface**
6. Breaking changes to `Qx`, `Qx.QuantumCircuit`, `Qx.Operations`, `Qx.Simulation`, `Qx.SimulationResult`, or any module under `Qx.Behaviours` REQUIRE a CHANGELOG entry and a major-version bump (SemVer).
7. Public functions raise typed `Qx.*Error` (`Qx.QubitIndexError`, `Qx.GateError`, etc.) on misuse. Do not let raw `Nx` / `Complex` / `ArgumentError` leak across the API boundary — route through `Qx.Validation`.

## VERIFICATION — MANDATORY after code changes

After ANY code change, before presenting results:

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict
```

Offer `mix test` after meaningful changes. Offer `mix bench` (alias in `mix.exs`) after touching `lib/qx/calc*.ex`, `lib/qx/gates.ex`, or `lib/qx/simulation.ex`.

Do NOT present code as complete until verification passes.

## POST-ACTION — Offer follow-ups

| After | Offer |
|-------|-------|
| Bug fix | "Capture as lesson with /phx:learn-from-fix?" |
| Feature complete | "Quality check with /phx:review?" |
| Nx kernel change | "Run `mix bench` to confirm no regression?" |
| Public API change | "Add CHANGELOG entry and bump version in `mix.exs`?" |

## QUICK REFERENCE

| Want to… | Use |
|----------|-----|
| Simple change | Describe it (auto-complexity runs) |
| Larger feature | `/phx:plan` → `/phx:work` → `/phx:review` |
| Debug bug | `/phx:investigate` |
| Review code | `/phx:review` |
| Project health | `/phx:audit` |

<!-- ELIXIR-PHOENIX-PLUGIN:END -->
