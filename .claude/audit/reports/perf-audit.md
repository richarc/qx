# Qx Performance Audit

Scope: `lib/qx/calc.ex`, `calc_fast.ex`, `simulation.ex`, `gates.ex`, `math.ex`,
`operations.ex`, `state_init.ex`, `result_builder.ex`, `draw/**`, `hardware/ibm.ex`.
Default Nx backend: `Nx.BinaryBackend` (EXLA commented out in `mix.exs`).
States are `:c64` (float32 real/imag), ε ≈ 1.2e-7. `bench/` covers GHZ (n≤20),
QFT (n≤10) and renormalization only — none of the matrix-builder two-qubit
gates, IBM client, or draw modules are benchmarked.

---

## Findings

### Nx kernel discipline (weight 40)

**CRIT — `lib/qx/calc_fast.ex:67-91` (single-qubit gate path).**
Kernel uses gather + mask: `Nx.take(state, paired_indices)` plus two
`Nx.select` calls, then a third `Nx.select` to rebuild the state. Violates
the reshape-then-contract Iron Law; on `Nx.BinaryBackend` each gather is an
O(2^n) Erlang traversal of a binary, and the two takes effectively read
every pair twice.
Fix: reshape state to `{2^(n-k-1), 2, 2^k}`, do a 2×2 `Nx.dot` along the
qubit axis, reshape back — no gather, no select, same semantics on both
backends.

**CRIT — `lib/qx/calc_fast.ex:114-143, 157-185, 187-229`
(CNOT / CSWAP / Toffoli kernels).**
Same gather + select pattern: `Nx.iota` + `bitwise_and`/`right_shift` to
build masks, `Nx.take` of `Nx.bitwise_xor` indices, `Nx.select` over a
boolean mask. Each gate allocates 4–6 full-size index/mask tensors.
Fix: reshape state to expose the involved qubit axes (`{…,2,…,2,…}`) and
apply the permutation via `Nx.reverse`/`Nx.transpose` on those axes. CNOT
becomes a single `Nx.reverse` along the target axis on the half of state
selected by the control axis.

**HIGH — `lib/qx/calc_fast.ex:42-44`.**
`apply_single_qubit_gate_compiled` is a thin `defn` wrapper around the
`defnp apply_single_qubit_gate_direct` — two `defn` boundaries per gate
where one would do. Without EXLA there is no JIT cache that makes this
worth it; every call retraces.
Fix: collapse to one `defn`, or drop `defn` entirely once the kernel is
pure `Nx.reshape`/`Nx.dot`/`Nx.reshape` (which doesn't need `defn` on
BinaryBackend).

**HIGH — `lib/qx/calc_fast.ex:63, 133, 175-178, 219`.**
`qubit_mask`/`target_mask`/`swap_mask` computed inside `defn` via
`Nx.left_shift(1, bit_position)` against a runtime scalar tensor —
allocates a 1-element scalar tensor per gate on BinaryBackend rather than
using a host integer shift.
Fix: compute the mask host-side via `Bitwise.bsl/2` and pass as a literal,
or move the bit-position arithmetic out of `defn`.

**HIGH — `lib/qx/simulation.ex:402-407, 419-431`
(SWAP / iSWAP / CP / CY / CRx / CRy / CRz).**
These all materialize a full `2^n × 2^n` gate matrix via
`Gates.swap/3`, `Gates.iswap/3`, `Gates.controlled_gate/4` and apply with
`Nx.dot`. That's O(4^n) memory and O(8^n) FLOPs vs. the O(2^n)
statevector-direct path used for `cx`/`ccx`/`cswap`. At n=14 the SWAP
matrix alone is 4.3 GB of c64 — these OOM-crash or are unusably slow
above ~10 qubits.
Fix: add a two-qubit direct kernel in `CalcFast` parameterized by the 4×4
sub-block (reshape state, 4×4 `Nx.dot` on the inner axes, reshape back),
and route all of these through it.

