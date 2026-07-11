# Qx — core quantum-computing library

> **Workspace context.** This repo lives inside the [`qxquantum`](../CLAUDE.md)
> multi-root workspace alongside [`qxportal/`](../qxportal/CLAUDE.md) and
> [`kino_qx/`](../kino_qx/CLAUDE.md). Each repo is independent — its own
> git remote, branches, PRs, releases, and CI. Cross-repo changes ship as
> separate PRs in each repo: land upstream (here) first, then bump the
> dependency downstream. See `../CLAUDE.md` for the shared development model.
>
> **Stack:** Pure Elixir library (no Phoenix / Ecto / LiveView / Oban).
> The full development lifecycle (plan → work → review → verify → release)
> is driven by the `/elixir-phoenix` plugin (`/phx:*` skills). All work —
> features and bug fixes alike — lives in `.claude/plans/<slug>/plan.md`.
>
> **`bd` (beads) is deprecated.** Existing `.beads/` issues are left in
> place for later extraction; do not create new `bd` issues and do not
> rely on `bd` for tracking. Out-of-scope work is noted in the plan's
> `scratchpad.md` or in `ROADMAP.md`.
>
> *(This file is `AGENTS.md`; `CLAUDE.md` in this folder is a symlink to it.)*

<!-- usage-rules-start -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

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

## Development Workflow

One path for all work — features and bug fixes alike. The plan file at
`.claude/plans/<slug>/plan.md` is the single source of truth. The
`/elixir-phoenix` plugin drives every stage; see the
**Elixir Plugin — Mandatory Procedures** block at the end of this file
for the complexity routing and Iron Laws the plugin enforces.

**No pull requests.** There is one human developer/reviewer.
`/phx:review` is the **merge gate** that replaces a PR review (see
below). Pushing branches and `main` is **backup only** — pushing never
publishes. The **only** release gate is a deliberate version tag (see
**Release**).

| Step | Command | What it does |
|------|---------|--------------|
| 0 | `git checkout -b feat/<slug>` (or `fix/<slug>`) from `main` | Create the working branch |
| 1 | `/phx:plan <description>` | Produces `.claude/plans/<slug>/{plan,scratchpad}.md` (auto-complexity routing; `/phx:quick` for &lt;50-line single-file changes) |
| 2 | `/phx:work .claude/plans/<slug>/plan.md` | Implements phase by phase; verify after each phase. Cross-repo deps stay `{:dep, path: "../<repo>"}` during dev |
| 3 | `/phx:verify` | Optional — explicit compile/format/credo/test gate after manual fixes |
| 4 | `/phx:review` | **Merge gate.** Parallel specialist agents produce a verdict. Must be PASS (or all findings triaged) before merge |
| 5 | `/phx:triage` | When review yields ≥ 5 findings — filter, then fix (loop step 2) |
| 6 | `git push -u origin <branch>` | Backup only — no PR, no release. Push whenever; lose-nothing insurance |
| 7 | merge to `main` — **only after `/phx:review` PASS** | `git checkout main && git merge --squash <branch> && git commit` (one clean commit per change). The human authorizes this |
| 8 | tick the matching ROADMAP item in that commit | Required — the release trigger reads ROADMAP check-state |
| 9 | `git push origin main` then `git branch -d <branch>` | Keeps `origin/main` truthful (still no release); clean up the branch |
| 10 | `/phx:compound` | Capture solved patterns as searchable docs |
| 11 | iterate steps 0–10 | One ROADMAP item per cycle |
| 12 | **Release** (below) | Only when a ROADMAP `## v0.X` section is fully checked |

### The merge gate (replaces the PR review)

For a single developer, `/phx:review` *is* the quality boundary a PR
used to provide — the rigorous self-check before code enters `main`.
Code does **not** merge until `/phx:review` is **PASS**, or every
finding is triaged (step 5) and resolved. The human authorizes the
merge: the agent runs the review, reports the verdict, and stops — it
does not squash-merge unreviewed work to `main`. There is no GitHub PR
and no second reviewer; the gate is the review verdict, not a PR page.

For end-to-end with no agent checkpoints, use `/phx:full` instead of
steps 2–5. It still stops at the merge gate for your authorization.

### TDD Rules (enforced by hook + instruction)

1. Tests written before implementation code — always
2. Existing tests never modified without explicit human approval (PreToolUse hook enforces this)
3. Newly written tests must fail before implementation begins
4. **Every module with `iex>` examples in its `@doc`/`@moduledoc` MUST have a
   matching `doctest <Module>` directive in a test module.** Doctests are
   opt-in per module — without the directive ExUnit never runs them, so they
   render fine in `mix docs` and look like coverage while being silently
   unverified (a wrong expected value stays green). Note `defdelegate` does
   **not** carry the target module's doctests: a facade needs its own
   `doctest Facade` for facade-level examples, and the target still needs
   `doctest Target`. When adding a doctest, confirm the module's doctest count
   in `mix test <file>` output actually increases. See
   `.claude/solutions/testing-issues/missing-doctest-directive-silent-uncovered-doctests-qx-patterns-20260711.md`.

