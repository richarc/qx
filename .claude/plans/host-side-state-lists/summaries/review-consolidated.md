# Consolidated Review Summary: host-side-state-lists

**Strategy**: Compress
**Input**: 4 files (elixir.md, testing.md, iron-laws.md, requirements.md), ~10k tokens
**Output**: ~2.5k tokens (~75% reduction)

Tags: [V] verified (read or run), [I] inferred. Reviewer name in parentheses. Deconfliction applied: where iron-law-judge and elixir-reviewer flag the same code, the iron-law finding is kept (its severity), with elixir's extra evidence folded in and labelled.

## BLOCKER
None (all four reviewers).

## WARNING

W1. Negative index in `from_counts` behaviour change. lib/qx/result_builder.ex:52-63. (iron-laws LOW "Law 7"; elixir WARNING, merged)
- `String.to_integer("-1", 2)` = -1 passes `index < size`. Main wrapped to the last element via `List.replace_at(-1)`. Now `Nx.indexed_put` gets a negative index. [V iron-laws: change exists]
- Elixir adds: it raises `ArgumentError "index -1 is out of bounds"` (deps/nx/lib/nx/binary_backend.ex:1979) [V]. Iron-laws only says "undefined or raw" [I]. Plan D2 (per elixir) says out-of-range indices are dropped, but negatives are not.
- Only reachable with malformed keys like "-1" or "-01". Internal function.
- Fix: filter `index >= 0 and index < size`, or document it. No test covers it (elixir S6).

W2. Non-natural `num_qubits` now raises. lib/qx/validation.ex:65-68 and lib/qx/gates.ex:332,407,454,500,541. (iron-laws LOW "Law 6/7"; elixir WARNING, merged)
- `valid_register?` with a float `num_qubits` (2.0): `Bitwise.bsl` raises ArithmeticError. Old `trunc(:math.pow)` returned a boolean. [V iron-laws, V elixir that bsl needs integers; error class I]
- Elixir adds: huge positive `num_qubits` allocates a bignum, where old `:math.pow` raised past 1023 [I]. The comment at validation.ex:66-67 is accurate only for negatives. Suggested guard: `is_integer(num_qubits) and num_qubits >= 0`.
- Gates `Integer.pow`: negative n raises ArithmeticError [I], float n raises FunctionClauseError. Old gave `trunc(0.5)` = 0 for negatives (elixir) [I]. Valid inputs unchanged. Zero n gives 1 in both.
- `Qx.Gates` has no `num_qubits` validation (pre-existing). Iron-laws suggests routing through `Qx.Validation` if cheap.
- Both judge these unreachable through the validated public API.

W3. CHANGELOG "Internal:" bullet, "14 sites" and "values identical". CHANGELOG.md. CONTRADICTION between reports:
- elixir: "14 sites" is wrong. The diff shows 13 `Integer.pow` replacements (gates 5, quantum_circuit 3, state_init 5); validation.ex uses `bsl`. [V by diff]
- requirements: "14 sites" is accurate (13 `Integer.pow` + 1 `bsl`), and the entry does not mention the `bsl` special case. [V by grep and count]
- Both agree on 13 + 1 bsl. They disagree on whether the wording is wrong. Likely reconcilable: the count is right only if `bsl` counts, and the entry does not say so.
- elixir and iron-laws agree "values are identical" is overstated for non-validated or invalid input (true for non-negative integers only). Suggest softening it.

W4. Duplicate-index test pins unspecified behaviour. test/qx/host_side_state_lists_test.exs:121-128. (testing)
- Nx documents duplicate indices in `indexed_put` as unspecified; EXLA may differ. The test also depends on small-map key ordering ("01" < "1", stable for <=32 keys). Real count keys are fixed-width, so duplicates are unreachable. [V by code, Nx semantics from memory]
- Fix: delete, or assert only that the result is one of the two valid values.
- CONTRADICTION (side by side):
  - testing: later-wins is undefined Nx behaviour; the test is fragile.
  - elixir: later-wins is VERIFIED on BinaryBackend (binary_backend.ex:1722, `Enum.at(upds, -1)`; `Enum.group_by` at :1759 preserves order) [V].
  - iron-laws: BinaryBackend resolves duplicates via `Enum.at(upds, -1)`, so the comment at result_builder.ex:44-47 matches the code [V].
  - Not strictly a conflict (BinaryBackend vs documented contract), but the comment and test assume a guarantee Nx does not make.

W5. Missing `doctest Qx.Gates`. lib/qx/gates.ex (20 `iex>` lines, e.g. around line 329; file touched by diff). No `doctest` directive found under test/ [V grep]. Pre-existing gap, but it breaks the project rule for a touched module. Other modules are covered: StateInit at state_init_test.exs:3, Validation at validation_test.exs:3, QuantumCircuit at quantum_circuit_state_test.exs:6. ResultBuilder has no `iex>`. (testing)