**HIGH — `lib/qx/gates.ex:331-369, 406-426, 453-474, 499-525, 540-569`.**
`controlled_gate/4`, `swap/3`, `iswap/3`, `cswap/4`, `toffoli/4` use
`for i <- 0..(2^n - 1), reduce: …` and emit `Nx.put_slice` inside the
loop — a host-side O(2^n) traversal with one tensor allocation per basis
state. Iron Law violation (no host-side loops over 2^n) and `toffoli/4`
additionally stores a real-only `{state_size, state_size, 2}` tensor.
Fix: stop building these matrices entirely (see previous finding); if
needed for inspection, generate them once with `Nx.iota` + bitwise ops in
Nx-native code.

**MED — `lib/qx/simulation.ex:280-289` `apply_gate_step`.**
Every gate wraps the kernel in `assert_norm/1` → `validate_normalized!/2`
→ `Nx.to_number/1`. Compile-gated to `:test` only (`@assert_norm`), but
this also means `bench/` runs under `MIX_ENV=dev` skip the guard — note
that test-env perf numbers will be much worse than dev/prod.

**LOW — `lib/qx/math.ex:34-47` `kron`.**
Broadcasting-via-reshape Kronecker product is correct and efficient. No
issue.

### Host-side iteration over 2^n amplitudes (weight 20)

**CRIT — `lib/qx/simulation.ex:552-572, 575-599`
(`calculate_measurement_probability` + `collapse_to_measurement`).**
Both iterate `for i <- 0..(state_size - 1), reduce: …` on the host and
call `Nx.to_number(state[i])` inside the loop — `2^n` host syncs per
single-qubit measurement, and `collapse_to_measurement` then rebuilds a
fresh c64 tensor from a list of `%Complex{}`. This is the
conditional/c_if path, so it runs *for every shot* — at 1024 shots × n=10
that's ~10⁶ host syncs.
Fix: vectorise via `mask = Nx.bitwise_and(Nx.right_shift(Nx.iota(...),
pos), 1) == value`; `prob = Nx.sum(mask * Nx.abs(state)**2)`;
`collapsed = mask * state / Nx.sqrt(prob)`.

**HIGH — `lib/qx/simulation.ex:467-476` `generate_samples`.**
`Enum.scan` to build the cumulative distribution, then per-shot
`Enum.find_index` linear scan. O(shots × 2^n) host work.
Fix: convert `cumulative` to a tensor and use vectorized search
(`Nx.argmax` on `Nx.less_equal(rand_t, cum_t)` per batch), or do binary
search host-side.

**HIGH — `lib/qx/state_init.ex:64-69, 218-223, 341-354, 376-393, 100-103`.**
`basis_state/3`, `random_state/3`, `ghz_state/3`, `w_state/3`, and (via
`zero_state`) every fresh `QuantumCircuit.new/2` build a `2^n`-element
Elixir list of `%Complex{}` structs and then call `Nx.tensor(_, type:
:c64)`. At n=20 that's a 1M-element list traversal just to make |0…0⟩.
Fix: `basis_state` — `Nx.broadcast(Nx.tensor(0, type: :c64), {dim}) |>
Nx.put_slice([idx], Nx.tensor([1], type: :c64))`; `ghz`/`w` — `Nx.iota` +
bitwise + scalar amplitude; `random_state` — `Nx.random_uniform` real and
imag then combine.

**HIGH — `lib/qx/result_builder.ex:44-54` `build_probability_tensor`.**
Builds a `2^n` Elixir list and `List.replace_at` (O(n) per replace) over
each populated outcome — worst case O(2^n × non-zero outcomes).
Fix: `Nx.broadcast` zeros + `Nx.indexed_put` over the {index, probability}
pairs in a single tensor op.

**MED — `lib/qx/result_builder.ex:25-30`.**
`Enum.flat_map` + `List.duplicate(bits, count)` materializes a per-shot
classical-bit list of length `shots`. For a 100k-shot hardware job that's
a multi-MB list only used to feed `Enum.frequencies` downstream.
Fix: don't expand counts back into shots; leave `classical_bits: []` and
provide a deriver if any caller actually needs it.

**MED — `lib/qx/simulation.ex:315-327` `real_state_to_complex`.**
For non-c64 input does `Nx.to_flat_list` → `Enum.map(Complex.new)` →
`Nx.tensor` — two full host passes per `run/2`.
Fix: `Nx.as_type(state, :c64)` handles real → complex natively; for fresh
circuits, stash the already-complex initial state on the struct.