### Branch Strategy

- **Feature branches**: `feat/<slug>`; **bug-fix**: `fix/<slug>` — slug matches `.claude/plans/<slug>/`
- **Branch creation**: by the user at step 0 (before `/phx:plan`)
- **Merge**: locally with `git merge --squash` after `/phx:review` PASS; `git branch -d` after
- Push branches to origin freely for backup — pushing **never** triggers a release

### Lifecycle

```
ROADMAP item → git branch → /phx:plan → /phx:work → /phx:verify
            → /phx:review  ⟪ MERGE GATE: PASS or all findings triaged ⟫
            → git merge --squash → main → ROADMAP check-off → git push origin main
            → /phx:compound → loop
            ⟂ release ONLY on a deliberate version tag (see Release)
```

The merge gate is a hard stop for the agent: run `/phx:review`, report
the verdict, and wait for the human to authorize the merge.

### Release (the only publish gate)

Pushing branches or `main` never publishes — releases are
**tag-triggered** (`release.yml` fires on `vX.Y.Z`). Cut a release only
when a ROADMAP `## v0.X` section is fully checked:

1. Bump `version:` in `mix.exs` and add the `CHANGELOG.md` `[0.X.Y]` section.
2. **Flip any `{:dep, path: "../<repo>"}` → the published hex version**
   (e.g. `{:qx, "~> 0.7", hex: :qx_sim}`) and re-run `/phx:verify`.
   Shipping a path dep = an uninstallable package. (Qx is upstream and
   normally has no sibling path deps; this is the workspace-wide rule.)
3. Invoke the `release-manager` agent (or follow `RELEASE.md`): tag
   `vX.Y.Z` and push the tag → the workflow publishes Hex + the GitHub
   Release. This tag push is the single, deliberate release action.

### Hook: Test File Guard

A `PreToolUse` hook in `.claude/settings.local.json` hard-blocks any `Edit` or `Write` tool call
targeting a file matching `*_test.exs` or `*/test/*`. If you see a block message, stop, explain
the intended change to the user, and wait for explicit approval before proceeding.

Note: The hook does not cover `Bash` tool calls (e.g. `sed -i`). The instruction above is the
backstop for that path.

## Issue & Work Tracking

`bd` (beads) is **deprecated** in this repo. The existing `.beads/`
database is retained for later extraction — do **not** create new `bd`
issues, run `bd dolt push`, or rely on `bd` for tracking.

Tracking now lives entirely in plan files and the roadmap:

- **Active work** → `.claude/plans/<slug>/plan.md` checkboxes (the state).
- **Open decisions / dead-ends** → `.claude/plans/<slug>/scratchpad.md`.
- **Out-of-scope or discovered work** → note it in the active plan's
  `scratchpad.md`, or add a line to `ROADMAP.md` under the appropriate
  version section.
- **Roadmap quality targets** (e.g. "test coverage to 80%") → tracked as
  `ROADMAP.md` checklist items, not `bd` issues.
- Do **not** use `TodoWrite`, `TaskCreate`, or markdown TODO lists for
  ongoing tracking — the plan file is the single source of truth.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **Capture out-of-scope work** discovered during the session — add it to the active plan's `scratchpad.md` or to `ROADMAP.md`.
