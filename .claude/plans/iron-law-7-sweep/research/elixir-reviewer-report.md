# Code Review: fix/iron-law-7-sweep — Iron Law #7 typed-error sweep

## Summary

- **Status**: ⚠️ Changes Requested
- **Issues Found**: 5 (1 BLOCKER, 2 SHOULD-FIX, 2 NICE-TO-HAVE)

---

## BLOCKER

### 1. `Qx.create_circuit/2` and `Qx.create_circuit/1` docs still claim `FunctionClauseError` — but that's no longer true

**File**: `lib/qx.ex:79`, `lib/qx.ex:100`

The `## Raises` sections on both `create_circuit` delegators say:

```
* `FunctionClauseError` - If `num_qubits <= 0` or `num_classical_bits < 0`
  (guard-only; struct construction predates `Qx.Validation`)
```

But `Qx.QuantumCircuit.new/2` (the delegate target) now calls
`Qx.Validation.validate_num_qubits!/1` unconditionally (see `quantum_circuit.ex:54`),
which raises `Qx.QubitCountError`, not `FunctionClauseError`. The guard on
`new/2` still covers the `num_classical_bits < 0` case with a raw
`FunctionClauseError`, but the `num_qubits <= 0` case is now a typed
`Qx.QubitCountError`.

This is a doc accuracy failure that contradicts the core goal of the sweep
(users who read the docs to know what to rescue will rescue the wrong thing).

**Fix**: Update both `## Raises` sections:

```
## Raises
  * `Qx.QubitCountError` - if `num_qubits` is out of the 1–20 range
  * `FunctionClauseError` - if `num_classical_bits < 0` (guard-only)
```

---

## SHOULD-FIX

### 2. `Qx.Gates.swap/3` and `Qx.Gates.iswap/3` docs still claim `FunctionClauseError`

**File**: `lib/qx/gates.ex:404`, `lib/qx/gates.ex:451`

Both functions document:

```
* `FunctionClauseError` - If qubit indices are out of range or equal
```

These functions are internal helpers called from `Qx.Register.swap/3` and
`Qx.Register.iswap/3`, which now validate before calling — so the raw
`FunctionClauseError` would only surface if callers bypass the public API.
However, these `@doc` strings are public (no `@doc false`). If the sweep
intent is that no raw error leaks at the public API boundary, these docs
need either:
- correction to "should not be called directly; use `Qx.Register.swap/3`", or
- `@doc false` on the functions, or
- actual typed-error raises added to the gate-matrix builders themselves.

At minimum the doc is misleading because for any call going through the
public `Qx.Register` or `Qx.Operations` path, callers will see
`Qx.QubitIndexError`, not `FunctionClauseError`.

### 3. `unless` anti-pattern in new register validation site

**File**: `lib/qx/register.ex:99`

```elixir
unless Qx.Validation.valid_qubit?(qubit) do
  raise Qx.RegisterError, {:invalid_qubit, qubit}
end
```

Credo (strict mode) flags `unless` with a body and no else as
`Credo.Check.Refactor.UnlessWithElse`... actually `unless` with no `else`
is fine from Credo's perspective, but stylistically this is a negated
condition that reads more clearly inverted. More relevantly, Elixir 1.18
deprecated bare `unless` — if the project targets 1.18+, this will emit
a compiler warning. The idiomatic replacement is:

```elixir
if not Qx.Validation.valid_qubit?(qubit) do
  raise Qx.RegisterError, {:invalid_qubit, qubit}
end
```

Or, preferably, pull the validation into a guard-style helper and match:

```elixir
Enum.each(qubits, fn qubit ->
  if Qx.Validation.valid_qubit?(qubit), do: :ok, else: raise Qx.RegisterError, {:invalid_qubit, qubit}
end)
```

Check `mix.exs` for the minimum Elixir version; if it targets 1.18+, this
is a compiler warning in the test run and therefore a BLOCKER.

---

## NICE-TO-HAVE

### 4. `Qx.BasisError` `@moduledoc` explanation of the missing fallback is accurate but slightly misleading

**File**: `lib/qx/errors.ex:105-107`

```
Like `Qx.ParameterError`, this exception omits the
`exception(message) when is_binary` fallback: a basis value may be any
term — a binary included — so every value is captured in `:value`, never
treated as a pre-formatted message.
```

The reasoning is correct and the omission is intentional (as noted in the
review brief). However, this means `raise Qx.BasisError, "some string"` will
produce `e.value == "some string"` and `e.message == ~s(Basis must be 0 or 1,
got: "some string")` rather than using the string as the message directly.