**MED — `lib/qx/simulation.ex:478-486` `extract_classical_bits`.**
Two nested `Enum.map`s per shot, building lists. Quadratic in
(shots × measurements).
Fix: build a `{shots, n_measurements}` bit tensor once via
`Nx.bitwise_and` on the samples tensor; convert at the API boundary only.

### Backend portability — must work on `Nx.BinaryBackend` (weight 15)

**MED — `lib/qx/simulation.ex:50-57` docstring.**
Doc example shows `backend: EXLA.Backend`, but EXLA is commented out of
`mix.exs`. Users following the doc verbatim hit `UndefinedFunctionError`.
Fix: either re-add EXLA as `optional: true` (and document the install
step) or update the docstring to say EXLA is a planned/optional path.

**LOW — `defn` correctness on BinaryBackend.**
All `defn` bodies use only ops BinaryBackend supports (`iota`,
`bitwise_*`, `select`, `take`, indexing, arithmetic). The portability
issue is *performance*, not correctness.

### Host-sync calls (`Nx.to_number/_list/_binary`) (subset of weight 10)

**HIGH — covered above:** `simulation.ex:563, 590` per-amplitude
`Nx.to_number` inside the conditional measurement loops.

**MED — `lib/qx/math.ex:270`, `lib/qx/validation.ex:53, 83, 93`.**
`Nx.to_number/1` in `Math.unitary?/1`, `Validation.valid_qubit?`,
`valid_register?`, `validate_normalized!/2`. The validation helpers are
gated to test in `Simulation`, but `valid_qubit?`/`valid_register?` are
public and callers may invoke them in loops without realising they sync.
Fix: document the host-sync cost in `@doc`.

**MED — `lib/qx/draw/tables.ex:91`, `lib/qx/draw/svg/charts.ex:32, 104`,
`lib/qx/draw/vega_lite.ex:33`, `lib/qx/draw.ex:212`.**
All draw entry points start with `Nx.to_flat_list(state_or_probs)`.
Expected for a renderer, but combined with the draw-layer unbounded-N
problem below, this is a large cost at high n.

### Allocation hotspots (weight 10)

**MED — `lib/qx/quantum_circuit.ex:98, 122, 142, 184, 602`.**
Every gate append uses `circuit.instructions ++ [instruction]` —
O(length(instructions)) per call → O(N²) to build an N-gate circuit.
usage_rules.elixir explicitly says "prefer to prepend `[new | list]`".
Same for `circuit.measurements ++ [measurement]` (line 184) and the
barrier instruction (operations.ex:602).
Fix: prepend and `Enum.reverse/1` once at execution start, or use a
private accumulator.

**MED — `lib/qx/simulation.ex:142-148, 156` `run_with_conditionals`.**
Materializes a list of `{state, cbits}` for *every shot* before
`Enum.frequencies` — at 100k shots × n=20 that's 100k × ~16 MB of state
retained until the reduce finishes. Worst-case process killer.
Fix: stream — accumulate counts directly inside the per-shot loop and
keep only the last state if it's required for the result.

**LOW — `lib/qx/simulation.ex:130-137, 160-167`.**
`%SimulationResult{…}` rebuild is fine; no leak.

### Hardware client robustness (weight 10)

**HIGH — `lib/qx/hardware/ibm.ex:91-93, 432-434`.**
IAM exchange: 10s `receive_timeout`, `retry: false`. All API calls
(`/jobs`, `/backends`, `/jobs/{id}`, `/jobs/{id}/results`): 30s
`receive_timeout`, `retry: false`. On a slow link or large result payload
(Sampler V2 with 100k shot samples is multi-MB JSON) 30s is tight, and
with no retry a single transient TCP RST kills the call.
Fix: bump `receive_timeout` to 60s on `/results` and `/backends`; enable
`retry: :safe_transient` (and 429 honoring via `retry_delay`) on GETs;
keep POSTs at `retry: false` for idempotence (or use an
`Idempotency-Key`).

