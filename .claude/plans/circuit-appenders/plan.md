# Circuit-appender surface (v0.11 Additive surface, part 1 · T1-05/07/12)

**Branch:** `feat/circuit-appenders`
**ROADMAP:** v0.11 "Additive surface" (part 1 of 2 — checkbox stays UNCHECKED
until the deferred `feat/qasm-facade-tdg` piece also lands)
**Depth:** comprehensive · **Complexity:** 8 (new public API +3, changes
declared-public `Qx`/`Patterns` surface +3, crosses Operations/Patterns/facade
+3, follows the gate-builder + defdelegate pattern −2)
**Research:** 2 agents (hex-deps → no new dep; patterns-conventions → home,
reframe safety, typed-error contract). Summaries in `research/`, decisions in
`scratchpad.md`.

## Decision

Add two ADDITIVE, non-breaking public builders that APPEND state-prep gates onto
an existing circuit at caller-chosen qubits, and reframe the existing zero-arg
creators as thin wrappers over them (api-design-principles §8 — resolve the
"Patterns mixes two shapes with no appender underneath its creators" tension
before v0.15 building-block work multiplies the creator shape):

- `Qx.Patterns.bell_pair/4` + `Qx.bell_pair/4` facade delegate
- `Qx.Patterns.ghz/2` + `Qx.ghz/2` facade delegate
- reframe `Patterns.bell_state_circuit/1` + `ghz_state_circuit/1`
  (fronted by `Qx.bell_state/1`, `Qx.ghz_state/1`) → thin wrappers.

**This is NEW code → TDD applies** (tests before impl; the docs-sweep was
doctest-free, this is not). Match the v0.11-standardized house doc style:
`@spec` + `## Returns` + `## Raises` + doctest on every new public function.

### Scope

**IN:** `bell_pair/4`, `ghz/2`, their facade delegates, the byte-identical
creator reframe, full docs + tests.
**OUT (→ `feat/qasm-facade-tdg`):** `tdg/2` gate; `to_qasm`/`from_qasm`/
`from_qasm!` facade delegates. **OUT (separate item):** `from_qasm_function/1`
atom-vs-string SemVer change. **OUT (→ "Principles-doc post-review edits"
item):** the `api-design-principles.md §6` family-row edit for prep builders.

### Target signatures

```elixir
# Qx.Patterns (fully documented tier-2 entry points)
@spec bell_pair(QuantumCircuit.t(), non_neg_integer(), non_neg_integer(),
        bell_state_type()) :: QuantumCircuit.t()
def bell_pair(circuit, q0, q1, which \\ :phi_plus)      # 4 which-clauses + OptionError fallback

@spec ghz(QuantumCircuit.t(), qubits()) :: QuantumCircuit.t()
def ghz(circuit, qubits)                                # H on first + cx_chain; guard len<2

# Qx facade
@spec bell_pair(circuit(), non_neg_integer(), non_neg_integer(),
        Patterns.bell_state_type()) :: circuit()
defdelegate bell_pair(circuit, q0, q1, which \\ :phi_plus), to: Patterns
@spec ghz(circuit(), Patterns.qubits()) :: circuit()
defdelegate ghz(circuit, qubits), to: Patterns
```

Gate sequences (verified byte-identical to current creators):
- bell_pair :phi_plus → `h(q0) cx(q0,q1)` · :phi_minus → `x(q0) h(q0) cx(q0,q1)`
  · :psi_plus → `x(q1) h(q0) cx(q0,q1)` · :psi_minus → `x(q0) x(q1) h(q0) cx(q0,q1)`
- ghz → `h(first) |> cx_chain(qubits)`

---

## Phase 1 — `Qx.Patterns.bell_pair/4` (TDD)

- [x] [P1-T1] **Tests first** (`test/qx/patterns_test.exs`, new `describe
      "bell_pair/4"`): append semantics onto a NON-empty/offset circuit (e.g.
      `new(3) |> bell_pair(1, 2, :phi_plus)` → instructions `[{:h,[1]},{:cx,[1,2]}]`);
      all 4 `which` sequences asserted as exact instruction lists; default
      `which` = `:phi_plus`; a doctest-shaped example; typed errors —
      `bell_pair(c, 0, 0, :phi_plus)` → `Qx.QubitIndexError` (equal via `cx`),
      out-of-range qubit → `Qx.QubitIndexError`, `bell_pair(c,0,1,:bogus)` →
      `Qx.OptionError`. Run — MUST FAIL (function undefined).
- [x] [P1-T2] Implement `Patterns.bell_pair/4`: default head + 4 `which`
      clauses composing `Operations.x/h/cx` in the verified order, + a final
      fallback clause `raise Qx.OptionError, {:which, which, "Expected
      :phi_plus, :phi_minus, :psi_plus, or :psi_minus."}` (byte-match the
      current `bell_state_circuit` fallback message). NO own index validation —
      composed ops raise `Qx.QubitIndexError`. Full `@doc` (`## Parameters`,
      `## Returns`, `## Raises`, doctest) + `@spec`. Tests + doctest pass;
      `mix compile --warnings-as-errors`.
- [x] [P1-T3] `Qx.bell_pair/4` facade delegate (`lib/qx.ex`, near `cx_chain`):
      `@spec` + `@doc` (Returns/Raises) + `defdelegate ... to: Patterns`. Add a
      facade doctest + a "delegates to Patterns" test mirroring the existing
      backward-compat assertions. Compile clean.

## Phase 2 — `Qx.Patterns.ghz/2` (TDD)

