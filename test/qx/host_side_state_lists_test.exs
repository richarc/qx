defmodule Qx.HostSideStateListsTest do
  # async: true is safe: the heap limit is set on one spawned process and is
  # not affected by other tests.
  use ExUnit.Case, async: true

  import Bitwise

  alias Qx.ResultBuilder
  alias Qx.StateInit

  # Heap limit for the "no host-side 2^n list" tests, in words. Measured on
  # 2026-11-14 (OTP 29, Nx 0.13.0, BinaryBackend, 2^20 elements, cold VM, one
  # fresh `mix run` per probe):
  #
  #   Nx.indexed_put build (basis state or probabilities): survives at 1,598
  #   list-based from_counts/3:                            killed at 22,820,312
  #   list-based basis_state/2:                            killed at 41,523,437
  #
  # 2^17 = 131,072 words is 82x above the first and 174x below the second.
  # Tensor data is an off-heap refc binary and is not counted.
  @heap_limit_words 1 <<< 17

  @dimension 1 <<< 20

  defp run_with_heap_limit(fun) do
    parent = self()

    {pid, ref} =
      spawn_monitor(fn ->
        Process.flag(:max_heap_size, %{
          size: @heap_limit_words,
          kill: true,
          error_logger: false
        })

        outcome =
          try do
            {:returned, fun.()}
          rescue
            exception -> {:raised, exception}
          end

        send(parent, {:outcome, self(), outcome})
      end)

    receive do
      {:outcome, ^pid, outcome} ->
        Process.demonitor(ref, [:flush])
        outcome

      {:DOWN, ^ref, :process, ^pid, reason} ->
        reason
    after
      30_000 -> flunk("the heap-limited process neither returned nor died within 30 s")
    end
  end

  describe "StateInit.basis_state/3 results" do
    test "default type is c64 with shape {dimension}" do
      state = StateInit.basis_state(1, 4)

      assert Nx.type(state) == {:c, 64}
      assert Nx.shape(state) == {4}
    end

    test "accepts :c128 and the tuple form {:c, 64}" do
      assert Nx.type(StateInit.basis_state(1, 4, :c128)) == {:c, 128}
      assert Nx.type(StateInit.basis_state(1, 4, {:c, 64})) == {:c, 64}
    end

    test "a nil type gives c64, as when the type was inferred from complex values" do
      state = StateInit.basis_state(1, 4, nil)

      assert Nx.type(state) == {:c, 64}
      assert Nx.to_flat_list(state) |> Enum.at(1) == Complex.new(1.0, 0.0)
    end

    test ":c128 has amplitude 1 at the index and 0 elsewhere" do
      zero = Complex.new(0.0, 0.0)

      assert Nx.to_flat_list(StateInit.basis_state(2, 4, :c128)) ==
               [zero, zero, Complex.new(1.0, 0.0), zero]
    end

    test "has amplitude 1 at the index and 0 elsewhere (first, middle, last)" do
      one = Complex.new(1.0, 0.0)
      zero = Complex.new(0.0, 0.0)

      for index <- [0, 3, 7] do
        expected = List.replace_at(List.duplicate(zero, 8), index, one)
        assert Nx.to_flat_list(StateInit.basis_state(index, 8)) == expected
      end
    end

    test "an invalid type raises ArgumentError" do
      assert_raise ArgumentError, ~r/invalid numerical type/, fn ->
        StateInit.basis_state(1, 4, :bogus)
      end
    end

    test "a real float type returns a one-hot tensor of that type" do
      state = StateInit.basis_state(1, 4, :f32)

      assert Nx.type(state) == {:f, 32}
      assert Nx.to_flat_list(state) == [0.0, 1.0, 0.0, 0.0]
    end

    test "an integer type returns a one-hot tensor of that type" do
      state = StateInit.basis_state(1, 4, :s32)

      assert Nx.type(state) == {:s, 32}
      assert Nx.to_flat_list(state) == [0, 1, 0, 0]
    end
  end

  describe "ResultBuilder.from_counts/3 probabilities" do
    test "are f32" do
      result = ResultBuilder.from_counts(%{"00" => 1, "11" => 3}, 4, 2)

      assert Nx.type(result.probabilities) == {:f, 32}
      assert Nx.to_flat_list(result.probabilities) == [0.25, 0.0, 0.0, 0.75]
    end

    test "empty counts give all zeros of shape {2^num_bits}" do
      result = ResultBuilder.from_counts(%{}, 0, 2)

      assert Nx.type(result.probabilities) == {:f, 32}
      assert Nx.to_flat_list(result.probabilities) == [0.0, 0.0, 0.0, 0.0]
    end

    test "an outcome whose index is >= 2^num_bits is dropped" do
      result = ResultBuilder.from_counts(%{"00" => 1, "111" => 1}, 2, 2)

      assert Nx.to_flat_list(result.probabilities) == [0.5, 0.0, 0.0, 0.0]
    end

    test "only out-of-range outcomes give all zeros" do
      result = ResultBuilder.from_counts(%{"111" => 1, "100" => 1}, 2, 2)

      assert Nx.to_flat_list(result.probabilities) == [0.0, 0.0, 0.0, 0.0]
    end

    test "two keys with the same index: the later key in map order wins" do
      # "01" and "1" both parse to index 1. Map order is "01" then "1", so the
      # value for "1" (3/4) overwrites the value for "01" (1/4); they are not
      # summed. The duplicates are collapsed before the Nx scatter, which does
      # not define an order for repeated indices.
      result = ResultBuilder.from_counts(%{"01" => 1, "1" => 3}, 4, 2)

      assert Nx.to_flat_list(result.probabilities) == [0.0, 0.75, 0.0, 0.0]
    end
  end

  describe "no host-side list of 2^n elements" do
    test "basis_state/2 at dimension 2^20 returns within the heap limit" do
      assert {:returned, state} =
               run_with_heap_limit(fn -> StateInit.basis_state(@dimension - 1, @dimension) end)

      assert Nx.shape(state) == {@dimension}
      assert Nx.to_number(state[@dimension - 1]) == Complex.new(1.0, 0.0)
      assert Nx.to_number(Nx.sum(Nx.abs(state))) == 1.0
    end

    test "from_counts/3 at 20 bits returns within the heap limit" do
      counts = %{String.duplicate("1", 20) => 1}

      assert {:returned, result} =
               run_with_heap_limit(fn -> ResultBuilder.from_counts(counts, 1, 20) end)

      assert Nx.shape(result.probabilities) == {@dimension}
      assert Nx.to_number(result.probabilities[@dimension - 1]) == 1.0
      assert Nx.to_number(Nx.sum(result.probabilities)) == 1.0
    end

    # Control: proves the harness kills a real 2^20-element host build.
    test "a call that does build a 2^20-element list is killed" do
      assert :killed = run_with_heap_limit(fn -> Enum.to_list(1..@dimension) end)
    end
  end

  describe "Validation.valid_register?/2" do
    test "returns false, without raising, for a negative num_qubits" do
      register = %{state: Nx.tensor([1.0, 0.0], type: :c64), num_qubits: -1}

      refute Qx.Validation.valid_register?(register)
    end

    test "returns false, without raising, for a non-integer num_qubits" do
      register = %{state: Nx.tensor([1.0, 0.0], type: :c64), num_qubits: 1.0}

      refute Qx.Validation.valid_register?(register)
    end
  end
end