2. **Update the active plan** - ensure `.claude/plans/<slug>/plan.md` checkboxes reflect what's actually done; record open decisions in `scratchpad.md`.
3. **Run quality gates** (if code changed) - `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test`.
4. **Check off ROADMAP** - if a roadmap item completed this session, flip its `- [ ]` to `- [x]` and commit.
5. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
6. **Clean up** - Clear stashes, prune remote branches
7. **Verify** - All changes committed AND pushed
8. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

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
| 4+ files or crosses module boundaries (Calc / Operations / Simulation / Draw / Hardware) | +3 |
| New domain concept (new gate, new sim mode, new visualization) | +3 |
| Follows existing pattern | -2 |
| Touches `defn` / Nx kernels in `lib/qx/calc*.ex` | +3 |
| Changes public API of any declared-public module (the Iron Law #6 surface: `Qx`, `Qx.QuantumCircuit`, `Qx.Operations`, `Qx.Simulation`, `Qx.SimulationResult`, `Qx.Step`, `Qx.StateInit`, `Qx.Patterns`, `Qx.Math`, `Qx.Hardware`, `Qx.Hardware.Config`, `Qx.Export.OpenQASM`, `Qx.Draw`) | +3 |
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
1. NO `String.to_atom/1` on caller-supplied strings — atom-table exhaustion. Use `String.to_existing_atom/1` or keep strings. **This includes `Module.concat/1`, `:erlang.binary_to_atom/2`, and `:erlang.list_to_atom/1`** — they intern immediately and unconditionally, so building a module/atom from a *parse- or request-derived* name (a generated module name, user identifier, or hash of input) is the same hazard wearing a different name. Ask: **is the set of distinct inputs bounded?** Unbounded → one permanent, non-GC'd atom per distinct input → table exhaustion → BEAM crash (a DoS surface for parsers/transpilers/codegen). "The atom will exist later anyway once the source compiles" is NOT a license to intern it eagerly now — prefer letting `Code.compile_string/1` mint the module atom at load time, or `Module.safe_concat/1` (raises unless the atom already exists). See `.claude/solutions/security-issues/eager-atom-intern-from-generated-name-unbounded-qx-openqasm-codegen-20260712.md`.
2. NO process (GenServer / Agent / Task started under a supervisor) without a runtime reason. Qx is a *library*; processes force callers to supervise. Justify with: concurrency, isolated state, or fault isolation.

**Nx kernels (`lib/qx/calc*.ex`, any `defn`)**
3. PREFER reshape + tensor contraction over `Nx.take` + `Nx.select` gather/mask patterns. Gathers don't fuse and double the work. If gather is unavoidable, leave a one-line comment saying why.
4. `defn` functions MUST be correct on `Nx.BinaryBackend` (the default when EXLA isn't loaded). No EXLA-only assumptions.
5. NO host-side loops over `2^n` amplitudes. Vectorise with Nx primitives.
8. PRECISION/TOLERANCE targets MUST be feasible at the runtime float width. Qx states are `:c64` (complex **float32**, ε≈1.2e-7): a norm/equality/tolerance target below ~`1.0e-6` (e.g. `1.0e-10`) is unreachable even immediately after `Qx.Math.normalize/1`. Do NOT specify or assert sub-epsilon tolerances; if a plan/AC demands one, surface it with measured data and amend before implementing (don't silently pick a new number). Express long-circuit norm guarantees as *relative* (renormalized drift < un-renormalized) or as a guard-fires test — not an absolute sub-ε number. Reuse `Qx.Math.normalize/1` + `Qx.Validation.validate_normalized!/2`; do NOT hand-roll a norm-form assertion. Any resulting dev/test host sync (e.g. `Nx.to_number`) MUST be compile-gated out of `:prod` via `Application.compile_env/3` (see Nx #5). (Numbered 8 to preserve existing cross-references to laws #6/#7.)

**Dispatch completeness (instruction/message shapes)**
9. Every instruction shape a producer can emit MUST have a matching consumer dispatch arm, verified by tracing a real producer output into the dispatch by hand — and covered by at least one *execution* test (`run/2` or `steps/2`); construction, drawing, and export tests do not count. A special-case arm for a shape no public API can produce is a MISSING arm wearing a comment, not coverage: it reads as handled while the real shapes fall through (the 2026-07-03 barrier bug — `apply_instruction/3` no-op'd `{:barrier, [], []}`, which nothing emits, while every producer's `{:barrier, qubits, []}` raised `Qx.GateError` for four releases). When adding or reviewing an instruction kind, grep the producers (`Qx.Operations`, `Qx.Patterns`, `lib/qx/export/openqasm/lowering.ex`) for the shapes they actually emit; DELETE unreachable special-case arms rather than leaving them as false evidence. Review check: for any instruction handled in exactly one arity/shape arm of a dispatch, confirm that arm's shape is producible. See `.claude/solutions/phoenix-issues/dead-special-case-masks-missing-dispatch-arm-qx-simulation-20260703.md`.

**Public API surface**
6. Breaking changes to any **declared-public** module REQUIRE a CHANGELOG entry and a bump of the version component that signals breakage (SemVer): the **major** version once ≥ 1.0.0; while < 1.0.0 the **minor** version plays that role, per Hex `~>` semantics (`~> 0.10` pins `< 0.11.0` — the v0.10.0 calc-mode demotion shipped correctly as a minor bump). Patch releases (0.x.PATCH) must never break. The declared public surface is `Qx`, `Qx.QuantumCircuit`, `Qx.Operations`, `Qx.Simulation`, `Qx.SimulationResult`, `Qx.Step`, `Qx.StateInit`, `Qx.Patterns`, `Qx.Math`, `Qx.Hardware`, `Qx.Hardware.Config`, `Qx.Export.OpenQASM`, `Qx.Draw`, `Qx.Draw.Image`, and `Qx.Draw.StateTable` — README and every tutorial alias-import these as primary surface. `Qx.StateInit` and `Qx.Math` are **trimmed** (v0.11 tier trim): the supported surface is `StateInit.basis_state/2,3` and `Math.normalize/1` + `Math.probabilities/1`; every other function in those two modules is `@deprecated` and will be removed at 1.0 (still working until then — removing one earlier is a breaking change). Everything else is internal (`@moduledoc false`, no stability guarantee): `Qx.Validation`, `Qx.Qubit` and `Qx.Register` (the calc engine, demoted v0.10 — state inspection is `Qx.steps/2` + `Qx.Step.show/1` in circuit mode), `Qx.Behaviours.QuantumState` (demoted v0.11 per finding R-13), the `Qx.Draw.SVG.*` and `Qx.Export.OpenQASM.*` sub-modules, and `Qx.Hardware.Ibm` / `Qx.Hardware.Portal`. The typed `Qx.*Error` exceptions are part of the public contract even though `Qx.Validation` (which raises them) is not.
7. Public functions raise typed `Qx.*Error` (`Qx.QubitIndexError`, `Qx.GateError`, etc.) on misuse. Do not let raw `Nx` / `Complex` / `ArgumentError` leak across the API boundary — route through `Qx.Validation`.

## VERIFICATION — MANDATORY after code changes

After ANY code change, before presenting results:

```
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict
```

Offer `mix test` after meaningful changes. Offer `mix bench` (alias in `mix.exs`) after touching `lib/qx/calc*.ex`, `lib/qx/gates.ex`, or `lib/qx/simulation.ex`.

Doc-surface demotions (`@moduledoc false` on a public module, or removing public docs) gate on the `mix docs` warning count: record the baseline before the flip, require ≤ baseline after, and treat the grouped warning sites as the worklist. A source grep of doc strings undercounts — it misses doctest bodies, `@spec` types, and README/CHANGELOG extras, which all autolink. See `.claude/solutions/architecture-issues/hidden-module-doc-refs-warning-sweep-qx-calc-mode-20260703.md`.

When the count MOVES, diff the warning **lists**, not the counts: capture `mix docs 2>&1 | grep "warning:" | sort | uniq -c` before (via `git stash push -- lib/ test/` + recompile) and after, and `diff` the two — counts gate, diffs diagnose (html+epub double-count: Δ2 ≈ one real site). And whenever doc prose gains a function reference (deprecation messages, See-Also blocks, moduledoc rewrites), grep the named function's definition FIRST — plans can prescribe phantom pointers, and ex_doc's autolinker is the only tool in the pipeline that resolves doc-prose references (compile/credo/tests all stay silent). See `.claude/solutions/architecture-issues/docs-warning-stash-diff-catches-phantom-pointer-qx-stateinit-20260708.md`.

Do NOT present code as complete until verification passes.

## POST-ACTION — Offer follow-ups

| After | Offer |
|-------|-------|
| Bug fix | "Capture as lesson with `/phx:learn-from-fix`?" |
| Review verdict | "Triage findings with `/phx:triage`?" |
| Merge to `main` | "Capture solved patterns with `/phx:compound`?" |
| Nx kernel change | "Run `mix bench` to confirm no regression?" |
| Public API change | "Add CHANGELOG entry and bump version in `mix.exs`?" |
| ROADMAP version section now fully checked | "Run release-manager agent to publish to Hex.pm + GitHub?" |

## QUICK REFERENCE

| Want to… | Use |
|----------|-----|
| Simple change (&lt;50 lines, 1 file) | `/phx:quick` (or describe it — auto-complexity runs) |
| Feature or bug fix (full chain) | branch → `/phx:plan` → `/phx:work` → `/phx:verify` → `/phx:review` (**merge gate: PASS/triaged**) → `git merge --squash` → `main` → ROADMAP tick → `git push origin main` → `/phx:compound` |
| One-shot, low-risk | `/phx:full`, then it stops at the `/phx:review` merge gate for your authorization |
| Debug a bug (root cause) | `/phx:investigate` |
| Review code | `/phx:review` |
| Verify changes | `/phx:verify` |
| Project health | `/phx:audit` |
| Release | `release-manager` agent (when ROADMAP version fully checked) |

## Roadmap & Release Triggers

- `ROADMAP.md` is the strategic plan. Each item maps to a plan slug (`(plan: <slug>)`); items without a plan yet are plain checklist lines.
- After every merge to `main`, tick the matching ROADMAP item in that commit. Don't skip this — the release trigger reads ROADMAP check-state.
- When a `## v0.X — …` section in ROADMAP.md has all items checked, that's the cue to invoke the `release-manager` agent. Don't release on time-based cadence; release when the milestone is actually complete.

<!-- ELIXIR-PHOENIX-PLUGIN:END -->
