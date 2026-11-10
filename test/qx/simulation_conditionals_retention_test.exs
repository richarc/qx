defmodule Qx.SimulationConditionalsRetentionTest do
  # async: false — the memory test polls another process every millisecond;
  # keeping the scheduler quiet keeps the sampled peak honest.
  use ExUnit.Case, async: false

  # Covers the shot loop of `run_with_conditionals/3` (reached through
  # `Qx.run/2` for any circuit containing `c_if`):
  #
  #   * the result fields are what they always were (classical bits in shot
  #     order, counts derived from them, state/probabilities of the LAST shot);
  #   * the loop holds one statevector at a time, not one per shot.
  #
  # Statevectors are refc binaries (off-heap), so the retention is invisible
  # to process-heap metrics. `Process.info(pid, :binary)` sees it: measured
  # peak tracks shots × 2^n × 8 bytes within a few percent when every shot's
  # state is retained.

  @tolerance 1.0e-6

  # q0 decides c0; `c_if` copies it onto q1; the remaining qubits stay |0⟩.
  defp conditional_circuit(num_qubits, prepare) do
    Qx.create_circuit(num_qubits, 2)
    |> prepare.(0)
    |> Qx.measure(0, 0)
    |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
    |> Qx.measure(1, 1)
  end

  describe "run/2 with c_if — result fields" do
    test "deterministic circuit: exact classical bits, counts, state and probabilities" do
      result = 2 |> conditional_circuit(&Qx.x/2) |> Qx.run(5)

      assert result.shots == 5
      assert result.classical_bits == List.duplicate([1, 1], 5)
      assert result.counts == %{"11" => 5}

      assert Nx.shape(result.state) == {4}
      assert Nx.type(result.state) == {:c, 64}
      # Only X gates: the amplitude is exactly 1+0i, no phase to allow for.
      assert_all_close(Nx.real(result.state), [0.0, 0.0, 0.0, 1.0])
      assert_all_close(Nx.imag(result.state), [0.0, 0.0, 0.0, 0.0])
      assert_all_close(result.probabilities, [0.0, 0.0, 0.0, 1.0])
    end

    test "renormalize options give the same result on the conditional path" do
      circuit = conditional_circuit(2, &Qx.x/2)

      for renormalize <- [true, 1] do
        result = Qx.run(circuit, shots: 5, renormalize: renormalize)

        assert result.classical_bits == List.duplicate([1, 1], 5)
        assert result.counts == %{"11" => 5}
        assert_all_close(Nx.real(result.state), [0.0, 0.0, 0.0, 1.0])
        assert_all_close(Nx.imag(result.state), [0.0, 0.0, 0.0, 0.0])
        assert_all_close(result.probabilities, [0.0, 0.0, 0.0, 1.0])
      end
    end

    test "a single shot returns one outcome" do
      result = 2 |> conditional_circuit(&Qx.x/2) |> Qx.run(shots: 1)

      assert result.classical_bits == [[1, 1]]
      assert result.counts == %{"11" => 1}
      assert_all_close(result.probabilities, [0.0, 0.0, 0.0, 1.0])
    end

    test "probabilistic circuit: one outcome per shot, counts derived from them" do
      shots = 50
      result = 2 |> conditional_circuit(&Qx.h/2) |> Qx.run(shots)

      assert result.shots == shots
      assert length(result.classical_bits) == shots
      assert Enum.all?(result.classical_bits, &(&1 in [[0, 0], [1, 1]]))
      assert result.counts == Enum.frequencies_by(result.classical_bits, &Enum.join/1)
      assert result.counts |> Map.values() |> Enum.sum() == shots
    end

    test "classical bits are in shot order: the last entry matches the returned state" do
      circuit = conditional_circuit(2, &Qx.h/2)

      # Shots are unseeded, so order cannot be pinned outcome by outcome.
      # A reversed list is only visible when the first and last shots
      # differ (half the runs); 30 runs leave a 2^-30 chance of missing it.
      for _run <- 1..30 do
        result = Qx.run(circuit, 8)

        expected =
          case List.last(result.classical_bits) do
            [0, 0] -> [1.0, 0.0, 0.0, 0.0]
            [1, 1] -> [0.0, 0.0, 0.0, 1.0]
          end

        assert_all_close(result.probabilities, expected)
        assert_all_close(Nx.abs(result.state), expected)
      end
    end
  end

  describe "run/2 with c_if — memory" do
    @tag timeout: 30_000
    test "does not retain one statevector per shot" do
      num_qubits = 12
      shots = 200
      circuit = conditional_circuit(num_qubits, &Qx.h/2)

      # c64 = 8 bytes per amplitude. Retaining every shot's state peaks at
      # ~all_states_bytes (6.5 MB here). Retaining one still leaves GC slack:
      # measured 0.3–0.75 MB whatever n and shots are, so the run has to be
      # large enough for half of all_states_bytes to clear that comfortably.
      all_states_bytes = shots * Integer.pow(2, num_qubits) * 8

      {peak_bytes, result} = peak_binary_bytes(fn -> Qx.run(circuit, shots) end)

      assert length(result.classical_bits) == shots

      # The poller must have seen the run: at least one statevector is live
      # throughout. A peak of 0 would mean nothing was measured.
      assert peak_bytes > Integer.pow(2, num_qubits) * 8,
             "peak refc-binary memory #{peak_bytes} B: the poller did not observe the run"

      assert peak_bytes < div(all_states_bytes, 2),
             "peak refc-binary memory #{peak_bytes} B during the run; " <>
               "retaining every shot's state would be ~#{all_states_bytes} B"
    end
  end

  defp assert_all_close(tensor, expected) do
    actual = Nx.to_flat_list(tensor)
    assert length(actual) == length(expected)

    actual
    |> Enum.zip(expected)
    |> Enum.each(fn {a, e} -> assert_in_delta a, e, @tolerance end)
  end

  # Runs `fun` in its own process and returns {peak, result}, where peak is
  # the largest total size of refc binaries that process referenced, sampled
  # about once per millisecond while it ran.
  defp peak_binary_bytes(fun) do
    parent = self()
    runner = spawn_link(fn -> send(parent, {:done, self(), fun.()}) end)
    poll_peak(runner, 0)
  end

  defp poll_peak(runner, peak) do
    receive do
      {:done, ^runner, result} -> {peak, result}
    after
      1 -> poll_peak(runner, max(peak, binary_bytes(runner)))
    end
  end

  defp binary_bytes(pid) do
    case Process.info(pid, :binary) do
      {:binary, binaries} -> binaries |> Enum.map(fn {_id, size, _refs} -> size end) |> Enum.sum()
      nil -> 0
    end
  end
end
