# Per-gate, per-n kernel micro-benchmark (BinaryBackend unless EXLA is loaded).
#
# Each scenario is a ONE-gate circuit run through the public `Qx.get_state/1`,
# i.e. the real `Qx.Simulation` hot path. The "empty" scenario per n is the
# fixed overhead (initial-state construction + result plumbing) — subtract it
# to read the gate's own cost.
#
# Gates that pre-v0.12 were applied via a materialised 2^n × 2^n matrix
# (CP / CRY / SWAP / iSWAP) are capped at `QX_BENCH_MAX_MATRIX_N` (default 10)
# because a 2^16 × 2^16 c64 matrix is ~34 GB. Set it to 16 once those gates
# are routed through the contraction kernel:
#
#     QX_BENCH_MAX_MATRIX_N=16 mix run bench/kernels_bench.exs

qubit_sizes = [4, 8, 12, 14, 16]

max_matrix_n =
  "QX_BENCH_MAX_MATRIX_N"
  |> System.get_env("10")
  |> String.to_integer()

mid = fn n -> div(n, 2) end
last = fn n -> n - 1 end

# {label, matrix_gate?, builder}
gates = [
  {"empty", false, fn c, _n -> c end},
  {"H q0", false, fn c, _n -> Qx.h(c, 0) end},
  {"H q_mid", false, fn c, n -> Qx.h(c, mid.(n)) end},
  {"H q_last", false, fn c, n -> Qx.h(c, last.(n)) end},
  {"CX", false, fn c, n -> Qx.cx(c, 0, last.(n)) end},
  {"CCX", false, fn c, n -> Qx.ccx(c, 0, mid.(n), last.(n)) end},
  {"CSWAP", false, fn c, n -> Qx.cswap(c, 0, mid.(n), last.(n)) end},
  {"CP", true, fn c, n -> Qx.cp(c, 0, last.(n), :math.pi() / 4) end},
  {"CRY", true, fn c, n -> Qx.cry(c, last.(n), 0, :math.pi() / 3) end},
  {"SWAP", true, fn c, n -> Qx.swap(c, 0, last.(n)) end},
  {"iSWAP", true, fn c, n -> Qx.iswap(c, 0, last.(n)) end}
]

scenarios =
  for n <- qubit_sizes,
      {label, matrix?, build} <- gates,
      not matrix? or n <= max_matrix_n,
      into: %{} do
    circuit = build.(Qx.create_circuit(n), n)
    {"#{label} n=#{n}", fn -> Qx.get_state(circuit) end}
  end

Benchee.run(
  scenarios,
  time: 2,
  warmup: 1,
  formatters: [Benchee.Formatters.Console]
)
