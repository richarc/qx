# Iron Law Judge Report — `docs/manual-test-livebook`

## Scope note

This agent has no Bash/git access, so `git --no-pager diff main --stat` could
not be run directly. Verification below is based on reading the current
content of `test/qx_manual_test.livemd`, `CHANGELOG.md`, and `ROADMAP.md`,
cross-checked against the claims in the prompt. No `lib/**/*.ex` file
content was found to be inconsistent with an unchanged library surface
(35 lib files enumerated, all pre-existing tier-1/2/3 modules — no new
module, no surface-shape anomaly). Confidence on "zero lib/ files in
diff" is REVIEW (asserted, not independently git-diffed) rather than
DEFINITE.

## Summary

- Files inspected: `test/qx_manual_test.livemd`, `CHANGELOG.md`, `ROADMAP.md`
- Iron Laws in scope: #6 (public API surface / teaching-surface contract), #8 (tolerance)
- Violations found: 0 blocking; 1 minor note (non-blocking)

## Check 1 — Iron Law #6 (no library surface change / teaching-surface contract)

- No `lib/` files appear in scope of this change per the task description; content review found nothing inconsistent with that (see Scope note). **Confidence: REVIEW** (not independently git-diffed).
- Grepped the livemd for calc-mode usage: `Qx\.Qubit|Qx\.Register\b` → **0 matches**. No calc-mode `Qx.Qubit`/`Qx.Register` cells anywhere in the file. PASS.
- Tier-2 escape hatch: the only non-facade call is `Qx.Export.OpenQASM.from_qasm_function/1` (line ~787, section 9 "Code generation: from_qasm_function/1"), explicitly documented in the notebook prose as reachable only via `Qx.Export.OpenQASM` (no `Qx.*` facade delegate exists — CHANGELOG confirms `from_qasm_function/1` "remains on `Qx.Export.OpenQASM` pending a separate atom-vs-string change"). This matches the one documented tier-2 escape. PASS.
- Deprecation-labelled superposition note: section 4 "Equal superposition (replacement for the deprecated preset)" explicitly states `Qx.superposition/1` is deprecated and shows the replacement idiom `Qx.create_circuit(1) |> Qx.h_all()`. Correctly labelled as deprecated, not taught as current API. PASS.
- All other cells use tier-1 `Qx.*` facade calls only (`Qx.create_circuit`, `Qx.h/x/y/z/s/sdg/t/tdg/rx/ry/rz/phase/u`, `Qx.cx/cz/swap/iswap/cp/ccx/cswap`, `Qx.get_state/get_probabilities/draw_bloch/draw_histogram/draw_circuit/draw_counts/draw_state`, `Qx.bell_state/ghz_state/bell_pair/ghz/cx_chain/h_all`, `Qx.measure/measure_x/measure_y/measure_z/run/c_if`, `Qx.steps`, `Qx.Step.show`, `Qx.to_qasm/from_qasm!`). No off-contract teaching found.

**Verdict: PASS** (REVIEW confidence on the "no lib/ files" leg only, due to tool access limits).

## Check 2 — Iron Law #8 (tolerance / feasibility at c64 float32)

All numeric `# Expected:` claims reviewed:
- Amplitudes quoted as `≈ 0.707+0i`, `≈ -0.707+0i` (§4 presets, √2/2 values) — fine, no sub-ε claim.
- Probabilities: `P=0.5`, `P=1.0`, `P=0.0`, `P=0.25`, interference set `≈0.625/0.125/0.125/0.125` (§2 CP gate) — all comfortably above float32 ε (~1.2e-7).
- Teleportation capstone signature: `P(|1⟩) = sin²(π/3) = 0.75` exact fraction claim, and the seeded-state check uses `Complex.abs(x) > 1.0e-6` as a **guard threshold** to find the nonzero amplitude pair — not an equality/tolerance assertion below 1.0e-6, and 1.0e-6 itself sits above float32 ε, consistent with the Iron Law #8 guidance ("guard-fires test... not an absolute sub-ε number"). PASS.
- No cell asserts equality tighter than 1.0e-6 anywhere in the file.

