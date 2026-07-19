---
module: "Qx.Hardware.Ibm"
date: "2026-07-01"
problem_type: build_issue
component: config
symptoms:
  - "A code reviewer (or agent) flags `Application.compile_env(:app, :key)` as raising `ArgumentError` at compile time when the key is only set in `config/test.exs`, predicting `mix compile` fails in `:dev`/`:prod`"
  - "The claim contradicts a passing build: `mix compile --warnings-as-errors` already succeeded in `:dev` with the key unset"
root_cause: "`Application.compile_env/2` is `compile_env/3` with an implicit `nil` default — it returns `nil` when the key is absent, it does NOT raise. Only the bang form `Application.compile_env!/2` raises on a missing key. The reviewers conflated the two."
severity: low
iron_law_number: null
tags: [compile-env, application-config, false-positive, review, test-only-config, retry-delay, req]
related_solutions: []
---

# `compile_env/2` defaults to `nil` (does not raise); the test-only config knob pattern

## Symptoms

- Two review agents independently flagged
  `@ibm_retry_delay Application.compile_env(:qx, :ibm_retry_delay)` as a BLOCKER:
  "raises `ArgumentError` when the key is missing, so `:dev`/`:prod` won't
  compile."
- But `mix compile --warnings-as-errors` had already passed in `:dev`, where the
  key is unset (it lives only in `config/test.exs`).

## Investigation

1. The key `:ibm_retry_delay` is set ONLY in `config/test.exs` (guarded by
   `config_env() == :test`); unset in dev/prod.
2. Forced clean recompile in `:dev`: `rm -rf _build/dev/lib/qx/ebin && mix compile
   --force --warnings-as-errors` → **compiled cleanly, no `ArgumentError`**.
3. Elixir semantics: `Application.compile_env(app, key, default \\ nil)`. The
   2-arity call is the 3-arity with `default = nil` → returns `nil` if unset.
   `Application.compile_env!/2` (bang) is the one that raises.

## Root Cause

Confusion between `compile_env/2` (nil default, safe) and `compile_env!/2`
(raises). A recurring review false-positive — settle it empirically with a
forced clean recompile in the env where the key is absent, not by argument.

## Solution

The code was correct. Two small hardening steps:

```elixir
# Pass the default explicitly so intent is unambiguous (silences the flag).
@ibm_retry_delay Application.compile_env(:qx, :ibm_retry_delay, nil)
```

### The test-only config knob pattern (why this exists)

Prod must keep Req's smart exponential backoff; the retry test must be instant.
Gate a zero delay through config so the two don't fight:

```elixir
# config/test.exs
config :qx, ibm_retry_delay: 0        # test only; dev/prod leave it unset

# lib/qx/hardware/ibm.ex
@ibm_retry_delay Application.compile_env(:qx, :ibm_retry_delay, nil)

defp maybe_put_retry_delay(options) do
  case @ibm_retry_delay do
    nil -> options                                    # prod → Req default backoff
    delay when is_integer(delay) ->                   # test → fixed (0 ms)
      Keyword.put(options, :retry_delay, delay)
  end
end
```

`Req`'s `:retry_delay` accepts a **plain integer** (fixed millis) OR a
`fun(retry_count)` — verified in `deps/req/lib/req/steps.ex`
(`calculate_retry_delay` matches `delay when is_integer(delay)`). No need to wrap
the integer in a function.

## Prevention

- [ ] Iron Law? No.
- Specific guidance:
  - `compile_env/2` returns `nil` for a missing key; only `compile_env!` raises.
    When a reviewer claims a compile-time raise, **verify with a forced clean
    recompile in the unset env** before treating it as a blocker.
  - For test-only tuning (retry delays, timeouts, feature toggles) that must NOT
    change prod behaviour: read `compile_env(app, key, nil)`, set the key only in
    `config/test.exs`, and branch on `nil` = "use the library default".

## Related

- ROADMAP v0.9 (Security & Hardening), plan: ibm-client-hardening.
- Pairs with the `:safe_transient` / Bypass retry-test solution (same plan).
