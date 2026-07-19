# Scratchpad: counts-contract

## Discovered during review (pre-existing, out of scope here)

Outcome-key semantics beyond the string fix, found empirically by the
elixir-reviewer:

- Key position is **measurement insertion order**, not classical-bit
  index: `measure(1, 1) |> measure(0, 0)` yields key "01" (qubit 1's
  outcome first), where cbit-index order would give "10".
- Key **width differs by path**: the sampled path emits
  measurement-width keys ("1" for one measured qubit of three); the
  conditional path emits register-width keys ("001").

Both predate this fix (they're properties of how `classical_bits` is
assembled) and Draw renders whatever the engine emits, so charts and
counts always agree. But it means two circuits measuring the same
qubits in different textual order key their counts differently.
Candidate normalisation: order by classical-bit index and pad to
`num_classical_bits`. That's a behaviour change needing its own
decision — add to the api-consistency-review findings list as a
follow-up (kin of R-03's two-regime `state` field).

Docs in this fix deliberately say "classical bits in measurement
order" to avoid codifying an invariant the producer doesn't enforce.

## Review

3 agents: elixir-reviewer PASS WITH WARNINGS, testing-reviewer PASS
WITH WARNINGS, iron-law-judge PASS. All warnings fixed in-branch:
3 examples/ scripts migrated, docs reworded per above, seam-test
assertion strengthened (`>= 512`) and moduledoc claim narrowed.
Reports in `research/`.
