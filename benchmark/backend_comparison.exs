#!/usr/bin/env elixir
#
# Backend Comparison Benchmark
#
# Compares performance across different Nx backends (CPU vs GPU) using
# a 20-qubit GHZ state as the benchmark workload.
#
# Usage:
#   mix run benchmark/backend_comparison.exs
#
# This will test all available backends and show speedup comparisons.
#

# Reuse GHZ helper from scaling benchmark
defmodule GHZBenchmark do
  def build_ghz_circuit(qubits) do
    circuit = Qx.create_circuit(qubits) |> Qx.h(0)

    Enum.reduce(1..(qubits - 1), circuit, fn i, c ->
      Qx.cx(c, i - 1, i)
    end)
  end

  def run_ghz(qubits) do
    build_ghz_circuit(qubits) |> Qx.get_state()
  end
end

# Backend detection and configuration
defmodule BackendConfig do
  @doc """
  Detects available backends and returns a map of backend configurations.
  """
  def detect_backends do
    backends = %{}

    # Binary backend - always available
    backends = Map.put(backends, "Binary Backend (Baseline)", %{
      backend: Nx.BinaryBackend,
      description: "Pure Elixir implementation (no acceleration)"
    })

    # EXLA CPU - should be available (it's in dependencies)
    backends = if Code.ensure_loaded?(EXLA.Backend) do
      Map.put(backends, "EXLA CPU", %{
        backend: EXLA.Backend,
        description: "Google XLA with CPU optimization (10-50x faster)"
      })
    else
      backends
    end

    # EMLX GPU - Apple Silicon only
    backends = if Code.ensure_loaded?(EMLX.Backend) do
      try do
        # Test if GPU device is available
        Nx.default_backend({EMLX.Backend, device: :gpu})
        test_tensor = Nx.tensor([1, 2, 3])
        Nx.to_number(test_tensor[0])  # Force evaluation

        Map.put(backends, "EMLX GPU (Metal)", %{
          backend: {EMLX.Backend, device: :gpu},
          description: "MLX with Metal GPU (Apple Silicon M1/M2/M3/M4)"
        })
      rescue
        _ -> backends  # GPU not available
      end
    else
      backends
    end

    # EXLA CUDA - NVIDIA GPUs
    backends = if Code.ensure_loaded?(EXLA.Backend) do
      # Use Task to safely check for CUDA without crashing main process
      task = Task.async(fn ->
        # Suppress error logs during detection
        Logger.configure(level: :emergency)

        result = try do
          _client = EXLA.Client.fetch!(:cuda)
          true
        rescue
          _ -> false
        catch
          :exit, _ -> false
        end

        # Restore normal logging
        Logger.configure(level: :warning)
        result
      end)

      case Task.yield(task, 1000) || Task.shutdown(task) do
        {:ok, true} ->
          Map.put(backends, "EXLA CUDA (NVIDIA GPU)", %{
            backend: {EXLA.Backend, client: :cuda},
            description: "Google XLA with CUDA acceleration"
          })
        _ ->
          backends  # CUDA not available
      end
    else
      backends
    end

    # EXLA ROCm - AMD GPUs
    backends = if Code.ensure_loaded?(EXLA.Backend) do
      # Use Task to safely check for ROCm without crashing main process
      task = Task.async(fn ->
        # Suppress error logs during detection
        Logger.configure(level: :emergency)

        result = try do
          _client = EXLA.Client.fetch!(:rocm)
          true
        rescue
          _ -> false
        catch
          :exit, _ -> false
        end

        # Restore normal logging
        Logger.configure(level: :warning)
        result
      end)

      case Task.yield(task, 1000) || Task.shutdown(task) do
        {:ok, true} ->
          Map.put(backends, "EXLA ROCm (AMD GPU)", %{
            backend: {EXLA.Backend, client: :rocm},
            description: "Google XLA with ROCm acceleration"
          })
        _ ->
          backends  # ROCm not available
      end
    else
      backends
    end

    backends
  end

  @doc """
  Prepares input map for Benchee with detected backends.
  """
  def prepare_inputs(backends) do
    backends
    |> Enum.map(fn {name, config} -> {name, config} end)
    |> Enum.into(%{})
  end
end

# Print header
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Qx Backend Comparison Benchmark")
IO.puts(String.duplicate("=", 70))
IO.puts("\nDetecting available backends...\n")

# Detect backends
backends = BackendConfig.detect_backends()

# Show detected backends
IO.puts("Found #{map_size(backends)} backend(s):\n")
Enum.each(backends, fn {name, config} ->
  IO.puts("  ✓ #{name}")
  IO.puts("    #{config.description}\n")
end)

if map_size(backends) < 2 do
  IO.puts("\n⚠️  Warning: Only one backend available.")
  IO.puts("   Install EMLX or EXLA with GPU support for comparison.\n")
end

IO.puts("Test workload: 20-qubit GHZ state")
IO.puts("  - State vector size: 1,048,576 complex amplitudes")
IO.puts("  - Memory required: ~8 MB")
IO.puts("  - Gates: 1 Hadamard + 19 CNOT gates")
IO.puts("\n--- Starting Benchmark ---")
IO.puts("This will take approximately 2 minutes...\n")

# Prepare inputs for Benchee
inputs = BackendConfig.prepare_inputs(backends)

# Run the benchmark
Benchee.run(
  %{
    "GHZ-20-qubits" => fn _backend_config ->
      GHZBenchmark.run_ghz(20)
    end
  },
  inputs: inputs,
  time: 10,
  memory_time: 2,
  warmup: 2,
  before_scenario: fn backend_config ->
    # Set the backend before running the scenario
    Nx.default_backend(backend_config.backend)
    backend_config
  end,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmark/results_backend_comparison.html"}
  ],
  print: [
    fast_warning: false
  ]
)

# Print summary and recommendations
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Benchmark complete!")
IO.puts(String.duplicate("=", 70))
IO.puts("\n📊 HTML report saved to: benchmark/results_backend_comparison.html")
IO.puts("\n💡 Interpretation Guide:")
IO.puts("   - IPS (iterations per second): Higher is better")
IO.puts("   - Comparison ratios show speedup vs slowest backend")
IO.puts("   - Memory should be similar across backends (~8 MB)")
IO.puts("\n   Expected speedups:")
IO.puts("   - EXLA CPU vs Binary: 10-50x faster")
IO.puts("   - GPU vs CPU: 2-10x faster (varies by hardware)")
IO.puts("\n🚀 Performance Tips:")
IO.puts("   - GPU acceleration benefits increase with circuit size")
IO.puts("   - First run includes JIT compilation (warmup handles this)")
IO.puts("   - For production, use EXLA CPU minimum, GPU if available\n")
