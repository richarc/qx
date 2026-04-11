## bd Issue

Implements [bd-___]: <!-- issue title -->

## Summary

- <!-- bullet point 1 -->
- <!-- bullet point 2 -->

## Changes

| File | Change |
|------|--------|
| `lib/...` | |
| `test/...` | |

## TDD Evidence

- [ ] Tests written before implementation code
- [ ] New tests confirmed failing before implementation began
- [ ] No existing test files modified

## Quality Checks

Run `mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix test` and paste results:

- [ ] `mix compile --warnings-as-errors` — pass
- [ ] `mix format --check-formatted` — pass
- [ ] `mix credo --strict` — pass
- [ ] `mix test` — pass (__ tests, 0 failures)

## Documentation

- [ ] All new public functions have `@doc` with Parameters, Examples, and Raises sections
- [ ] New modules have `@moduledoc`
- [ ] CHANGELOG.md updated (if user-facing change)

## Reviewer Checklist

- [ ] Acceptance criteria from bd issue are all addressed
- [ ] Error handling follows Qx conventions (raise exceptions, not `{:ok/_}` tuples)
- [ ] Input validation uses `Qx.Validation` at API boundaries
- [ ] No nested `case` statements
- [ ] Predicate functions end with `?`