**Verdict: PASS.**

## Check 3 — ROADMAP integrity

- `## v0.11: API Review Follow-Through` section: **9/9 items checked** (`- [x]` at lines 25, 26, 27, 28, 29, 30, 31, 32, 33 — no unchecked `- [ ]` items in the section). Confirmed count matches the "9/9" claim.
- Final ticked item's text (line 33): *"Modernise or retire `test/qx_manual_test.livemd`: **modernised** (user call, 2026-07-12) — rewritten onto the tier-1 circuit surface (calc-mode `Qubit.*` cells gone; real `u/5`; deprecated `superposition/1` replaced) and expanded from a gate gallery into a full manual test suite: five new sections (Step-Through incl. seeded trajectory, Patterns & Appenders at offset qubits, OpenQASM round-trip incl. native `tdg` + `from_qasm_function` codegen, Measurement Bases, and a Quantum Teleportation capstone verified at state level). All 58 cells run headlessly clean; checkable `# Expected:` claims asserted numerically before being written."*
  - "modernised, not retired" — accurate; the file was rewritten, not deleted. Correct verb choice.
  - "5 new sections" — verified: sections 7 (Step-Through Inspection), 8 (Composite Patterns & Appenders), 9 (OpenQASM Round-Trip), 10 (Measurement Bases), 11 (Capstone: Quantum Teleportation) are indeed new relative to what a "gate gallery" predecessor would have had (sections 1–6 cover single/two/three-qubit gates, entanglement/presets, circuit diagrams, measurement/conditional — the gallery scope). Count matches.
  - "headless verification" — claim of "All 58 cells run headlessly clean" cannot be independently executed by this agent (no Bash/mix access), but is internally consistent with the CHANGELOG's matching claim (see Check 4). Confidence: REVIEW (asserted, not re-run).

**Verdict: PASS** (with REVIEW-level confidence on the unexecuted headless-run claim, which this agent cannot independently verify).

## Check 4 — CHANGELOG Documentation entry vs actual file content

- CHANGELOG (`### Documentation`, lines 122–134) states the file was "rewritten onto the tier-1 circuit surface," §1's Bloch cells moved off calc-mode `Qx.Qubit`, superposition preset replaced, S†/T† round-trip cells added, and lists the same five new section names as ROADMAP. Matches file content 1:1 (verified against Check 1 and Check 3 section names).
- Cell count: CHANGELOG says **"All 58 cells verified headlessly."** Grep of the actual file for ` ```elixir ` fences returns **59** occurrences total. Reconciled: 59 total code cells = 1 `Mix.install` **setup** cell (not a testable/demonstrative cell) + 58 content/demonstration cells with `# Expected:` assertions. This is consistent with "58 cells" referring to the test-suite content cells, excluding the environment-setup cell. **Not a discrepancy**, but the CHANGELOG/ROADMAP wording is slightly ambiguous (doesn't explicitly say "58 of 59, excluding setup") — flagged as a minor documentation-clarity note, not a violation.

**Verdict: PASS** (minor non-blocking clarity note on the 58-vs-59 cell-count wording).

## Findings Table

| # | Check | Verdict | Confidence |
|---|-------|---------|------------|
| 1 | Iron Law #6 — surface/teaching contract | PASS | REVIEW (lib/ diff not independently git-verified); DEFINITE on grep-for-calc-mode and escape-hatch checks |
| 2 | Iron Law #8 — tolerance feasibility | PASS | DEFINITE |
| 3 | ROADMAP v0.11 9/9 + tick text accuracy | PASS | LIKELY (headless-run claim un-replayable by this agent) |
| 4 | CHANGELOG Documentation entry vs file | PASS | LIKELY (58/59 cell-count reconciliation is inferred, not stated explicitly in the doc) |

## Overall Verdict: PASS — no blocking violations found.

Non-blocking suggestion: consider clarifying the CHANGELOG/ROADMAP "58 cells" wording to explicitly note it excludes the `Mix.install` setup cell (59 total `elixir` code fences in the file), to preempt exactly this kind of audit ambiguity.
