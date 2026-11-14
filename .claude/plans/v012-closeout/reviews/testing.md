# Test Review: test/qx/conditional_measurement_guard_test.exs

## Summary
Adequate core coverage; four gaps worth closing. No Iron Law violations (async: true is safe: pure, no Application env, no Mox, no DB). Verified by reading code unless marked (inferred).

## Existing tests vs removed behaviour (verified by Grep)
- No test under `test/` references `Qx.Gates.toffoli`. All `apply_toffoli` hits are `Calc`/`CalcFast`, which are untouched.
- No other test builds a `c_if` block containing a measurement (grep of `c_if.*measure` and `{:measure, ...}` hits only shows top-level measures). `conditional_operations_test.exs:167` is a top-level measure followed by c_if. Nothing relied on the old silent skip. (Full-suite run not performed by me.)
- No other test uses a one-qubit `{:measure, [q], []}`.

## Critical
None.

## Warnings
- [ ] Remaining dead arm (verified): `lib/qx/simulation.ex:570` still has `:measure -> state` in the TWO-qubit controlled dispatch. This is the same class of silent no-op as the deleted one-qubit arm. `{:measure, [0, 1], []}` is also the real `[qubit, cbit]` shape, but it is routed through the measurement path at line 702, so the arm looks unreachable. Either delete it, or add a test. The new test pins only the one-qubit case.
- [ ] No execution test through `Qx.steps/2` (project rule: every instruction shape needs a `run` or `steps` test). The one-qubit `:measure` GateError test uses only `Qx.run`. Whether `steps/2` shares the dispatch is inferred (simulation.ex:702-755 suggests a separate timeline path), so verify it raises `Qx.GateError` there too.
- [ ] The three c_if raise tests assert the message only via regex `~r/[Mm]easurement.*conditional block/`. The actual message is "Measurement is not supported inside a conditional block; measure after the c_if block instead". The regex is loose (`[Mm]` hedge) and would also match a different error. Pin the exact message or at least `"Measurement is not supported inside a conditional block"`. Also assert the hint text ("measure after the c_if block"), since that is the user-facing remedy.
- [ ] Control test "gates only block runs" asserts `counts == %{"11" => 10}`. This is deterministic (x(0), measure, c_if x(1), measure), so it is fine, but it does not verify that a measurement AFTER the block works when c_if has a measure-free body at an earlier position. It does (the trailing `Qx.measure(1, 1)`), so this item is satisfied. No change needed.

## Suggestions (missing cases)
- [ ] Call `Qx.Operations.c_if/4` directly once: `Qx.c_if` is a `defdelegate` (verified), so the value is low. Skip or add one line.
- [ ] Measure as the only, first, and last statement in a QASM `if` body: `Enum.find` over the body would catch all, but only "gate then measure" (last position) is tested. Add `if (c[0]==1) { c[1] = measure q[1]; }` (only) and `{ c[1] = measure q[1]; x q[1]; }` (first).
- [ ] QASM `line == 7` is asserted, but the `line` in the error is the measure's `meta[:line]` (verified, lowering.ex:221). The statement is on the same line as the `if`, so the test cannot tell whether it reports the measure's line or the `if` line. Put the body on separate lines to distinguish them. Assert `error.hint` too (currently untested).
- [ ] Nested measurement: measurement inside an `if` body nested in another body, or a measure inside a QASM `for`/block, is not covered. Confirm the parser forbids nested ifs (inferred).
- [ ] The `error.feature =~` assertion uses backticks in the string; acceptable, but brittle if the wording changes. Exact-equality on `feature` is more honest here.
- [ ] Assert the error is raised before the c_if is appended, e.g. that the original `qc` is unchanged (immutable, so low value).
- [ ] The describe "a one-qubit :measure instruction" uses `put_instructions/2` to inject an impossible shape. Acceptable for a boundary test, but note it pins an internal API; if `put_instructions` is renamed, this fails for the wrong reason.
- [ ] Optional property/round-trip: `from_qasm` of the output of `to_qasm` for a circuit with c_if + trailing measure still imports (shows the guard does not reject valid exports).

## Pre-existing (unchanged files)
None found in the files I grepped; I did not audit the whole suite.
