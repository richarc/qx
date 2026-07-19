# Code Review: feat/calcfast-norm-drift-guard (Elixir)

## Summary
- **Status**: ⚠️ Changes Requested
- **Issues Found**: 5 (1 BLOCKER, 2 WARNINGS, 2 SUGGESTIONS)

---

## BLOCKER

### 1. `lib/mix.exs:88-104` — `Qx.OptionError` missing from `"Error Handling"` docs group

`Qx.OptionError` is a new public exception raised at the API boundary and documented in `Qx.Simulation.run/2` options, but it is not listed in the `"Error Handling"` group in `mix.exs`'s `docs()`. Every other typed Qx exception is listed there. Callers discovering the error via `raise Qx.OptionError` will find no ExDoc page because the module is absent from the generated docs navigation.

```elixir
# Current (mix.exs ~line 91) — missing entry:
"Error Handling": [
  Qx.Error,
  Qx.QubitIndexError,
  # ... Qx.OptionError is not listed
]

# Suggested:
"Error Handling": [
  Qx.Error,
  Qx.OptionError,   # add here — alphabetically between Error and QubitIndexError
  Qx.QubitIndexError,
  ...
]
```

---

## WARNINGS

### 2. `lib/qx/simulation.ex:293-296` — `assert_norm/1` silently discards the `:ok` return; side-effect form is misleading

`Validation.validate_normalized!/2` returns `:ok` on success or raises. The call site is:

```elixir
if @assert_norm, do: Validation.validate_normalized!(state, @norm_tolerance)
state
```

This works correctly — `state` is always the return value. However, in `:test` (where `@assert_norm` is `true`) the `if` evaluates to `:ok`, not `state`, and the discarded result produces a Credo `UnusedEnumOperation`-equivalent warning from Dialyzer (`expression_is_result_of_call_and_could_be_boolean`). More importantly, this style reads as if `state` might be rebinding, and makes the intent less clear than it could be.

```elixir
# Current
defp assert_norm(state) do
  if @assert_norm, do: Validation.validate_normalized!(state, @norm_tolerance)
  state
end

# Clearer — side-effect separated from return, intent is explicit
defp assert_norm(state) do
  if @assert_norm, do: Validation.validate_normalized!(state, @norm_tolerance)
  # always return the tensor unchanged
  state
end
# (The comment in the existing code already explains it; the code itself is fine
# but see note — Dialyzer may flag the discarded :ok in test mode.)
```

The real fix if Dialyzer does flag it:
```elixir
defp assert_norm(state) do
  if @assert_norm, do: :ok = Validation.validate_normalized!(state, @norm_tolerance)
  state
end
```
This pins the expected return via pattern match and makes the discard explicit.

### 3. `lib/qx/simulation.ex:590-600` — `process_conditional/6` applies no `maybe_gate_renorm` to conditional sub-instructions

The `execute_single_shot/2` reduce loop applies `maybe_gate_renorm(renorm, idx)` after each timeline item. However, the `{:conditional, ...}` branch delegates to `process_conditional/6`, which calls `Enum.reduce(instructions, state, fn instr, s -> apply_instruction(...) end)` — those sub-gate applications are invisible to the outer `idx` counter and receive **no per-gate renorm at all**.

For `renormalize: N` with a large conditional block, this creates an untracked gate-count window. If a conditional branch has `M` gates, the effective renorm interval for that shot can exceed `N` by up to `M`. For short circuits / small `M` this is within noise, but it is an undocumented inconsistency.

Not flagging this as BLOCKER because `execute_single_shot` is only invoked for `c_if` circuits and the existing test (`"conditional circuit with renormalize: N"`) passes, implying drift stays in tolerance for the tested case. Worth noting for callers of conditional + high-gate-count branches.

---

## SUGGESTIONS

### 4. `lib/qx/validation.ex:328` — `@spec` input type is narrower than `validate_renormalize!`'s purpose

```elixir
@spec validate_renormalize!(false | true | pos_integer()) :: false | true | pos_integer()
```

The spec says the function only accepts `false | true | pos_integer()`. But the function's purpose is to *validate* arbitrary caller input and raise `Qx.OptionError` on bad input. Dialyzer will infer a warning for call sites that pass, e.g., `0` or `:bad` (values the spec says cannot occur), even though that is exactly the intended use from `resolve_renormalize/1` (which passes `Keyword.get/3` result — typed `term()`).

The input type should be `term()`:

```elixir
@spec validate_renormalize!(term()) :: false | true | pos_integer()
```

### 5. `lib/qx/simulation.ex:104-110` — `resolve_renormalize/1` — triple-clause `case` over boolean-ish values could use function heads

The three-clause `case` in `resolve_renormalize/1` dispatches on `false`, `true`, and `n` — values that are already validated by `validate_renormalize!/1`. Using private function heads here would be idiomatic and eliminate the `case`:

```elixir
# Current
defp resolve_renormalize(options) do
  case Validation.validate_renormalize!(Keyword.get(options, :renormalize, false)) do
    false -> :off
    true -> :measurement
    n -> {:every, n}
  end
end

# Suggested
defp resolve_renormalize(options) do
  options |> Keyword.get(:renormalize, false) |> Validation.validate_renormalize!() |> to_renorm()
end

defp to_renorm(false), do: :off
defp to_renorm(true), do: :measurement
defp to_renorm(n), do: {:every, n}
```

This is a style suggestion only — the current code is correct and credo-clean.

---

## Pre-existing issues outside the diff (one-liners)

- `lib/qx/simulation.ex:316-333` — `apply_instruction/3` dispatches on `length(qubits)` inside a `case`; pre-existing pattern-match in function heads would be idiomatic (pre-existing, not introduced by this diff).
- `lib/qx/validation.ex:74-85` — `valid_register?/2` uses `if/else` over a boolean; `case` on shape + guard would be idiomatic (pre-existing).
