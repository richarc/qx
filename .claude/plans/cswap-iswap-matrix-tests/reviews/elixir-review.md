# Code Review: cswap/4 rewrite + CswapIswapMatrixTest

## Summary
- **Status**: ⚠️ Changes Requested
- **Issues Found**: 3 (0 BLOCKER, 1 WARNING, 2 SUGGESTION)

---

## Warnings

### 1. `lib/qx/gates.ex:485` — Doc claims `:c64` but says "real 0/1 permutation tensor" — contradiction

The `@doc` for `cswap/4` reads:

> Returns a `:c64` `{2ⁿ, 2ⁿ}` **real 0/1 permutation tensor**.

"Real 0/1 permutation tensor" is a truthful description of the *values*, but calling it a "real … tensor" while the type is `:c64` is a contradiction that will confuse readers. The CSWAP matrix has only real entries (it's a permutation gate), but the tensor is complex-typed.

**Fix:**

```elixir
# Current (line 485)
Returns a `:c64` `{2ⁿ, 2ⁿ}` real 0/1 permutation tensor.

# Suggested
Returns a `:c64` `{2ⁿ, 2ⁿ}` permutation tensor (all entries are real 0 or 1).
```

---

## Suggestions

### 2. `lib/qx/gates.ex:519-520` — `Math.complex_matrix([[C.new(1, 0)]])` where `Nx.tensor([[1]], type: :c64)` already works

`cswap/4` sets the swap target with:

```elixir
|> Nx.put_slice([i, j], Math.complex_matrix([[C.new(1, 0)]]))
```

The `iswap/3` precedent uses `Math.complex_matrix` there because it needs a genuinely complex value (`C.new(0, 1)`) that cannot be expressed as a plain number literal. For the CSWAP case the value is 1+0i — identical to `Nx.tensor([[1]], type: :c64)` (confirmed by reading `Math.complex_matrix/1`). Using `Math.complex_matrix` here adds a `Complex` struct allocation and an `Enum.map` over a 1-element list for no reason. Using `Nx.tensor` also makes the intent (a real integer 1) immediately legible.

```elixir
# Suggested
|> Nx.put_slice([i, j], Nx.tensor([[1]], type: :c64))
```

This is not a correctness issue — both produce identical `:c64` tensors — so it is a suggestion, not a blocker.

### 3. `test/qx/cswap_iswap_matrix_test.exs:42-43` — `Nx.to_list |> List.flatten` loses structural information early

```elixir
a = actual |> Nx.to_list() |> List.flatten()
e = expected |> Nx.to_list() |> List.flatten()
```

For a square matrix `Nx.to_list/1` returns a list of rows (list-of-lists). `List.flatten` collapses this to a flat list. The subsequent `Enum.zip` then reports the flat index, which makes a failure message like `"real mismatch at flat index 13"` ambiguous (row 1 col 5 of an 8×8? row 6 col 6?). Because shape is checked first, there is no correctness risk, but diagnostic quality suffers on failures.

Consider keeping the list-of-lists structure and reporting `"row #{i}, col #{j}"`:

```elixir
actual |> Nx.to_list() |> Enum.with_index() |> Enum.each(fn {row, i} ->
  row |> Enum.with_index() |> Enum.each(fn {av, j} ->
    ev = expected |> Nx.to_list() |> Enum.at(i) |> Enum.at(j)
    assert_in_delta Complex.real(av), Complex.real(ev), @delta,
                    "#{message}: real mismatch at row #{i}, col #{j}"
    assert_in_delta Complex.imag(av), Complex.imag(ev), @delta,
                    "#{message}: imag mismatch at row #{i}, col #{j}"
  end)
end)
```

This is entirely a quality-of-life suggestion; the existing flat-index reporting is not wrong.

---

## Correctness Notes (No Issue)

- The `cswap/4` bit-math is correct. Verified manually: `cswap(0,1,2,3)` produces rows 5↔6 (|101⟩↔|110⟩); `cswap(2,0,1,3)` produces rows 3↔5 (|011⟩↔|101⟩). Both match the test references.
- The `:c64` identity seed and `Nx.put_slice` pattern correctly mirrors `iswap/3` and `swap/3`.
- The doctest shape update `{8,8,2}` → `{8,8}` is correct.
- Test helper `identity_with_rows_swapped/3` is built independently of `Qx.Gates` — it is a genuine reference, not a tautology.
- The `assert_complex_matrix_equal/3` helper correctly checks shape before entry-wise comparison.
- The iSWAP sign test (SUGGESTION 3 test) is a valuable regression guard for the +i vs −i convention.
