# circuit-helpers — open decisions & dead-ends

## Decisions taken (no clarifying questions per session policy)

- **Scope**: Standard (7 helpers). Defer `mcx`, `compose`, `inverse`, QFT, Grover diffuser, range variants, gate-function overloading.
- **Module**: New `Qx.Patterns`. Rejected: extending `Qx.Operations` (different category — multi-instruction); a generic `apply_gate/3` (less discoverable than explicit `_all`).
- **Naming**: `_all` suffix. Rejected: Qiskit-style overloading of `Qx.h/2` to accept lists/ranges (changes error behavior for non-integer arg, less discoverable).
- **`measure_all` semantics**: Raise `Qx.ClassicalBitError` (via inherited `add_measurement/3` check). Rejected: auto-grow classical register (mutates circuit shape unexpectedly).
- **`cx_chain` semantics**: Linear chain `cx(q[i], q[i+1])`. Rejected: star-from-q[0] (`cx(q[0], q[i]) for i in 1..n-1`) — that's what GHZ-state circuit prep uses; revisit only if a real second use case surfaces. Empty / singleton list is a no-op.
- **Version**: ~~0.8.0 → 0.8.1~~ → **Ships in 0.8.0** (user redirect: "make this change part of v0.8 not v0.8.1"). 0.8.0 is committed on `main` but not yet tagged via `release-manager`; circuit helpers extend the 0.8.0 release scope and CHANGELOG `[0.8.0]` section is amended in lockstep. ROADMAP entry moves to v0.8 (added unchecked alongside qx-mbv on 2026-05-21).
- **Tutorial migration**: Out of this branch. Separate qxportal commit after 0.8.0 hits Hex.

## Dead-ends / explicitly rejected

- **`apply_gate/3` generic** (e.g. `Qx.Patterns.apply(qc, :h, 0..3)`) — initially appealing for uniformity but suffers from:
  - Parameterized gates (`:rx`, `:ry`, `:u`) need a params list, signature gets ugly.
  - Existing `Qx.QuantumCircuit.add_gate/4` already exposes the atom-name path; users can pipe through.
  - Discoverability worse than explicit names.
- **`measure_each/2` taking a list of qubit indices** — useful but adds API surface for a 5% case; deferred.
- **`reset_all/1`** — would emit `:reset` instructions but Qx doesn't currently have a per-qubit reset primitive (`Qx.QuantumCircuit.reset/1` clears the whole circuit, not a single qubit). Deferred until a `:reset` instruction exists.

## Open items to confirm at review time

- Whether to add a brief migration note in CHANGELOG showing the before/after for the tutorials' `apply_h_all/2` boilerplate. (Lean: yes, as a `### Added` body bullet.)
- Whether `Qx.Patterns` exports `cx_chain` as the *only* multi-qubit-gate helper, or also a sibling `cz_chain/2`. (Lean: just `cx_chain` until tutorials demonstrate cz_chain need.)
