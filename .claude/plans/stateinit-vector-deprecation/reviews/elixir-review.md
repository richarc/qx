# Code Review: stateinit-vector-deprecation

## Summary
- **Status**: ⚠️ Changes Requested
- **Issues Found**: 4 (1 WARNING, 3 SUGGESTIONS)

---

## Warnings

### 1. `@spec ghz_state_vector` overstates accepted input — `pos_integer()` admits `1` but the guard rejects it
**Location**: `lib/qx/state_init.ex:353`

```elixir
# Current
@spec ghz_state_vector(pos_integer(), Nx.Type.t()) :: Nx.Tensor.t()
def ghz_state_vector(num_qubits, type \\ :c64)
    when is_integer(num_qubits) and num_qubits >= 2 do
```

`pos_integer()` covers `t >= 1`. The guard requires `t >= 2`, so a caller passing `1` satisfies the spec yet gets a `FunctionClauseError`. Dialyzer won't flag `ghz_state_vector(1, :c64)` as a type error.

There is no standard Dialyzer type for "integer >= 2", so the idiomatic fix is to tighten the `@doc` text or add a `@doc` note that `num_qubits >= 2` is enforced at runtime, and leave the spec as `pos_integer()` with that caveat explicit. What is **not** acceptable is leaving the spec silent about the tighter lower bound with no documentation: the function raises on `1`, but neither the spec nor the `@doc` body currently warns the caller.

The `@doc` at line 321 currently lists no parameters section — add one like `bell_state_vector` (lines 237-238) and state `num_qubits >= 2` explicitly.

---

## Suggestions

### 2. `ghz_state/2` deprecated shim carries a redundant guard — inconsistent with `bell_state/2` shim
**Location**: `lib/qx/state_init.ex:376`

```elixir
# ghz_state shim — has guard:
def ghz_state(num_qubits, type \\ :c64) when is_integer(num_qubits) and num_qubits >= 2 do
  ghz_state_vector(num_qubits, type)
end

# bell_state shim — no guard (line 317):
def bell_state(which \\ :phi_plus, type \\ :c64) do
  bell_state_vector(which, type)
end
```

The guard on the `ghz_state` shim is redundant — `ghz_state_vector/2` already guards. The only observable difference is that `ghz_state(1)` raises `FunctionClauseError` from the shim rather than from the canonical function. Both shims are pure delegators; carrying a guard on one but not the other is an unexplained inconsistency. Consider dropping the guard from the shim for uniformity with `bell_state/2` and the `math.ex:225` pattern.

### 3. Exact `== 0.0` float comparisons in the test file, inconsistent with `approx_equal?/2`
**Location**: `test/qx/state_init_vector_test.exs:55,62,69`

```elixir
# Lines 55, 62, 69 — strict equality:
assert Enum.at(probs, 1) + Enum.at(probs, 2) == 0.0
assert Enum.sum(Enum.slice(probs, 1..6)) == 0.0
assert Enum.sum(Enum.slice(probs, 1..14)) == 0.0
```

The zero-probability assertions use exact `== 0.0` while every non-zero assertion uses `approx_equal?/2`. The current states are constructed from literal `C.new(0.0, 0.0)` amplitudes, so these should be exactly zero. However, if the construction path ever changes to go through `Qx.Math.normalize/1` or any arithmetic, float rounding will silently break these. Prefer `approx_equal?(value, 0.0)` for consistency and resilience.

### 4. `cond` in `ghz_state_vector` body where pattern-matched cases over `i` would be clearer
**Location**: `lib/qx/state_init.ex:361-365`

```elixir
# Current
cond do
  i == 0 -> C.new(inv_sqrt2, 0.0)
  i == dimension - 1 -> C.new(inv_sqrt2, 0.0)
  true -> C.new(0.0, 0.0)
end
```

The first two branches produce identical results and could be collapsed with `||`:

```elixir
if i == 0 or i == dimension - 1,
  do: C.new(inv_sqrt2, 0.0),
  else: C.new(0.0, 0.0)
```

`cond` with a `true ->` catch-all that covers the remaining cases is idiomatic when branches differ; here two branches are identical, making `if`/`else` both shorter and more readable. Low-priority — this is pre-existing structure, not introduced by this change.

---

## Verification notes (not findings)

- The `:c128` correction (`:c32` → `:c128`) in the `bell_state_vector` docstring is correct. Nx complex types are `{:c, 64}` and `{:c, 128}` only.
- Deprecation shim order (`# Deprecated:` comment → `@deprecated` → `@doc false` → delegation) matches `math.ex:220-228` exactly.
- `@type bell_state_which` is correctly defined and referenced in the `@spec` for the canonical function; no spec on the deprecated shim is consistent with the `math.ex` precedent.
- CHANGELOG entry placement (`### Added` + `### Deprecated` under `[Unreleased]`) and removal-window statement (v0.9) are correct.
- `qx.ex` `See Also` cross-refs updated to `bell_state_vector/2` and `ghz_state_vector/2` — correct.
