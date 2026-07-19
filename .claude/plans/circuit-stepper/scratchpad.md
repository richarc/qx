# Scratchpad: circuit-stepper

Decisions made during planning (2026-07-03). The design doc
(`spec/unified-circuit-stepper-design.md`, amended 2026-07-03) settled the
API shape; these are the implementation-level calls on top of it.

## DECISION: thread explicit :rand state, never seed the caller's process

`perform_single_measurement/3` uses `:rand.uniform/0` (process dict). A
`seed:` option via `:rand.seed/2` would clobber the caller's RNG state, an
invisible side effect in a library (spirit of Iron Law #2). Use
`:rand.seed_s/2` + `:rand.uniform_s/1` with the state threaded through the
stream accumulator. Default (no seed) uses `:rand.seed_s(:exsss)` from
entropy, still without touching the process dict. Test asserts
`:rand.export_seed/0` is unchanged after materialising a seeded stream.

## DECISION: taps keep the MeasurementError contract

Rebuilding the taps "on the stepper" could instead let a measured prefix
sample a trajectory. Rejected: the raise contract shipped to `main` in
24cd1cf with docs and tests days after being designed; silently changing
it again would be a second behaviour change to the same public functions
in one release cycle. Taps guard-then-delegate; the stepper is the way to
observe measured circuits.

## DECISION: per-step probabilities stay eager

`%Qx.Step{}` carries `probabilities` computed per step, O(2^n) per step.
Fine at teaching scale (n <= ~12). Alternative if it ever matters: drop
the field and compute in `Qx.Step.show/1`. Revisit only with bench data;
do not pre-optimise (the v0.11 perf pass is the venue).

## DECISION: not-taken c_if emits one flagged step

Taken blocks emit one step per inner gate with
`condition: {cbit, value, :taken}`. A not-taken block emits a single
`:conditional` step with `:not_taken` and the unchanged state, so a UI can
grey the branch out and the step count still reflects what a reader sees
in the drawing.

## DECISION: Inspect truncates the Dirac string at 4 non-zero terms

Resolved during Phase 1 (2026-07-03). The `Inspect` impl filters terms
with probability > 1.0e-6, shows the first 4, and appends ` + …` when
more remain. `Qx.Step.show/1` stays untruncated; it's the full-detail
view. Constant: `@max_dirac_terms 4` in the `defimpl` in
`lib/qx/step.ex`.

## TRIAGE (review cycle 1, 2026-07-03)

All 3 review agents returned PASS. Fixed in the same cycle: multi-gate
c_if coverage, empty-circuit coverage, renormalize: true acceptance,
show/1-on-measurement coverage, the Inspect sub-threshold Dirac fallback
(now shows the top-4 terms by probability instead of "0.000|00…0⟩" at
the n=20 uniform regime), and an O(2^n) display-cost note in the
Qx.Step moduledoc.

Accepted without change:

- **Taps compute per-step probabilities they discard** (elixir-reviewer
  warning). tap_state/tap_probabilities ride steps/2, which computes
  Math.probabilities per step; only the last step is used. Accepted:
  the plan's risk section already accepts O(2^n)/step for inspection
  APIs, the taps' docs say "use sparingly", and the alternative (a
  probabilities-free stream variant) forks the single execution path
  the plan exists to create. Revisit with bench data in the v0.11 perf
  pass alongside the lazy-probabilities idea above.
- Facade passthrough tests for backend:/renormalize: — defdelegate
  can't diverge; engine tests cover both options.

## DISCOVERED BUG (pre-existing, out of scope): multi-qubit barrier raises

`Qx.barrier(qc, [0, 1])` stores `{:barrier, [0, 1], []}` but
`apply_instruction/3` only handles `:barrier` in the 0-qubit arm, so
`run/2` (and therefore `steps/2`) raises `Qx.GateError: Unsupported
gate: :barrier`. Reproduced on this branch 2026-07-03; the dispatch
code is untouched by circuit-stepper, so it fails on `main` identically.
Recorded in ROADMAP v0.10; fix on its own `fix/barrier-dispatch` branch
(surfaced by testing-reviewer during the circuit-stepper review).

## Deferred / out of scope

- Phase-circle renderer + `Qx.Draw.circuit/2` gate-position metadata +
  kino_qx widget: ROADMAP backlog entry (depends on this plan).
- Calc-mode demotion (`Qx.Register`/`Qx.Qubit` internal): separate v0.10
  item, gated on this plan + qxportal tutorial rewrites (audit 2026-07-03).
- Collapse-and-rotate-back for measure_x/measure_y mid-circuit display:
  doc note only for now (design §4); revisit if tutorial feedback asks.
- `perform_single_measurement`'s host-side 2^n loop: pre-existing,
  scheduled v0.11 (perf CRIT C3). The stream reuses it; do not fix here.
