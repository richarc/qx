# Scratchpad: conditionals-retained-state

## Decisions

- **2026-11-10:** scope is the retention only (ROADMAP item as written). Reduce
  carrying `{reversed_cbits, last_state}`; results unchanged.
- **Research** (research/hex-library-researcher-report.md, BinaryBackend):
  - No new dependency. Benchee is dev-only and measures process heap, which
    cannot see refc binaries.
  - `Process.info(pid, :binary)` summed sizes tracks `shots × 2^n × 8` within
    1–7 %. Process heap stays at 1–3 MB whatever the shot count.
  - Current code, peak MiB: n=10/200 shots 1.59; n=10/400 3.15; n=12/200 6.37;
    n=14/200 25.45 (49 s).
  - Post-fix **proxy** (reduce over repeated `Qx.run(c, shots: 1)`): 0.28 MiB at
    n=10, flat in shots; 0.69 MiB at n=14. Proxy only: re-measure on the real fix.
  - Memory after `run/2` returns is already freed; only a peak poller sees it.

## Current code facts (2026-11-10, main @ 4ed6db4)

- `run_with_conditionals/3` (simulation.ex:174): `for _ <- 1..shots` list of
  `{state, cbits}`; uses all cbits + `List.last/1` state.
- `execute_single_shot/2` (:662) rebuilds the timeline and the complex initial
  state every shot, and calls `seed_rand(nil)` (fresh entropy) every shot.
- `run/2` validates `shots` with `validate_shots!` before either path, so the
  `1..shots` descending-range hazard is already closed.

## Out of scope / discovered

- Hoist `create_instruction_timeline/1` and `real_state_to_complex/1` out of the
  shot loop: invariant per run, one 2^n conversion saved per shot. Small, but it
  touches `execute_single_shot/2`'s signature; candidate follow-up.
- Whole-circuit re-execution per shot (could share the prefix before the first
  measurement). Separate plan.
- Per-shot `seed_rand(nil)`: no reproducible conditional runs. Tied to the
  deferred `seed:` option on `run/2` (user decision 2026-11-08).
- The test-file-guard hook path in `.claude/settings.local.json` was reported
  stale on 2026-11-08 (guard inactive). Not re-checked here.

## Dead-ends

(none yet)

## Implementation notes

- **Red (old code), peak `Process.info(pid, :binary)`:** 1,650,808 B at
  n=10/200 (all states = 1,638,400 B); 6,636,528 B at n=12/200 (6,553,600 B).
- **Real post-fix peak (BinaryBackend, test circuit: H, measure, c_if X, measure):**
  - n=10/200 warm: 304–340 KB; first run in a VM: 720,564 B.
  - n=10/800: 338 KB. n=12/200 warm: 381 KB. n=14/100: 737 KB.
  - n=12/200 as the first run in a fresh VM: 745,140 B, identical in 6 of 6 VMs.
  - So the slack is an absolute ~0.3–0.75 MB (GC-driven), not a number of
    states: 88 states at n=10, 5.6 at n=14. The research proxy (0.28 MiB at
    n=10) under-read the cold case.
- **D3 amended** (user, 2026-11-10): n=10/200 left 1.14× margin, below the
  plan's 1.5× bar. Moved to n=12/200 (threshold 3.28 MB; 4.4× under, old code
  2× over). Test file runs in ~1.6 s.
- The test polls from the test process itself (`receive ... after 1`), so
  there is no separate poller process.
- New test file was written with `Write`; the test-file guard hook did not
  block it (consistent with the stale hook path noted above).

## Review follow-up (2026-11-10, /phx:review → PASS WITH WARNINGS)

- User chose "fix everything". All in the new test file + CHANGELOG:
  - W1: last-shot check now runs 30 times at 8 shots. Mutation check: with
    `Enum.reverse` removed from `run_with_conditionals/3` the test fails
    (restored afterwards).
  - W2: floor assertion `peak_bytes > 2^n * 8` guards a vacuous pass.
  - Suggestions: plan-path removed from the test comment; CHANGELOG no longer
    says "independent of shots"; `renormalize: true | 1` case added;
    deterministic test compares real and imaginary parts; `@tag timeout: 30_000`.
- Not adopted: dropping `//1`; loosening 1.0e-6 (values compared are exact 0/1).
