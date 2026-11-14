defmodule Qx.DrawSizeCapTest do
  @moduledoc """
  The state-sized draw functions refuse to build more than
  `2^max_qubits` bars/rows (default 12, so 4096) and raise
  `Qx.DrawSizeError` naming the override (plan: draw-state-size-cap).

  Inputs are built directly rather than simulated, so the sizes are
  exact and the tests stay fast.
  """
  use ExUnit.Case, async: true

  import Bitwise

  alias Qx.Draw
  alias Qx.Draw.StateTable

  @draw_functions [:plot, :histogram, :state_table, :counts]
  @tensor_functions [:plot, :histogram, :state_table]

  # Heap limit for the guard-before-build tests, in words. Measured on
  # 2026-11-14 (OTP 29, Nx 0.13.0, BinaryBackend): a guarded call needs
  # the VM minimum (233 words); an unguarded 2^20-element call needs
  # 75.5M words (plot, histogram) or 155M words (state_table) to
  # survive. 2^17 sits more than 500x from either side.
  @guard_heap_words 1 <<< 17

  defp probabilities(size), do: Nx.broadcast(Nx.tensor(0.0, type: :f32), {size})

  defp state(size), do: Nx.broadcast(Nx.tensor(0.0, type: :c64), {size})

  defp result(fields) do
    struct!(
      %Qx.SimulationResult{
        probabilities: probabilities(2),
        classical_bits: [],
        state: nil,
        shots: 1,
        counts: %{}
      },
      fields
    )
  end

  # A counts map with `outcomes` distinct bit-string keys.
  defp counts(outcomes) do
    Map.new(0..(outcomes - 1), fn i ->
      {i |> Integer.to_string(2) |> String.pad_leading(16, "0"), 1}
    end)
  end

  # The argument for `function` that would draw `size` bars/rows: tensor
  # elements for plot/histogram/state_table, distinct outcomes for counts.
  defp input(:plot, size), do: result(probabilities: probabilities(size))
  defp input(:histogram, size), do: probabilities(size)
  defp input(:state_table, size), do: state(size)
  defp input(:counts, size), do: result(counts: counts(size))

  defp call(:plot, input, options), do: Draw.plot(input, options)
  defp call(:histogram, input, options), do: Draw.histogram(input, options)
  defp call(:state_table, input, options), do: Draw.state_table(input, options)
  defp call(:counts, input, options), do: Draw.counts(input, options)

  defp draw(function, size, options \\ []), do: call(function, input(function, size), options)

  defp facade(function, size, options \\ [])

  defp facade(:plot, size, options),
    do: Qx.draw(result(probabilities: probabilities(size)), options)

  defp facade(:histogram, size, options), do: Qx.draw_histogram(probabilities(size), options)
  defp facade(:state_table, size, options), do: Qx.draw_state(state(size), options)
  defp facade(:counts, size, options), do: Qx.draw_counts(result(counts: counts(size)), options)

  defp assert_drawn(%VegaLite{}), do: :ok
  defp assert_drawn(%StateTable{}), do: :ok

  # Runs `fun` in a process that is killed if its heap passes
  # @guard_heap_words. Returns the exception `fun` raised, :returned,
  # or :killed. Tensor data is an off-heap binary, so only a host-side
  # build of the 2^n list can reach the limit.
  defp run_with_heap_limit(fun) do
    parent = self()

    {pid, ref} =
      spawn_monitor(fn ->
        Process.flag(:max_heap_size, %{
          size: @guard_heap_words,
          kill: true,
          error_logger: false
        })

        outcome =
          try do
            fun.()
            :returned
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
    end
  end

  describe "over the default cap" do
    for function <- @tensor_functions, size <- [4097, 8192] do
      test "#{function}/2 raises Qx.DrawSizeError for a #{size}-element tensor" do
        error = assert_raise Qx.DrawSizeError, fn -> draw(unquote(function), unquote(size)) end

        assert error.size == unquote(size)
        assert error.limit == 4096
        assert error.max_qubits == 12
        assert error.message =~ "max_qubits: 13"
      end
    end

    test "counts/2 raises Qx.DrawSizeError for 4097 distinct outcomes" do
      error = assert_raise Qx.DrawSizeError, fn -> draw(:counts, 4097) end

      assert error.size == 4097
      assert error.limit == 4096
      assert error.max_qubits == 12
      assert error.message =~ "max_qubits: 13"
    end

    test "the message states the size, the limit and the override" do
      error = assert_raise Qx.DrawSizeError, fn -> draw(:histogram, 1 <<< 13) end

      assert error.message ==
               "Cannot draw 8192 states: the limit is 4096 (max_qubits: 12). " <>
                 "Pass max_qubits: 13 (or higher) to draw it anyway."
    end

    test "the suggested max_qubits is the smallest that admits the input" do
      error = assert_raise Qx.DrawSizeError, fn -> draw(:histogram, (1 <<< 13) + 1) end

      assert error.size == 8193
      assert error.message =~ "max_qubits: 14"
    end

    test "state_table/2 with hide_zeros: true is still capped" do
      assert_raise Qx.DrawSizeError, fn ->
        draw(:state_table, 1 <<< 13, hide_zeros: true)
      end
    end
  end

  describe "boundary and override" do
    for function <- @draw_functions do
      test "#{function}/2 draws exactly 4096 bars/rows with no option" do
        assert_drawn(draw(unquote(function), 1 <<< 12))
      end

      test "#{function}/2 draws 8192 bars/rows with max_qubits: 13" do
        assert_drawn(draw(unquote(function), 1 <<< 13, max_qubits: 13))
      end

      test "#{function}/2 with max_qubits: 2 refuses 8 bars/rows" do
        error =
          assert_raise Qx.DrawSizeError, fn -> draw(unquote(function), 8, max_qubits: 2) end

        assert error.size == 8
        assert error.limit == 4
        assert error.max_qubits == 2
        assert error.message =~ "max_qubits: 3"
      end

      test "#{function}/2 accepts a max_qubits far above any real state" do
        assert_drawn(draw(unquote(function), 4, max_qubits: 1_000_000_000_000))
      end
    end

    test "state_table/2 draws a large state with hide_zeros: true and max_qubits" do
      table = draw(:state_table, 1 <<< 13, hide_zeros: true, max_qubits: 13)

      assert %StateTable{} = table
      refute table.text =~ "⟩"
    end

    test "counts/2 is capped on distinct outcomes, not on bit-string length" do
      twenty_qubit_ghz = %{String.duplicate("0", 20) => 510, String.duplicate("1", 20) => 514}

      assert %VegaLite{} = Draw.counts(result(counts: twenty_qubit_ghz, shots: 1024))
    end
  end

  describe "max_qubits option validation" do
    for function <- @draw_functions, value <- [0, -1, 1.5, :all, "13"] do
      test "#{function}/2 rejects max_qubits: #{inspect(value)} on a small input" do
        value = unquote(value)

        error =
          assert_raise Qx.OptionError, fn -> draw(unquote(function), 4, max_qubits: value) end

        assert error.option == :max_qubits
        assert error.value == value
        assert error.message =~ "Expected a positive integer."
      end
    end
  end

  describe "the guard runs before the host-side build" do
    for function <- @tensor_functions do
      test "#{function}/2 on 2^20 elements raises within a #{1 <<< 17}-word heap" do
        # Built here, outside the limited process, as in the measurements.
        input = input(unquote(function), 1 <<< 20)

        outcome = run_with_heap_limit(fn -> call(unquote(function), input, []) end)

        assert {:raised, error} = outcome
        assert is_exception(error, Qx.DrawSizeError)
        assert error.size == 1_048_576
        assert error.limit == 4096
      end
    end

    test "a call that does build 2^20 elements is killed at that heap limit" do
      probabilities = probabilities(1 <<< 20)

      assert :killed = run_with_heap_limit(fn -> Nx.to_flat_list(probabilities) end)
    end
  end

  describe "Qx facade" do
    for function <- @draw_functions do
      test "Qx facade for #{function}/2 raises Qx.DrawSizeError over the default cap" do
        error = assert_raise Qx.DrawSizeError, fn -> facade(unquote(function), 1 <<< 13) end

        assert error.limit == 4096
        assert error.max_qubits == 12
      end

      test "Qx facade for #{function}/2 accepts max_qubits:" do
        assert_drawn(facade(unquote(function), 1 <<< 13, max_qubits: 13))
      end
    end
  end
end

defmodule Qx.DrawSizeCapRegisterTest do
  # Not async: these tests emit the Register deprecation warning on
  # stderr, and async tests elsewhere assert that their captured stderr
  # is empty.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  describe "deprecated Qx.Register input to state_table/2" do
    test "is capped, after the deprecation warning" do
      register = %Qx.Register{
        num_qubits: 13,
        state: Nx.broadcast(Nx.tensor(0.0, type: :c64), {8192})
      }

      warning =
        capture_io(:stderr, fn ->
          error = assert_raise Qx.DrawSizeError, fn -> Qx.Draw.state_table(register) end

          assert error.size == 8192
        end)

      assert warning =~ "deprecated"
    end

    test "renders with max_qubits:" do
      register = %Qx.Register{
        num_qubits: 13,
        state: Nx.broadcast(Nx.tensor(0.0, type: :c64), {8192})
      }

      capture_io(:stderr, fn ->
        assert %Qx.Draw.StateTable{} = Qx.Draw.state_table(register, max_qubits: 13)
      end)
    end
  end
end
