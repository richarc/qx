#!/usr/bin/env elixir
#
# GHZ State Scaling Benchmark
#
# Tests the performance of creating GHZ (Greenberger-Horne-Zeilinger) states
# across different qubit counts to demonstrate exponential scaling behavior.
#
# Usage:
#   mix run benchmark/ghz_scaling.exs
#
# This will generate:
#   - Console output with timing statistics
#   - HTML report at benchmark/results_ghz_scaling.html
#

# Helper module for GHZ circuit construction
defmodule GHZBenchmark do
  @moduledoc """
  Helper functions for GHZ state benchmarking.

  A GHZ state is a maximally entangled quantum state:
  |GHZ⟩ = (|000...0⟩ + |111...1⟩) / √2

  Created using:
  1. Hadamard gate on first qubit
  2. CNOT chain connecting all qubits
  """

  @doc """
  Builds a GHZ state circuit for n qubits.

  Circuit structure:
    H(0) - CX(0,1) - CX(1,2) - ... - CX(n-2, n-1)

  Gate count: 1 Hadamard + (n-1) CNOT gates
  """
  def build_ghz_circuit(qubits) do
    # Start with Hadamard on first qubit
    circuit = Qx.create_circuit(qubits)
              |> Qx.h(0)

    # Chain CNOT gates to entangle all qubits
    Enum.reduce(1..(qubits - 1), circuit, fn i, c ->
      Qx.cx(c, i - 1, i)
    end)
  end

  @doc """
  Runs the GHZ circuit and returns the final quantum state.

  This executes:
  1. Circuit construction (already done in build_ghz_circuit)
  2. State vector simulation (2^n complex amplitudes)
  3. All gate operations sequentially
  """
  def run_ghz(qubits) do
    build_ghz_circuit(qubits)
    |> Qx.get_state()
  end

  @doc """
  Validates that the GHZ state is correct by checking probabilities.

  Expected: 50% |000...0⟩ and 50% |111...1⟩, all others 0%
  """
  def verify_ghz(qubits) do
    state = run_ghz(qubits)
    probs = Qx.Math.probabilities(state) |> Nx.to_flat_list()

    # Check |000...0⟩ state (index 0)
    prob_zeros = Enum.at(probs, 0)
    # Check |111...1⟩ state (index 2^n - 1)
    prob_ones = Enum.at(probs, round(:math.pow(2, qubits)) - 1)

    # Both should be ~0.5, others should be ~0
    correct = abs(prob_zeros - 0.5) < 0.01 and abs(prob_ones - 0.5) < 0.01

    if correct do
      IO.puts("✓ GHZ-#{qubits} verification: PASSED (#{Float.round(prob_zeros * 100, 1)}% / #{Float.round(prob_ones * 100, 1)}%)")
    else
      IO.puts("✗ GHZ-#{qubits} verification: FAILED")
    end

    correct
  end
end

# Print header
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Qx Performance Benchmark: GHZ State Scaling")
IO.puts(String.duplicate("=", 70))
IO.puts("\nBackend: #{inspect(Nx.default_backend())}")
IO.puts("Platform: #{:erlang.system_info(:system_architecture)}")
IO.puts("OTP Version: #{:erlang.system_info(:otp_release)}")
IO.puts("Elixir Version: #{System.version()}")

# Verify correctness first (quick check)
IO.puts("\n--- Verification ---")
for qubits <- [5, 10, 15, 20] do
  GHZBenchmark.verify_ghz(qubits)
end

IO.puts("\n--- Starting Benchmark ---")
IO.puts("This will take approximately 2 minutes...\n")

# Run the benchmark
Benchee.run(
  %{
    "GHZ-5-qubits"  => fn -> GHZBenchmark.run_ghz(5) end,
    "GHZ-10-qubits" => fn -> GHZBenchmark.run_ghz(10) end,
    "GHZ-15-qubits" => fn -> GHZBenchmark.run_ghz(15) end,
    "GHZ-20-qubits" => fn -> GHZBenchmark.run_ghz(20) end
  },
  time: 10,              # Run each test for 10 seconds
  memory_time: 2,        # Measure memory for 2 seconds
  warmup: 2,             # 2 second warmup (JIT compilation)
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmark/results_ghz_scaling.html"}
  ],
  print: [
    fast_warning: false  # Don't warn about fast functions
  ]
)

# Print summary
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Benchmark complete!")
IO.puts(String.duplicate("=", 70))
IO.puts("\n📊 HTML report saved to: benchmark/results_ghz_scaling.html")
IO.puts("\n💡 Performance Tips:")
IO.puts("   - For GPU acceleration, set Nx backend before running:")
IO.puts("     export NX_DEFAULT_BACKEND=emlx  # Apple Silicon")
IO.puts("     export NX_DEFAULT_BACKEND=exla  # NVIDIA/AMD")
IO.puts("\n   - Compare results by running with different backends")
IO.puts("   - See benchmark/backend_comparison.exs for automated comparison\n")