**MED — `lib/qx/hardware/ibm.ex:316-374` (no streaming).**
`fetch_results` loads the full Sampler body into memory and decodes via
Jason; for high-shot jobs the body is tens of MB. `Req` defaults to
buffering. `samples` is then traversed by `Enum.frequencies_by/2`
(single pass — fine), but the list is held for that duration.
Fix: consider Jason streaming or accept buffering plus a `receive_buffer`
cap. `list_backends` has no paging — fine today but fragile.

**MED — `lib/qx/hardware/ibm.ex:407-417` `with_iam_refresh`.**
Catches `:unauthorized` and re-runs once with no jitter and no cap when
concurrent callers all hit 401 around expiry. Low-risk for a library;
note only.

**LOW — `lib/qx/hardware/ibm.ex:461-462` 429.**
`retry_after_seconds` is parsed; the client doesn't auto-retry. Document
that callers must handle the `{:rate_limited, n}` tuple.

### Draw-layer bounds (weight 5)

**HIGH — `lib/qx/draw/svg/charts.ex:31-69, 103-137`,
`lib/qx/draw/vega_lite.ex:32-50, 102-109`, `lib/qx/draw.ex:205-233`.**
Probability bar charts and histograms materialise every basis state into
the SVG / VegaLite data list with no truncation, no top-k, no warning.
For n=20 that's a 1M-bar SVG (>100 MB of XML; crashes most browsers and
LiveBook). `width / num_states` makes bars sub-pixel above ~10 qubits.
Fix: cap plotted states to top-K by probability (e.g. 64) or raise a
`Qx.Draw` error above some threshold (e.g. n > 12); document the cap.

**MED — `lib/qx/draw/tables.ex:91-110`.**
`state_table` produces one row per amplitude (2^n rows). `hide_zeros:
true` mitigates but the default is unbounded.
Fix: cap or warn — same threshold as above.

**LOW — `lib/qx/draw/svg/bloch.ex`.**
Single-qubit only; no 2^n dependence. Fine.

### Misc

**LOW — `lib/qx/math.ex:248-274` `unitary?/1`.**
Host-syncs via `Nx.to_number` but isn't in a hot path. Note only.

**LOW — `:math.pow(2, n)` + `trunc/1` for an integer power**.
Used in `lib/qx/state_init.ex:101, 183, 215, 342, 377`,
`lib/qx/quantum_circuit.ex:58, 221, 311`, `lib/qx/simulation.ex:553,
576`, `lib/qx/gates.ex:332, 407, 454, 500, 541`, `lib/qx/validation.ex:75`.
Prefer `Integer.pow(2, n)` (or `Bitwise.bsl(1, n)`) — exact, no float
rounding.

---

## Performance score

| Area | Weight | Score | Notes |
|---|---:|---:|---|
| Nx kernel discipline | 40 | 14 / 40 | Two CRIT gather+select kernels; matrix-materialisation for SWAP/iSWAP/CP/CY/CR*; host loops in `Gates` matrix builders |
| No host-side 2^n iteration | 20 | 6 / 20 | CRIT in conditional measurement path; HIGH in `state_init` + `result_builder` + sampling |
| Backend portability | 15 | 12 / 15 | Code is correct on BinaryBackend; doc misleads about EXLA availability |
| Allocation hygiene | 10 | 5 / 10 | Quadratic `instructions ++ […]`; per-shot state retention in conditionals |
| Hardware client robustness | 10 | 6 / 10 | Tight timeouts, no retry on transient errors, no streaming of large bodies |
| Draw-layer bounds | 5 | 1 / 5 | Unbounded N in charts / histograms / tables — fails above ~12 qubits |

**Performance score: 44 / 100**

Top three fixes (in expected-impact order):

1. Replace gather+select in `CalcFast.apply_*` with reshape + 2×2/4×4
   contraction kernels — removes the CRIT kernel pattern *and* unlocks
   replacing the SWAP/iSWAP/CY/CP/CR* matrix-materialisation path with
   the same 4×4 kernel.
2. Vectorise `calculate_measurement_probability` /
   `collapse_to_measurement`; remove `for i <- 0..(2^n - 1)` host loops
   from `state_init.ex` and `result_builder.ex`.
3. Cap or error in `Qx.Draw.plot` / `histogram` / `state_table` above
   ~12 qubits, and bump `Req` timeouts + enable `retry: :safe_transient`
   on `Hardware.Ibm` GETs.