- [x] [P2-T1] **Tests first** (`describe "ghz/2"`): append onto offset circuit
      (`new(4) |> ghz(1..3)` → `[{:h,[1]},{:cx,[1,2]},{:cx,[2,3]}]`); list AND
      range inputs; default/edge — `ghz(c, [])` and `ghz(c, [0])` →
      `Qx.QubitCountError` (len < 2, see scratchpad decision); out-of-range
      qubit → `Qx.QubitIndexError` (via `h`/`cx_chain`); a doctest. Run — FAIL.
- [x] [P2-T2] Implement `Patterns.ghz/2`: normalise via the existing private
      `qubits_to_list/1`; `[] | [_]` → `raise Qx.QubitCountError` (reason tuple
      giving a clear "GHZ needs ≥ 2 qubits" message); `[first | _] = list` →
      `circuit |> Operations.h(first) |> cx_chain(list)`. Full `@doc` + `@spec`.
      Tests + doctest pass; compile clean.
- [x] [P2-T3] `Qx.ghz/2` facade delegate (`lib/qx.ex`): `@spec` + `@doc`
      (Returns/Raises) + `defdelegate ... to: Patterns` + facade doctest +
      delegate test. Compile clean.

## Phase 3 — Reframe creators as byte-identical wrappers

- [x] [P3-T1] **Invariant tests first**: add reframe-equality assertions —
      `bell_state_circuit(w) == new(2) |> bell_pair(0,1,w)` (instruction lists
      equal) for all 4 `w`; `ghz_state_circuit(n) == new(n) |> ghz(0..(n-1))`
      for n ∈ {2,3,5}. These PIN the invariant before the refactor. Confirm the
      EXISTING `bell_state`/`ghz_state` tests + doctests are NOT modified.
- [x] [P3-T2] Reframe `Patterns.bell_state_circuit/1`: collapse the 4 explicit
      `which` clauses + fallback into `def bell_state_circuit(which \\
      :phi_plus)` head + `def bell_state_circuit(which), do: QuantumCircuit.new(2)
      |> bell_pair(0, 1, which)` (bell_pair now owns the which-dispatch AND the
      OptionError fallback — byte-identical error). Run FULL suite: existing
      bell_state tests/doctests pass UNCHANGED.
- [x] [P3-T3] Reframe `Patterns.ghz_state_circuit/1`: change ONLY the happy-path
      body to `QuantumCircuit.new(num_qubits) |> ghz(0..(num_qubits - 1))`;
      **KEEP** the `n >= 2` guard + the two `Qx.QubitCountError` fallback
      clauses unchanged (preserves the exact creator error behaviour — the
      appender's own guard is never reached for valid n). Full suite passes
      unchanged.

## Phase 4 — CHANGELOG & verify

- [x] [P4-T1] CHANGELOG `[Unreleased]` **Added**: `Qx.bell_pair/4` and
      `Qx.ghz/2` circuit appenders (+ note the creators are now thin wrappers,
      no behaviour change). Non-breaking, no version bump. Note in scratchpad
      that the §6 family-row + the qasm/tdg piece + the ROADMAP tick remain
      pending.
- [x] [P4-T2] Full gate: `mix compile --warnings-as-errors && mix format
      --check-formatted && mix credo --strict && mix test`.
- [x] [P4-T3] `mix docs` warning count ≤ baseline (36) — the new doctests +
      `@spec` type refs autolink; stash-diff the warning LISTS if the count
      moves (per CLAUDE.md docs discipline / the docs-sweep solution doc).

## Iron Laws check

- **#6 (public API):** purely ADDITIVE — two new functions + facade delegates;
  the creator reframe is a pure refactor with byte-identical output/errors
  (Phase-3 invariant tests enforce this). CHANGELOG **Added** entry; no version
  bump (release is tag-gated). No existing signature/return/spec changed.
- **#7 (typed errors):** `bell_pair` bad `which` → `Qx.OptionError`; `ghz`
  short list → `Qx.QubitCountError`; all qubit-index misuse → `Qx.QubitIndexError`
  via the composed `h`/`x`/`cx` (verified — no raw error escapes).
- **#9 (dispatch completeness):** n/a — emits only existing instruction shapes
  (`:h`/`:x`/`:cx`) already handled by every consumer; no new instruction kind.
- **TDD:** every new public function gets failing tests before impl (Phases
  1–2); the reframe gets invariant tests before the refactor (Phase 3).

## Risks

1. **Reframe drift** — the whole non-breaking claim rests on byte-identical
   output. Mitigation: Phase-3 T1 invariant tests + running the UNMODIFIED
   existing bell_state/ghz_state suite as the tripwire.
2. **`ghz` minimum-length semantics** (empty/single → raise vs allow) — a real
   API decision; default is **≥2 / `QubitCountError`** (scratchpad). Cheap to
   flip if the reviewer disagrees.
3. **Docs-warning autolink** — new doctests/specs feed ex_doc; Phase-4 T3 count
   gate + stash-diff is the tripwire (docs-sweep precedent: held at 36).

## Self-check (comprehensive)

- *What could make this break unexpectedly?* Only the reframe — covered by
  invariant tests + the frozen existing suite.
- *What did research explicitly rule out?* A new hex dep (none); bespoke index
  validation (composed ops already raise typed errors).
- *What's deliberately deferred?* tdg/2 + QASM facade (`feat/qasm-facade-tdg`),
  the §6 family-row doc edit, and the ROADMAP tick — all recorded in scratchpad.
