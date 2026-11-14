# Iron Law Review: docs-consistency

Checked against the project's AGENTS.md laws, TDD rules and VERIFICATION. Phoenix, Ecto, LiveView and Oban laws do not apply.
Violations: 0 blockers, 0 high. 3 low or advisory notes.

## Answers

1. CONTRIBUTING paragraph vs Iron Law #6 (verified by reading both). It agrees.
   - Tier 1 and tier 2 coverage, the CHANGELOG entry, the minor bump below 1.0.0 (`~> 0.11` excludes 0.12.0), the major bump from 1.0.0, and "a patch never breaks" all match.
   - The tier-1 opener "Tier 1: a core Qx type", the tier-2 opener "Utility module:", and tier 3 as `@moduledoc false` match the law.
   - Overstatement: none.
   - The phrase "or rejects input that used to be accepted" is not in the law. It is a PR-description instruction and does not contradict the law.
   - Minor: `lib/qx/draw.ex` carries "Utility module:" on line 5, after a summary line, not as the opener. The law has the same looseness.
2. Named definitions (verified by grep).
   - All of these exist in `lib/qx/errors.ex`: QubitIndexError, QubitCountError, ClassicalBitError, GateError, ParameterError, BasisError, MeasurementError, ConditionalError, OptionError, StateNormalizationError, StateShapeError, DrawSizeError, QasmParseError, QasmUnsupportedError, MissingDependencyError.
   - `Qx.Hardware.ConfigError`, `ExecutionError` and `NoMeasurementsError` are referenced in `lib/qx/hardware.ex`. I did not locate their defmodule lines, so the "Qx.Hardware has its own error types" claim rests on those references (partly inferred).
   - The README claim that a measurement inside an `if` block raises QasmUnsupportedError matches `lib/qx/export/openqasm/lowering.ex:220`.
   - The claim that a `c_if` block rejects a measurement or a nested `c_if` matches `lib/qx/operations.ex:839`.
   - The CHANGELOG compare links and tags v0.10.0, v0.10.1 and v0.11.0 match the CHANGELOG headings.
   - Not verified: whether the git tags exist on GitHub, and whether CONTRIBUTING.md is on `main` for the absolute README link.
3. Existing tests (verified from the diff). Only the new file `test/qx/doctest_directives_test.exs` is added. No existing test is touched. TDD rule 2 holds.
4. TDD rule 4 (verified by grep). Modules in `lib/` with `iex>` are Calc, SimulationResult, Draw.Image, Draw.StateTable, Export.OpenQASM, QuantumCircuit, Operations, Step, Validation, Math, Register, StateInit, Simulation, Patterns, Qubit, Format, Qx, Gates and Hardware.Config. Every one now has a `doctest` directive. Rule 4 holds for all of them.
   - Advisory (LOW, REVIEW): the rule also says to confirm the doctest count rises in `mix test` output. I have no Bash, so I did not run it and the claim is unconfirmed.
   - Advisory (LOW): the `Qx.Calc` doctests (`lib/qx/calc.ex:26-33,57-58`) have no expected values. They only prove the calls don't crash.
   - I did not run `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict` or `mix test`. The VERIFICATION section requires them before this is called done.
5. Iron Law #8 (verified). The rewritten examples assert only shape `{2, 2}` or `{4, 4}` and type `{:c, 64}`. `Math.complex_matrix` builds `:c64`, so the type assertion is feasible. There are no numeric tolerance claims.
6. Iron Law #6, other: the diff changes no runtime code and no public signature, so there is no version-bump trigger from this diff.
