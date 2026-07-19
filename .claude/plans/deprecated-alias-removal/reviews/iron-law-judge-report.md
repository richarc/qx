# Iron Law Judge Report — feat/deprecated-alias-removal

## Verdict: PASS

All 9 repo Iron Laws (AGENTS.md "IRON LAWS" section) checked. No violations.
This is a pure-deletion diff (three deprecated aliases removed) plus test/doc
adjustments — no kernels, no processes, no dispatch changes, no new deps, as
expected.

## Law-by-law

### Law #6 — Breaking change to declared-public modules requires CHANGELOG + major-version bump
- **Status: SATISFIED, with an explicit and reasonable pre-1.0 SemVer reading.**
- `Qx.StateInit`, `Qx.Math`, and `Qx` are all on the declared-public surface
  (AGENTS.md law #6 list), so the removals are in-scope for the law.
- `CHANGELOG.md:43-53` (`## [Unreleased]` → `### Removed`) names all three
  removed aliases and their canonical replacements:
  `Qx.StateInit.bell_state/0,1,2` → `bell_state_vector/0,1,2`,
  `Qx.StateInit.ghz_state/1,2` → `ghz_state_vector/1,2`,
  `Qx.Math.basis_state/2` → `Qx.StateInit.basis_state/3`,
  `Qx.histogram/1,2` → `Qx.draw_histogram/1,2`. CHANGELOG condition met.
- The law's literal text says "major-version bump (SemVer)". This ships as
  **v0.10** (minor), not v1.0.0. `ROADMAP.md:78-95` (`## v0.10`) explicitly
  invokes the pre-1.0 exception: *"Pre-1.0, so the breaking removals are
  allowed in this minor; the deprecation windows … are all satisfied here."*
  This is a defensible reading of the law's *intent*, not a bypass of it:
  under SemVer itself (spec item 4), the entire 0.y.z line is declared
  unstable and any change may be breaking without a major bump — "major
  version bump" only starts meaning something once a project ships 1.0.0.
  Qx has not (ROADMAP backlog explicitly defers "a 1.0 release and an
  API-stability guarantee" as unscheduled). Applying the law's intent
  (surface a breaking change loudly, don't let it slip out silently) rather
  than its literal SemVer-major wording: the CHANGELOG entry, the named
  deprecation windows, and the dedicated `deprecated_alias_removal_test.exs`
  regression test together satisfy that intent. **Judgment: the ROADMAP's
  stated pre-1.0 policy satisfies Law #6's intent for this repo's actual
  versioning stage; this is not itself a violation.** Recommend the human
  reviewer confirm they're comfortable codifying "pre-1.0 minor breaks
  allowed" as a standing exception the next time Law #6 or AGENTS.md is
  revised, so future reviewers don't have to re-derive this reasoning.

### Law #7 — Public functions raise typed `Qx.*Error`, not raw Nx/Complex/ArgumentError
- **Status: N/A / confirmed no regression.**
- No error-path code changed. `lib/qx/math.ex` and `lib/qx/state_init.ex`
  diffs are deletions only (the removed functions were thin delegators/
  duplicates, not validation or error-raising paths). Remaining functions
  in both files are unchanged in behavior. No new raw `ArgumentError`,
  `Nx`, or `Complex` exceptions introduced or removed from the public
  boundary.

### Law #9 — Dispatch completeness (instruction/message shapes)
- **Status: N/A, confirmed.**
- `lib/qx/simulation.ex` (the dispatch module, `apply_instruction/3` /
  `apply_gate_step/5`) is **not** in the changed-files list and was not
  touched. Nothing in this change adds, removes, or renames an instruction
  shape; `bell_state_vector`, `ghz_state_vector`, `basis_state/3`, and
  `draw_histogram` are all pure state-construction/drawing functions, not
  producers feeding the instruction dispatcher. No dispatch arms affected.

### Law #1 — No `String.to_atom/1` on caller-supplied strings
- **N/A.** No `String.to_atom` calls in any changed file (confirmed by grep
  across `lib/qx.ex`, `lib/qx/math.ex`, `lib/qx/state_init.ex`).

### Law #2 — No process without a runtime reason
- **N/A.** No `GenServer`/`Agent`/`Task` in any changed file.

### Law #3 — Prefer reshape+contraction over gather/select in Nx kernels
- **N/A.** `lib/qx/math.ex`'s `defn` kernels (`kron`, `normalize`,
  `inner_product`, `outer_product`, `apply_gate`, `probabilities`, `trace`)
  are unchanged by this diff — the only change to `math.ex` is the deletion
  of the non-`defn` `basis_state/2` shim. No gather/select patterns touched.

### Law #4 — `defn` must be correct on `Nx.BinaryBackend`
- **N/A.** Same reasoning as #3 — no `defn` kernel touched.

### Law #5 — No host-side loops over `2^n` amplitudes
- **N/A.** `Qx.StateInit`'s remaining `for i <- 0..(dimension - 1)` loops
  (`basis_state/3`, `ghz_state_vector/2`, `w_state/2`) are pre-existing and
  unchanged by this diff; the deletion removed a *duplicate* shim
  (`Qx.Math.basis_state/2`), not a hot path. No new host loop introduced.

### Law #8 — Precision/tolerance targets feasible at `:c64` (float32, ε≈1.2e-7)
- **N/A.** No new tolerance assertions introduced. Test-file changes
  (`state_init_test.exs`, `state_init_vector_test.exs`,
  `deprecated_alias_removal_test.exs`) use `function_exported?/3` existence
  checks and pre-existing probability-tolerance patterns (e.g. `< 0.01`),
  none below the float32 epsilon floor.

## Cross-file consistency check (beyond the 9 numbered laws, informational)

- Confirmed no dangling call sites: grepped the whole repo (`.ex`/`.exs`/
  `.livemd`) for `Math.basis_state/2`-shaped calls — none found.
- `test/qx_manual_test.livemd` calls `Qx.bell_state/1` and `Qx.ghz_state/0`
  (the circuit-returning facades in `Qx.Patterns`/`Qx`) and
  `Qx.draw_histogram/2` — these are the **unaffected** canonical names, not
  the removed `Qx.StateInit` aliases or `Qx.histogram`. No update needed
  there.
- New `test/qx/deprecated_alias_removal_test.exs` directly asserts absence
  of all three removed surfaces (`function_exported?/3` refutes) plus
  presence of the canonical replacements — good regression coverage for
  exactly this Iron Law #6 concern.
