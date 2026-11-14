# Review: docs-consistency (docs-only diff)

Status: Changes requested (1 wrong claim, 1 count mismatch, minor items). No Bash, so no tests or `git tag` command were run; tags read from `.git/refs/tags`.

## Wrong / misleading

1. CONTRIBUTING.md, "`~> 0.11` excludes 0.12.0" (VERIFIED by Hex/Version semantics, not by running code). A two-segment `~> 0.11` means `>= 0.11.0 and < 1.0.0`, so it ALLOWS 0.12.0. Only `~> 0.11.0` excludes it. The same slip is in AGENTS.md line 403 ("`~> 0.10` pins `< 0.11.0`"), which is the likely source. Fix the CONTRIBUTING text to `~> 0.11.0`, and consider fixing AGENTS.md too.
2. ROADMAP v0.12 intro says "three breaking changes" (VERIFIED, CHANGELOG.md). `## [Unreleased]` has four `**Breaking:**` entries: draw size limit (l.12), `instructions` field removal (l.30), `c_if` measurement rejection (l.121), OpenQASM import rejecting a measurement in an `if` block (l.129). The description folds the last two into one item ("in `Qx.c_if/4` and on OpenQASM import"), so the prose is internally coherent, but the count does not match CHANGELOG. Either say "four" or say "three, one of which covers both c_if and QASM import". Also the QASM raise is `QasmUnsupportedError`, the c_if one `ConditionalError`; the ROADMAP wording does not name either.

## Verified correct

- README c_if sentence: `validate_conditional_block/1` (operations.ex:887-904) raises `ConditionalError` for `{:c_if,_,_}` (nested) and `{:measure,_,_}`. The measure_x/measure_y claim is in CHANGELOG/docs; I did not trace that they lower to `{:measure,...}` (INFERRED).
- README QASM bullet: lowering.ex:219-220 raises `QasmUnsupportedError` with feature "measurement inside an `if` block". Verified.
- README error list: every name exists in errors.ex. `DrawSizeError` is raised by Draw (errors.ex docs). Grouping is accurate in spirit; omitted `RegisterError` (raised in register.ex and draw/tables.ex, both hidden calc-engine modules), which is defensible. "Qx.Hardware has its own error types": ConfigError, ExecutionError, NoMeasurementsError exist. Verified. I did not grep every raise site per exception (e.g. whether `StateShapeError` is raised from build vs. simulation), so the exact grouping is INFERRED.
- CONTRIBUTING tiers: openers "Tier 1: a core Qx type" and "Utility module:" match lib/ moduledocs and spec/api-design-principles.md section 3; minor-bump-before-1.0 matches AGENTS.md l.403. The `Qx` facade is tier 1 per spec. Note the old text named `Qx.Behaviours.*`; the new text drops it without saying whether it is tier 1/2 (it has a `QuantumState` behaviour module; tier not checked).
- CHANGELOG links: tags v0.2.0..v0.11.0 all exist; link refs now cover every version section through 0.11.0, and Unreleased compares from v0.11.0. mix.exs version is 0.11.0, README "Current version: 0.11.0" agrees. Verified.

## Doctests

- Gates examples: `Math.complex_matrix` builds `type: :c64`, so `{{2, 2}, {:c, 64}}` is right (verified). `controlled_gate`/`cnot` 2-qubit `{4, 4}` is correct by construction (INFERRED, not run).
- Minor style: `phase(:math.pi/4)` kept unspaced while the rest use `:math.pi() / 2`; harmonise.
- Simulation: examples now define `qc` in each block; fine. Splitting prose between blocks is correct for doctest isolation (a blank line plus text starts a new test; bindings do not carry over).
- RISK: `doctest Qx.Calc` is newly added but the CHANGELOG only names Simulation, Step, StateTable, Image. Qx.Calc examples (calc.ex:26-33, 57-58) end with `iex>` lines that have no expected value, and one has a `# comment` line between examples. I believe doctest accepts a final expression without expectation, but could not run it. Run `mix test test/qx/doctest_directives_test.exs` to confirm. Also add Gates/Calc to the CHANGELOG sentence, or drop the list.
- README Contributing: CONTRIBUTING.md link uses an absolute GitHub URL (good for hex.pm rendering); `feat/<slug>` / `fix/<slug>` convention not cross-checked against CONTRIBUTING.
