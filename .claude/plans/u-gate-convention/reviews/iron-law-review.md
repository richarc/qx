# Iron Law Violations Report — `feat/u-gate-convention`

## Summary

- Files scanned: 4 (`lib/qx/gates.ex`, `lib/qx/operations.ex`, `lib/qx.ex`, `test/qx/u_gate_convention_test.exs`)
- Iron Laws checked: 7 of 7 (Qx-specific set; Phoenix/Ecto/Oban laws not applicable)
- **Violations found: 0**

## Iron Law #6 — Breaking Change Analysis (key judgement)

**Verdict: #6 does NOT trigger. No CHANGELOG entry or version bump required.**

Reasoning:

- `@spec u(circuit(), non_neg_integer(), number(), number(), number()) :: circuit()` in `lib/qx.ex` is **unchanged**.
- `def u(%QuantumCircuit{} = circuit, qubit, theta, phi, lambda)` in `lib/qx/operations.ex` is **unchanged** (function head, guards, body untouched).
- `def u(theta, phi, lambda)` in `lib/qx/gates.ex` is **unchanged**.
- The diff is `@doc` text only — clarifying the OpenQASM 3.0 / Qiskit `UGate` convention that the implementation already follows. Docstring improvements are not a breaking change under SemVer: they change no observable behaviour, no typespec, no error surface, and no call signature.
- The plan explicitly states "no API change, no kernel change" and "Complexity: 1 (LOW) — docstring precision + test hardening for an already-correct gate". This is consistent with the file examination.

## Per-Law Results

| # | Law | Verdict |
|---|-----|---------|
| 1 | No `String.to_atom/1` on caller-supplied strings | CLEAN — zero occurrences in test or lib files |
| 2 | No process (GenServer/Agent/Task) without runtime reason | CLEAN — test file uses `ExUnit.Case, async: true` only; no processes spawned |
| 3 | Prefer reshape+contraction over gather/mask in Nx kernels | N/A — no `defn` or Nx kernel code touched |
| 4 | `defn` correct on `Nx.BinaryBackend` | N/A — no `defn` code touched |
| 5 | No host-side loops over 2^n amplitudes | N/A — no amplitude-iteration code touched |
| 6 | Breaking public-API change → CHANGELOG + major-version bump | CLEAN — doc-only change, no signature/spec/behaviour change |
| 7 | Public functions raise typed `Qx.*Error`; no raw errors leak | N/A — no function body or error-path code touched |

## Test File Notes

`test/qx/u_gate_convention_test.exs` is well-formed:

- `async: true` is correct (pure Nx computation, no shared state).
- `assert_in_delta` comparisons use a sensible `@delta 1.0e-6`.
- The `for` comprehension generating parameterised tests at compile time is idiomatic ExUnit; no runtime process spawning.
- `Nx.to_list/1` + `List.flatten/1` then iterating over 4 complex entries is not an O(2^n) host-side loop — it is over the 4 elements of a fixed 2×2 matrix. Law #5 is satisfied.
- No `String.to_atom/1` calls anywhere in the file.

## Conclusion

**All Iron Laws pass. The branch is clear to proceed to merge gate (`/phx:review` PASS).**
