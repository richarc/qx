# Scratchpad: host-side-state-lists

## Open decisions

- D2 (plan): real `type` in `basis_state/3` returns a tensor after the
  rewrite. Alternative is a typed `Qx.*Error` for non-complex types. Default
  chosen: allow. User can swap at plan review.

## Findings

- ROADMAP line 38 lists `simulation.ex` for the `pow` sweep; it has no
  `:math.pow` call as of 2026-11-14. The 14 sites are in `gates.ex`,
  `validation.ex`, `quantum_circuit.ex`, `state_init.ex`.
- `trunc(:math.pow(2, n))` is already exact for n ≤ 1023. The sweep is a
  clarity change, not a correctness fix.

## Out-of-scope work discovered

- `Qx.StateInit.basis_state/3` with an invalid `type` leaks a raw
  `ArgumentError` from Nx (Iron Law #7, tier 2). Exists today, unchanged here.
- `Qx.ResultBuilder.from_counts/3` builds two dense `2^num_bits` tensors
  (probabilities and the zero `state` placeholder). `num_bits` comes from the
  circuit's classical-bit count or is inferred from the returned count keys in
  `Qx.Hardware`. Not checked: whether anything bounds it. A large value would
  be an allocation failure on the hardware result path.
- The `@deprecated` `StateInit` functions and the `Qx.Gates` n-qubit builders
  still build host lists; they go with the 1.0 calc-engine removal
  (ROADMAP line 32).

## Dead ends

(none yet)

## From /phx:review (2026-11-14)

- Pre-existing, out of scope: `lib/qx/gates.ex` has `iex>` examples but no
  `doctest Qx.Gates` directive under `test/` (TDD rule 4). Candidate ROADMAP
  backlog line.
- Pre-existing: `Qx.ResultBuilder.from_counts/3` raises raw errors for a
  malformed outcome key or a negative `num_bits` (internal module, input from
  hardware responses).
- Decision: `valid_register?/2` returns false for a non-integer `num_qubits`
  (was `true` for 1.0 on main via `trunc(:math.pow/2)`). Tier 3.
- Decision: `basis_state/3` nil type means c64 (matches main).
