# Scratchpad: `qx-hardware`

Decisions log + dead-end notes for the qx-side of the
`kino-qx-circuit-pipeline` workspace refactor.

## Open decisions (resolve during `/phx:work`)

- [ ] **Portal URL validation strictness.** Carry over kino_qx's host
  allowlist (`{test,api}.qxquantum.com` + localhost), or relax to URI
  scheme check + arbitrary host? Plan currently defaults to the
  relaxed version, with the allowlist deferred to a bd issue if
  security pushes back. Touch points:
  `lib/qx/hardware/config.ex` Phase 2,
  `lib/qx/hardware/portal.ex` Phase 4.
- [ ] **`Qx.RemoteError` removal vs deprecation cycle.** Plan removes
  it outright (pre-1.0, audit `M6` confirmed unused). Alternative:
  keep the module with `@deprecated "Use Qx.Hardware.ConfigError"`
  for one minor cycle. Cost of keeping it = a dead module in the
  generated docs.
- [ ] **`examples/remote/` directory.** Delete entirely, or keep
  with a `README.md` redirect? Plan currently deletes and replaces
  with `examples/hardware/run_on_ibm.exs`.
- [ ] **IBM region allowlist enforcement.** Hard-fail unknown
  regions in `Qx.Hardware.Config.new/1`, or warn + pass through?
  Plan currently hard-fails — simpler, and downstream IBM API will
  reject anyway. Revisit if IBM ships a region between cuts.

## Resolved (locked by interview)

- ✅ **No `@deprecated` cycle for `Qx.Remote`** — interview §1.
  Drop in one release. Pre-1.0 SemVer permits.
- ✅ **`Qx.Hardware.transpile/3` is a public API** — qx owns the
  portal contract for hardware paths (no injected-fn alternative).
  Codebase-scan open question #2 was resolved in the interview's
  favour of "qx owns the portal contract via `Qx.Hardware.Portal`".
- ✅ **`run/3` is synchronous (blocking)** — interview §5. No
  `Task.async` / non-blocking variant.
- ✅ **Input = `%Qx.QuantumCircuit{}` only for `run/3`** — interview
  §6. Hand-authored QASM goes through `submit_qasm/3`.
- ✅ **Status events use literal atoms throughout** — interview §9 +
  Iron Law #1. No `String.to_atom` on any HTTP response body.
- ✅ **Cancellation in qx is best-effort, synchronous, via
  `cancel/2`.** Monitor pattern (`trap_exit` alternative) lives in
  kino_qx land (not this plan).

## Dead-ends to avoid

- ❌ Don't try to keep `Qx.Remote.Config` as an alias shim to the
  new `Qx.Hardware.Config`. The field shapes are incompatible
  (`url, api_key` vs `portal_url, portal_token, ibm_api_key, ...`).
  Shim ≠ migration aid; just complicates the CHANGELOG entry.
- ❌ Don't merge `Qx.Hardware.Portal` and `Qx.Hardware.Ibm` into a
  single client module. Privacy invariant (no token cross-flow)
  is structural — two modules, two configs, two `Req` bases.
- ❌ Don't introduce a GenServer for the poll loop. `Process.sleep`
  in a synchronous library function is the precedent (existing
  `Qx.Remote` does it). Downstream supervision is the caller's job.
- ❌ Don't add `kino` as a `qx` dep "for status events". The status
  callback is a plain function; Kino's `Kino.Frame` rendering is
  exclusively a kino_qx-side concern.

## Cross-plan handoff

This plan is **half** of the `kino-qx-circuit-pipeline` workspace
refactor. The downstream plan
(`kino_qx/.claude/plans/kino-qx-circuit-pipeline/plan.md`) is
blocked on the 0.7.0 hex publish. Sequence:

1. This plan completes → 0.7.0 hex publish.
2. `kino_qx` plan starts; bumps `{:qx, "~> 0.7"}`.
3. Both plans cross-reference in their PR descriptions.

## Audit cross-references

The most recent `/phx:audit` (in flight as of 2026-05-13) raised
findings that intersect this plan. Applied here:

- **arch H1** (`Qx.Validation` raising `ArgumentError`) — do NOT
  copy that anti-pattern into `Qx.Hardware.Config.new/1`. Use the
  new `Qx.Hardware.ConfigError` (Phase 2).
- **arch M6** (`Qx.RemoteError` dead surface) — removed in Phase 7.
- **perf L1** (remote polling: no jitter, no backoff) — consider
  adding jitter to `Qx.Hardware.Ibm.poll_job`'s `Process.sleep`.
  Cheap win; non-blocking on this plan.
- **deps F-D2** (`nx` stale at 0.10.0; 0.11 available) — orthogonal
  to this plan. File as separate bd issue if not already covered.

### 21:43 WARN: verification-runner did not write reviews/verification.md
Manual verification results from Phase 9 of the plan:
- mix compile --warnings-as-errors: clean
- mix format --check-formatted: clean
- mix credo --strict: 719 mods, no issues
- mix test: 689 tests + 229 doctests, 0 failures
- mix coveralls: 78.8% total; hardware modules 75-91%
- mix docs: all Qx.Hardware.* modules render

(verification-runner agent returned a short message but no artifact file)
