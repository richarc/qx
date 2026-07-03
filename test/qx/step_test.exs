defmodule Qx.StepTest do
  use ExUnit.Case, async: true

  alias Qx.Step

  # :c64 states are complex float32 (eps ~1.2e-7); 1.0e-6 per Iron Law #8.
  @tolerance 1.0e-6

  # Bell-state step built by hand: Phase 1 tests the struct and display
  # only, the engine stream that produces steps arrives in Phase 2.
  defp bell_step do
    qc = Qx.create_circuit(2) |> Qx.h(0) |> Qx.cx(0, 1)
    state = Qx.Simulation.get_state(qc)

    %Step{
      kind: :gate,
      operation: {:cx, [0, 1], []},
      index: 1,
      state: state,
      probabilities: Qx.Math.probabilities(state)
    }
  end

  describe "struct" do
    test "has the documented fields with nil defaults and empty classical_bits" do
      step = %Step{}

      assert step.kind == nil
      assert step.operation == nil
      assert step.index == nil
      assert step.state == nil
      assert step.probabilities == nil
      assert step.classical_bits == []
      assert step.condition == nil
    end
  end

  describe "show/1" do
    test "returns the show_state display map for a Bell state" do
      info = Step.show(bell_step())

      assert %{state: state_str, amplitudes: amplitudes, probabilities: probabilities} = info
      assert map_size(info) == 3

      assert state_str == "0.707|00⟩ + 0.707|11⟩"

      assert Enum.map(amplitudes, fn {basis, _} -> basis end) ==
               ["|00⟩", "|01⟩", "|10⟩", "|11⟩"]

      assert Enum.all?(amplitudes, fn {_basis, amp} -> is_binary(amp) end)

      expected = [{"|00⟩", 0.5}, {"|01⟩", 0.0}, {"|10⟩", 0.0}, {"|11⟩", 0.5}]

      for {{basis, prob}, {exp_basis, exp_prob}} <- Enum.zip(probabilities, expected) do
        assert basis == exp_basis
        assert_in_delta prob, exp_prob, @tolerance
      end
    end

    test "matches Qx.Register.show_state/1's shape and values" do
      reg = Qx.Register.new(2) |> Qx.Register.h(0) |> Qx.Register.cx(0, 1)
      reg_info = Qx.Register.show_state(reg)
      step_info = Step.show(bell_step())

      assert Map.keys(step_info) == Map.keys(reg_info)
      assert step_info.state == reg_info.state

      assert Enum.map(step_info.amplitudes, &elem(&1, 0)) ==
               Enum.map(reg_info.amplitudes, &elem(&1, 0))

      for {{basis, prob}, {reg_basis, reg_prob}} <-
            Enum.zip(step_info.probabilities, reg_info.probabilities) do
        assert basis == reg_basis
        assert_in_delta prob, reg_prob, @tolerance
      end
    end
  end

  describe "Inspect" do
    test "gate step renders index, operation, and Dirac string" do
      rendered = inspect(bell_step())

      assert rendered =~ "#Qx.Step<1: cx(0, 1)"
      assert rendered =~ "0.707|00⟩ + 0.707|11⟩"
      refute rendered =~ "cbits:"
      assert String.ends_with?(rendered, ">")
    end

    test "renders cbits when classical_bits is non-empty" do
      step = %{bell_step() | classical_bits: [1, 0]}

      assert inspect(step) =~ "cbits: [1, 0]"
    end

    test "measurement step renders a measurement arrow" do
      qc = Qx.create_circuit(2) |> Qx.x(0)
      state = Qx.Simulation.get_state(qc)

      step = %Step{
        kind: :measurement,
        operation: {:measure, [0, 0], []},
        index: 1,
        state: state,
        probabilities: Qx.Math.probabilities(state),
        classical_bits: [1, 0]
      }

      rendered = inspect(step)

      assert rendered =~ "measure q0 → c0"
      assert rendered =~ "⇒"
      assert rendered =~ "cbits: [1, 0]"
    end

    test "conditional step renders the condition and taken flag" do
      qc = Qx.create_circuit(3) |> Qx.x(2)
      state = Qx.Simulation.get_state(qc)

      step = %Step{
        kind: :conditional,
        operation: {:x, [2], []},
        index: 4,
        state: state,
        probabilities: Qx.Math.probabilities(state),
        classical_bits: [1, 1, 0],
        condition: {1, 1, :taken}
      }

      rendered = inspect(step)

      assert rendered =~ "c_if(c1==1)"
      assert rendered =~ "x(2)"
      assert rendered =~ "taken"
    end

    test "not-taken conditional step renders not_taken" do
      step = %Step{
        kind: :conditional,
        operation: nil,
        index: 3,
        state: Qx.Simulation.get_state(Qx.create_circuit(1)),
        probabilities: Nx.tensor([1.0, 0.0]),
        classical_bits: [0],
        condition: {0, 1, :not_taken}
      }

      assert inspect(step) =~ "not_taken"
    end

    test "truncates the Dirac string past four non-zero terms" do
      qc = Qx.create_circuit(3) |> Qx.h_all()
      state = Qx.Simulation.get_state(qc)

      step = %Step{
        kind: :gate,
        operation: {:h, [2], []},
        index: 2,
        state: state,
        probabilities: Qx.Math.probabilities(state)
      }

      rendered = inspect(step)

      # 8 equal-weight terms must not all appear; 4 terms + ellipsis do.
      assert rendered =~ "…"
      assert rendered =~ "|000⟩"
      assert rendered =~ "|011⟩"
      refute rendered =~ "|100⟩"
    end
  end

  describe "Inspect fallback below the probability threshold" do
    test "renders the largest terms instead of a misleading 0.000 term" do
      # All probabilities sit below the 1.0e-6 display threshold (the
      # n=20 uniform-superposition regime, miniaturised): the fallback
      # must show the top terms, not "0.000|00>".
      # 9.0e-4 amplitude: probability 8.1e-7 stays under the 1.0e-6
      # display threshold, while the amplitude still renders non-zero
      # ("0.001") at 3-decimal precision.
      tiny = Complex.new(9.0e-4, 0.0)
      state = Nx.tensor([tiny, tiny, tiny, tiny], type: :c64)

      step = %Step{
        kind: :gate,
        operation: {:h, [1], []},
        index: 0,
        state: state,
        probabilities: Qx.Math.probabilities(state)
      }

      rendered = inspect(step)

      refute rendered =~ "0.000|00"
      assert rendered =~ "0.001|00⟩"
      assert rendered =~ "|00⟩"
      assert rendered =~ "|11⟩"
    end
  end

  describe "show/1 on measurement steps" do
    test "shows the collapsed state of the sampled trajectory" do
      qc = Qx.create_circuit(2) |> Qx.x(0)
      state = Qx.Simulation.get_state(qc)

      step = %Step{
        kind: :measurement,
        operation: {:measure, [0, 0], []},
        index: 1,
        state: state,
        probabilities: Qx.Math.probabilities(state),
        classical_bits: [1, 0]
      }

      assert Step.show(step).state == "1.000|10⟩"
    end
  end
end