## SUGGESTION (grouped)

Hardening of unlikely inputs (elixir):
- state_init.ex:79 and result_builder.ex:62: index tensor is always s32 (`Nx.Type.infer`, nx/type.ex:173) [V]. Index >= 2^31 would truncate [I]. Practically unreachable (qubits capped at 20). Option: `type: :s64`.
- state_init.ex:77: an explicit `type: nil` now gives an s32 tensor (old inferred c64) [V nx.ex:822]. Default is `:c64`, so very low impact. The CHANGELOG "Results are unchanged" is otherwise true.
- result_builder.ex:52-65: logic correct. Output f32 [V]; empty pairs give f32 zeros per plan [V]. Optional idiom: build `{[i], p}` and `Enum.unzip` to avoid a second pass.
- state_init.ex:77-79: duplicates and type merging are fine [V]. The old :f32 crash claim was reasoned, not run [I].

Test-suite quality (testing, all in host_side_state_lists_test.exs):
- :2-3: the `async: false` comment is wrong. `max_heap_size` is per-process and sibling draw_size_cap_test.exs uses `async: true`. Fix the comment or switch to async. [I]
- :25-54 harness: no spurious-failure risks found (cold VM, refc binaries not copied, deterministic kill). Residual: no `receive` timeout, so a hang shows only as ExUnit's 60 s timeout. Add `after 30_000 -> flunk(...)`. [I]
- :148-151 control: valid but weaker than the real regressions (2^20 list, ~2M words, 16x limit; does not exercise Nx). Optional: use `Nx.tensor(List.duplicate(0.0, @dimension))`.
- :132-146: heap tests assert shape only. Add a cheap value check at 2^20 (`state[0]`, `probabilities[@dimension-1] == 1.0`). This also covers a large boundary index; `result.state` shape is not asserted.
- :64-67: c128 test checks type only. Add a value assertion via `Nx.to_flat_list`.
- :108-115: the `[]` branch via "all indices >= 2^n" is untested. Add e.g. `%{"111" => 1}` with 2 bits.
- Missing tests: negative index (W1), float/negative `num_qubits` (W2), large index. Integer.pow sites have no targeted test, which is acceptable given existing gate tests [I, S7]. The :154-159 `valid_register?` negative pin is meaningful [I].
- Float `==` comparisons are safe (f32-exact values). Heap tests are not tautological.

Comments and docs:
- "Iron Law #5" comments match CLAUDE.md:396 (elixir, requirements: mild, unrequested). CHANGELOG timings (227 ms to 4.7 ms, 111 ms to 11 ms) and heap word counts (1,598 / 22.8M / 41.5M) are internally consistent with progress.md but not re-measured by elixir [I]. Requirements confirms they match progress.md and plan note 4.1.

## Pre-existing (not this diff)
- result_builder.ex:19: `String.to_integer(outcome, 2)` accepts "-", "+", "_" and raises a raw ArgumentError (elixir, iron-laws).
- result_builder.ex:26-29: `List.duplicate(bits, count)` is an O(shots) host list, not 2^n (elixir, iron-laws).
- result_builder.ex:32,49: `is_integer` guard only; negative `num_bits` raises. Line 33: zero-vector placeholder is an f32 real tensor, not c64 (iron-laws).
- state_init.ex:214-260, 385-440: superposition, random, ghz and w still build 2^n host lists. Iron-laws: the first, second and fourth are `@deprecated`, and `ghz_state_vector` is not. Plan scope-out.
- `Qx.Gates` has no `num_qubits` validation (iron-laws).

## Iron-law and requirements verdicts
- iron-laws: 9 project laws checked. 0 violations introduced. Law 5 (no host loops over 2^n) COMPLIANT: `basis_state` is O(1) host work, `build_probability_tensor` is O(k). Law 4 (BinaryBackend) COMPLIANT. Law 6 COMPLIANT for valid inputs (no breaking change; real types now succeed instead of crashing). Law 3 does not apply.
- requirements: 25 MET, 0 PARTIAL, 0 UNMET, 2 UNCLEAR (3.3 full suite and 4.2 verification gate not re-run; progress.md claims 1586 passed). ROADMAP.md:33,38 still `[ ]`, deferred to the squash commit by design. Doctest count not re-verified.
- Plan ID NOTE: elixir cites "D2" for out-of-range dropping and "D5" for real type. requirements maps real type to D2, dropping to D4a, and pow sweep to D5. Check plan.md for the actual numbering before citing.

## Coverage

| File | Represented | Key Items |
|---|---|---|
| elixir.md | Yes | 3 W (merged into W1-W3), 6 S, pre-existing |
| testing.md | Yes | 2 W (W4, W5), 8 S |
| iron-laws.md | Yes | 0 violations, 2 LOW (merged into W1, W2), per-law verdicts |
| requirements.md | Yes | 25 MET, 2 UNCLEAR, count contradiction (W3) |
