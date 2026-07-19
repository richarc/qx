# Scratchpad — public-surface-declaration

## Decisions

- **Scope = broad** (user). Closes ROADMAP #23, #29, #30, #24 in one commit.
- **Qx.Validation → internal** (user, #30). `@moduledoc false`, drop the 3
  moduledoc examples. Rationale: the public contract is the typed `Qx.*Error`
  exceptions, not the validation hub; no tutorial/README refs; audit omitted it
  from the 9. Functions stay callable; `valid_qubit?`/`valid_register?` `@doc`
  doctests still run.
- **Qx.StateInit → public** (#29), resolved automatically by being one of the 9.

## Verified facts (from planning)

- `CLAUDE.md` is a symlink → edit `AGENTS.md` once.
- Two list sites in `AGENTS.md`: line **329** (complexity table) + line **390**
  (Iron Law #6). Both reconciled in Phase 1.
- `lib/qx/draw/svg/circuit.ex` **already** `@moduledoc false` → verify, skip.
- The other 11 internal modules each have a prose `@moduledoc """…"""`, **zero
  doctests** → no test impact from hiding them.
- `lib/qx.ex` `## Modules` already lists Qubit, QuantumCircuit, Operations,
  Patterns, Simulation, Draw, Math, Export.OpenQASM. Missing → add Register,
  StateInit, Hardware, Hardware.Config.
- **Doctest delta: 245 → 242** (only Validation's 3 moduledoc doctests drop).
  `test/qx/validation_test.exs:3` keeps `doctest Qx.Validation`.

## Open questions

- (none blocking)

## Dead ends

- (none yet)
