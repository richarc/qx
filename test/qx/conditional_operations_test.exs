defmodule Qx.ConditionalOperationsTest do
  use ExUnit.Case, async: true

  # Pins the observable semantics of `Qx.c_if/4` for two cases not covered
  # by the single-`c_if` and structural tests in `qx_test.exs` /
  # `operations_typed_errors_test.exs`:
  #
  #   * CHAINED conditionals — several `c_if` blocks in one circuit,
  #     executed shot-by-shot through `run_with_conditionals/3`. Tests use
  #     deterministic circuits and assert exact `result.counts`.
  #   * NESTED conditionals — a `c_if` inside a `c_if` block. Nesting is
  #     unsupported by design: `validate_conditional_block/1` rejects it at
  #     construction time with `Qx.ConditionalError`. These are rejection /
  #     characterization tests; if a later refactor adds nested execution
  #     they SHOULD break and force a review.
  #
  # Counts keys are the classical-bit register as a list [c0, c1, ...];
  # unmeasured bits stay 0. A regression net for the v0.8.2 simulation work.

  describe "chained conditionals — execution semantics" do
    test "two c_if on the SAME classical bit both fire" do
      # c0 = 1, so both blocks fire: X on q1 applied twice → q1 back to |0⟩.
      qc =
        Qx.create_circuit(2, 2)
        |> Qx.x(0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
        |> Qx.measure(1, 1)

      assert Qx.run(qc, 100).counts == %{"10" => 100}
    end

    test "mixed chain: one block fires, the next is skipped (deterministic)" do
      # c0 = 1 (fires X q2), c1 = 0 (skips) → q2 ends |1⟩.
      qc =
        Qx.create_circuit(3, 3)
        |> Qx.x(0)
        |> Qx.measure(0, 0)
        |> Qx.measure(1, 1)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 2) end)
        |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
        |> Qx.measure(2, 2)

      assert Qx.run(qc, 100).counts == %{"101" => 100}
    end

    test "mixed chain in the other order: skip then fire (deterministic)" do
      # c0 = 0 (skips), c1 = 1 (fires X q2) → q2 ends |1⟩. Exercises the
      # no-op branch of process_conditional as the FIRST reducer step.
      qc =
        Qx.create_circuit(3, 3)
        |> Qx.x(1)
        |> Qx.measure(0, 0)
        |> Qx.measure(1, 1)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 2) end)
        |> Qx.c_if(1, 1, fn c -> Qx.x(c, 2) end)
        |> Qx.measure(2, 2)

      assert Qx.run(qc, 100).counts == %{"011" => 100}
    end

    test "chain of three conditionals on independent targets (fire/skip/fire)" do
      # c0 = 1, c1 = 0, c2 = 1; each block flips a distinct qubit.
      qc =
        Qx.create_circuit(6, 6)
        |> Qx.x(0)
        |> Qx.x(2)
        |> Qx.measure(0, 0)
        |> Qx.measure(1, 1)
        |> Qx.measure(2, 2)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 3) end)
        |> Qx.c_if(1, 1, fn c -> Qx.x(c, 4) end)
        |> Qx.c_if(2, 1, fn c -> Qx.x(c, 5) end)
        |> Qx.measure(3, 3)
        |> Qx.measure(4, 4)
        |> Qx.measure(5, 5)

      assert Qx.run(qc, 100).counts == %{"101101" => 100}
    end

    test "a multi-gate conditional block runs every gate when it fires" do
      # The block applies TWO gates; [1, 1, 1] proves both ran (one gate
      # alone would leave [1, 1, 0] or [1, 0, 1]).
      qc =
        Qx.create_circuit(3, 3)
        |> Qx.x(0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> c |> Qx.x(1) |> Qx.x(2) end)
        |> Qx.measure(1, 1)
        |> Qx.measure(2, 2)

      assert Qx.run(qc, 100).counts == %{"111" => 100}
    end

    test "probabilistic chain: both blocks track the same measured bit" do
      # c0 is 50/50; both conditionals key on c0, so outcomes are perfectly
      # correlated: either both fire ([1,1,1]) or both skip ([0,0,0]).
      qc =
        Qx.create_circuit(3, 3)
        |> Qx.h(0)
        |> Qx.measure(0, 0)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
        |> Qx.c_if(0, 1, fn c -> Qx.x(c, 2) end)
        |> Qx.measure(1, 1)
        |> Qx.measure(2, 2)

      shots = 1000
      counts = Qx.run(qc, shots).counts
      count_000 = Map.get(counts, "000", 0)
      count_111 = Map.get(counts, "111", 0)

      # The c_if-specific property: every shot lands in one of the two
      # correlated buckets — no partial outcome where only one block fired.
      assert count_000 + count_111 == shots
      # Both branches of the chain are actually exercised (fires and skips).
      # At 1000 shots an empty bucket has probability 0.5^1000 ≈ 0 — not flaky.
      assert count_000 > 0
      assert count_111 > 0
    end
  end

  describe "nested conditionals — rejected at construction (Qx.ConditionalError)" do
    setup do
      %{qc: Qx.create_circuit(3, 3)}
    end

    test "a bare c_if inside a c_if block raises at build time (no run needed)", %{qc: qc} do
      assert_raise Qx.ConditionalError, ~r/Nested conditional operations/, fn ->
        Qx.c_if(qc, 0, 1, fn c ->
          Qx.c_if(c, 1, 1, fn inner -> Qx.x(inner, 2) end)
        end)
      end
    end

    test "nesting is rejected even when the inner c_if is not the first gate", %{qc: qc} do
      assert_raise Qx.ConditionalError, ~r/Nested conditional operations/, fn ->
        Qx.c_if(qc, 0, 1, fn c ->
          c
          |> Qx.x(1)
          |> Qx.c_if(1, 1, fn inner -> Qx.x(inner, 2) end)
        end)
      end
    end

    test "triple nesting is rejected at the outermost c_if call", %{qc: qc} do
      assert_raise Qx.ConditionalError, ~r/Nested conditional operations/, fn ->
        Qx.c_if(qc, 0, 1, fn c ->
          Qx.c_if(c, 1, 1, fn mid ->
            Qx.c_if(mid, 2, 1, fn inner -> Qx.x(inner, 2) end)
          end)
        end)
      end
    end
  end
end
