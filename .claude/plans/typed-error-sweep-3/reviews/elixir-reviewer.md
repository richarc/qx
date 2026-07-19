# Code Review: typed-error-sweep-3

## Summary
- **Status**: ⚠️ Changes Requested
- **Issues Found**: 3

## Warnings

1. **lib/qx/quantum_circuit.ex:74-77** — `new/2` fallback relies on
   *implicit* raise-or-not behavior of two independent validators instead of
   being explicit about which failure mode it's handling:

   ```elixir
   def new(num_qubits, num_classical_bits) do
     Qx.Validation.validate_num_qubits!(num_qubits)
     Qx.Validation.validate_num_classical_bits!(num_classical_bits)
   end
   ```

   Given today's validator definitions this is safe (I traced all guard-fail
   paths: one of the two calls always raises), but the safety is an
   emergent property of the *conjunction* of two validators' guards
   matching the *disjunction* in the primary clause's guard — nothing
   enforces that invariant if either validator is edited independently.
   If a future change relaxes `validate_num_qubits!/1` (e.g. widens
   accepted input), this function silently returns `:ok` (the last
   expression) instead of a `%QuantumCircuit{}`, breaking the `@spec` and
   every caller expecting a circuit. Prefer matching explicitly on which
   argument is invalid, e.g.:

   ```elixir
   def new(num_qubits, num_classical_bits) when not is_integer(num_qubits) do
     Qx.Validation.validate_num_qubits!(num_qubits)
   end

   def new(_num_qubits, num_classical_bits) do
     Qx.Validation.validate_num_classical_bits!(num_classical_bits)
   end
   ```
   This makes the "always raises" property structurally guaranteed rather
   than incidentally true. (`new/1`'s single-validator fallback at line 99-101
   doesn't have this issue — it's the sole guard, so it's safe by
   construction.)

2. **lib/qx/simulation_result.ex:118-120** — same pattern, lower risk:
   `filter_by_probability/2`'s fallback calls
   `Validation.validate_probability!(threshold)`, which only raises because
   its guard (`is_number(p) and p >= 0 and p <= 1`) is currently a byte-for-byte
   copy of the primary clause's guard. Any future drift between the two
   guards (e.g. `Validation` tightening/loosening independently of this
   call site) reintroduces the same silent-`:ok`-return risk as #1. Low
   priority since both guards live one file apart and are easy to eyeball,
   but flag for awareness — this is the second occurrence of the same
   fragile idiom in this sweep.

3. **lib/qx/operations.ex:783-803** — `c_if/4`'s clause 3
   (`value not in [0, 1]`, lib/qx/operations.ex:789) matches regardless of
   `classical_bit`'s type, so `c_if(qc, "bad", 5, fn c -> c end)` (both a
   non-integer bit *and* an invalid value) raises `Qx.ConditionalError`
   ("Conditional value must be 0 or 1") rather than the arguably more
   proximate `Qx.ClassicalBitError`. Not a bug — the input is invalid
   either way and something typed is raised — but worth confirming this
   error-priority ordering (value-check before bit-type-check) is the
   intended UX, since the sweep's stated goal is precise, pattern-matchable
   causes.

## Verified correct (per WHY-CONTEXT, no action needed)
- `Qx.ClassicalBitError` / `Qx.BasisError` exception clause order: all
  atom-tagged tuple clauses precede the unguarded catch-all(s); no
  shadowing.
- `Qx.QuantumCircuit.new/1,2` and `add_gate`/`add_two_qubit_gate` guard
  relaxations: every input that now bypasses the dropped `is_integer`
  guard is caught by `Validation.validate_qubit_index!/2`'s second clause
  (`when is_integer(num_qubits)`, always true from the struct) — no
  invalid input silently succeeds.
- `StateInit.basis_state/3` fallback `cond`: correctly prioritized
  (dimension → index-type → sign → range); idiomatic given 4 mutually
  exclusive checks with no natural pattern-match target (all failure
  modes examine the same two args).
- `Qx.Math.normalize/1` → `normalize_unchecked/1` split and `Nx.pow`
  usage in the host `def`: matches described intent exactly.