The test at `typed_errors_sweep_test.exs:47-50` correctly documents this
behavior. The only suggestion is to add a sentence to the moduledoc
explicitly stating `raise Qx.BasisError, "bad"` sets `:value`, not
`:message`, since this surprises callers who use the binary shorthand
convention that every other exception in the family supports.

### 5. `Qx.RegisterError.exception/1` fallback clause leaves `:reason` as `nil` with no struct field set

**File**: `lib/qx/errors.ex:93-95`

```elixir
def exception(message) when is_binary(message) do
  %__MODULE__{message: message}
end
```

This sets `reason: nil` (the default). That is consistent with
`Qx.QubitIndexError` and others that have a similar `is_binary` fallback.
However, unlike those, `Qx.RegisterError` documents three concrete `:reason`
shapes. A caller doing `rescue e in Qx.RegisterError -> e.reason` would get
`nil` when the string shorthand was used and a struct when a proper reason
atom/tuple was used — an inconsistency that is invisible at compile time.

If the string fallback is retained (it serves internal use like
`raise Qx.RegisterError, "boom"` in tests or interop), consider adding a
note to the moduledoc that the fallback leaves `:reason` as `nil` and is
not intended for programmatic matching.

---

## Exception Module Pattern — No Issues

`Qx.RegisterError` and `Qx.BasisError` both:

- Use `defexception [:field, ..., :message]` (correct struct definition)
- Implement `@impl true` on `exception/1` (correct callback attribution)
- Build the struct explicitly rather than delegating to `defexception`'s
  default (consistent with the rest of the family)
- `Qx.RegisterError` includes the `is_binary` fallback matching the family
  convention; `Qx.BasisError` intentionally omits it (documented, correct)
- Multi-clause `exception/1` heads use pattern matching rather than `case`
  inside a single function — idiomatic

## Raise Site Correctness — No Issues

All inspected raise sites carry the correct payload shape:

| Site | Error | Payload | Correct |
|------|-------|---------|---------|
| `register.ex:92` | `Qx.RegisterError` | `:empty` | Yes |
| `register.ex:100` | `Qx.RegisterError` | `{:invalid_qubit, qubit}` | Yes |
| `register.ex:163` | `Qx.RegisterError` | `:empty` | Yes |
| `register.ex:168` | `Qx.BasisError` | `Enum.find(...)` value | Yes |
| `qubit.ex:290` | `Qx.BasisError` | `basis` | Yes |
| `draw/tables.ex:63` | `Qx.RegisterError` | `{:invalid_input, val}` | Yes |
| `draw/svg/circuit.ex:112` | `Qx.QubitCountError` | `{count, 1, 20}` | Yes |
| `draw/svg/circuit.ex:123` | `Qx.QubitIndexError` | `{qubit, num_qubits}` | Yes |
| `draw/svg/circuit.ex:127` | `Qx.ClassicalBitError` | `{bit, num_cbits}` | Yes |
| `draw/svg/circuit.ex:162` | `Qx.GateError` | `{:unsupported_gate, gate}` | Yes |
| `export/openqasm.ex:177` | `Qx.OptionError` | `{:version, v, hint}` | Yes |
| `export/openqasm.ex:189` | `Qx.ConditionalError` | string | Yes |

## `u/5` Guard Relaxation — Correct

`Operations.u/5` guard at line 292 keeps only `is_integer(qubit)` (dropping
bounds). This correctly delegates bounds checking to
`QuantumCircuit.add_gate/4 → Qx.Validation.validate_qubit_index!/2`, which
raises `Qx.QubitIndexError`. The parameter validation (theta, phi, lambda)
raises `Qx.ParameterError` via `Validation.validate_parameter!/1`. Both paths
produce typed errors as required by Iron Law #7.

## Test Coverage — No Issues

`test/qx/typed_errors_sweep_test.exs` covers:

- Both new exception constructors (all argument shapes)
- The `is_binary` fallback on `Qx.RegisterError`
- `BasisError` binary-value behavior (no accidental message passthrough)
- All new public raise sites: `from_basis_states/1`, `from_basis/1`,
  `Tables.render/2`, `Draw.plot/2`, `Draw.plot_counts/2`,
  `SVG.Circuit.render/1` (5 sub-cases)

The `QuantumCircuit` struct is constructed directly in several tests to
inject invalid state — acceptable for a defensive-validation test file.
