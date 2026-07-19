# Scratchpad — stateinit-vector-deprecation

## Decisions

- **Tests stay on old names.** User chose this. Verified `--warnings-as-errors`
  does not promote `@deprecated` warnings (test: `elixirc --warnings-as-errors`
  on a deprecated-caller module → exit 0, warning only). So the existing
  `state_init_test.exs` callers keep the suite green AND serve as live
  delegation coverage. No need to touch the file (which the hook blocks anyway).

- **New test file, not an edit.** `test/qx/state_init_vector_test.exs` is the
  additive home for `_vector` coverage. The test-guard hook blocks `Write` to
  ANY `*_test.exs` path, so even this new file needs explicit approval at work
  time — expected, surface it then.

- **Arity note.** ROADMAP says `bell_state_vector/2` and `ghz_state_vector/1`,
  but current `ghz_state` is `/2` (`num_qubits, type \\ :c64`). Keeping the
  optional `type` param → `ghz_state_vector/2` (callable as `/1`). The `/1`
  in the roadmap is the informal primary arity.

- **Not breaking.** Additive + deprecation. No major bump. Removal deferred to
  v0.9 (ROADMAP line 94).

## Open questions

- (none blocking)

## Dead ends

- Considered making the new test additive via a `describe` block appended to
  the existing `state_init_test.exs` — rejected: the hook blocks editing it,
  and a separate file is cleaner anyway.
