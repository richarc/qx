# Measurement micro-benchmark (BinaryBackend unless EXLA is loaded).
#
# Three hot paths:
#
#   * "sample"  — `Qx.run/2` on an H^⊗n + measure_all circuit (no
#                 conditionals): one final state, then `shots` samples from
#                 the 2^n outcome distribution (uniform, so a linear search
#                 averages 2^(n-1) steps per shot).
#   * "c_if"    — `Qx.run/2` on a circuit with a mid-circuit measurement and
#                 a `c_if`: the whole circuit re-runs per shot, with one
#                 single-qubit measurement + collapse per shot.
#   * "steps"   — `Qx.steps/2` materialised on a circuit with two
#                 mid-circuit measurements (seeded, so every run follows the
#                 same trajectory).
#
# Before v0.12 the sample path was O(shots × 2^n) and every mid-circuit
# measurement made ~3·2^n host syncs. The slowest pre-v0.12 scenarios can be
# skipped when benchmarking an older commit:
#
#     QX_BENCH_MAX_SAMPLE_N=12 mix run bench/measurement_bench.exs

max_sample_n =
  "QX_BENCH_MAX_SAMPLE_N"
  |> System.get_env("16")
  |> String.to_integer()

hadamard_all = fn c, n -> Enum.reduce(0..(n - 1), c, &Qx.h(&2, &1)) end

sample_scenarios =
  for n <- [8, 12, 16],
      n <= max_sample_n,
      shots <- [1024, 100_000],
      into: %{} do
    circuit = Qx.create_circuit(n, n) |> hadamard_all.(n) |> Qx.measure_all()
    {"sample n=#{n} shots=#{shots}", fn -> Qx.run(circuit, shots) end}
  end

# H on every qubit, measure q0 mid-circuit, X on the last qubit iff c0 = 1,
# then measure the last qubit.
c_if_scenarios =
  for n <- [4, 8, 12], into: %{} do
    circuit =
      Qx.create_circuit(n, 2)
      |> hadamard_all.(n)
      |> Qx.measure(0, 0)
      |> Qx.c_if(0, 1, fn c -> Qx.x(c, n - 1) end)
      |> Qx.measure(n - 1, 1)

    {"c_if n=#{n} shots=256", fn -> Qx.run(circuit, 256) end}
  end

# GHZ-n with two mid-circuit measurements, the second after more gates.
steps_scenarios =
  for n <- [12, 14], into: %{} do
    circuit =
      Qx.create_circuit(n, 2)
      |> Qx.h(0)
      |> then(fn c -> Enum.reduce(1..(n - 1), c, &Qx.cx(&2, &1 - 1, &1)) end)
      |> Qx.measure(div(n, 2), 0)
      |> Qx.h(n - 1)
      |> Qx.measure(n - 1, 1)

    {"steps n=#{n} (2 measurements)", fn -> circuit |> Qx.steps(seed: 1) |> Enum.to_list() end}
  end

Benchee.run(
  sample_scenarios |> Map.merge(c_if_scenarios) |> Map.merge(steps_scenarios),
  time: 2,
  warmup: 1,
  formatters: [Benchee.Formatters.Console]
)
