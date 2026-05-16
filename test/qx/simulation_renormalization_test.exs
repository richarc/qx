defmodule Qx.SimulationRenormalizationTest do
  @moduledoc """
  Covers the configurable `:renormalize` option and the compile-time
  norm-drift guard added for qx-53v.

  Numeric note: states are `:c64` (complex float32, ε≈1.2e-7), so the
  guard/tolerance is `1.0e-6`, not the issue's original `1.0e-10`
  (unreachable in float32 even right after `Math.normalize/1`). The
  guard is compiled active in `:test` (config/test.exs), which these
  tests rely on for the P4-T1 relative guarantee.
  """
  use ExUnit.Case, async: true

  alias Qx.{Math, Simulation}

  # Total-probability deviation from 1.0 — the quantity the guard
  # (`Qx.Validation.validate_normalized!/2`) checks. Asserts a rank-1
  # statevector first so a future shape regression can't make the
  # metric silently lenient (S3).
  defp dev(state) do
    assert tuple_size(Nx.shape(state)) == 1,
           "expected a rank-1 statevector, got shape #{inspect(Nx.shape(state))}"

    abs((state |> Math.probabilities() |> Nx.sum() |> Nx.to_number()) - 1.0)
  end

  # Apply `n` repeated H/RX/CX gates to a 3-qubit circuit. Deterministic
  # on BinaryBackend; drifts the norm steadily without renormalization
  # (~6e-7 at 60 gates, ~7e-7 at 80, ~1.07e-6 at 100, ~1.3e-6 at 120).
  # NOTE: `rem(i, 3)` is both the branch selector and the qubit index —
  # this assumes a 3-qubit circuit; do not reuse with other qubit counts.
  defp apply_drift(circuit, n) do
    Enum.reduce(1..n, circuit, fn i, acc ->
      case rem(i, 3) do
        0 -> Qx.h(acc, rem(i, 3))
        1 -> Qx.rx(acc, rem(i, 3), 0.3)
        2 -> Qx.cx(acc, rem(i, 3), rem(i + 1, 3))
      end
    end)
  end

  defp drift_circuit(n), do: apply_drift(Qx.create_circuit(3, 3), n)

  # Conditional circuit: `n` drift gates run via the
  # execute_single_shot/2 *timeline* reduce, THEN a measure + c_if so
  # run/2 takes the shot-by-shot conditional path.
  defp conditional_pre_measure_drift(n) do
    drift_circuit(n)
    |> Qx.measure(0, 0)
    |> Qx.c_if(0, 1, fn c -> Qx.x(c, 1) end)
  end

  # X(0) → measure(0,0) pins classical bit 0 = 1, so the c_if block
  # ALWAYS executes. The `n` drift gates live INSIDE the block, so this
  # exercises norm-guarding + renorm of c_if sub-gates
  # (process_conditional, W1 fix).
  defp conditional_in_block_drift(n) do
    base =
      Qx.create_circuit(3, 3)
      |> Qx.x(0)
      |> Qx.measure(0, 0)

    Qx.c_if(base, 0, 1, fn c -> apply_drift(c, n) end)
  end

  describe "AC #3 (amended): renormalize: N keeps a long circuit normalized" do
    test "100-gate circuit with renormalize: 10 stays within 1.0e-6" do
      result = Simulation.run(drift_circuit(100), renormalize: 10, shots: 1)
      assert dev(result.state) <= 1.0e-6
    end

    test "renormalize: 10 yields strictly lower drift than renormalize: false" do
      # Direct numeric relative guarantee (W3): a 60-gate circuit drifts
      # ~6e-7 without renorm — below @norm_tolerance, so BOTH paths run
      # without the guard firing and both deviations are measurable.
      # This proves renorm *reduces drift* independently of the guard
      # (the 100-gate guard test below is a separate concern).
      circuit = drift_circuit(60)
      off = dev(Simulation.run(circuit, renormalize: false, shots: 1).state)
      renormed = dev(Simulation.run(circuit, renormalize: 10, shots: 1).state)

      # Measured on BinaryBackend (deterministic): off ≈ 5.96e-7,
      # renormed ≈ 1.19e-7 — a ~5× margin, so `renormed < off` is not
      # float32-ULP-fragile.
      assert off <= 1.0e-6
      assert renormed <= 1.0e-6
      assert renormed < off
    end

    test "guard fires when a 100-gate circuit drifts past tolerance without renorm" do
      # Guard-behaviour test (re-scoped, W3): independent of renorm,
      # this asserts the compile-time dev/test guard (active in :test)
      # raises when a circuit's drift exceeds @norm_tolerance — here
      # ~1.07e-6 after 100 un-renormalized gates. Deterministic: no
      # randomness in a measurement-free circuit on BinaryBackend.
      assert_raise Qx.StateNormalizationError, fn ->
        Simulation.run(drift_circuit(100), renormalize: false, shots: 1)
      end
    end
  end

  describe "AC #4 / non-breaking: default renormalize: false is unchanged" do
    test "default equals explicit false; Bell probabilities are the known values" do
      bell = Qx.create_circuit(2, 2) |> Qx.h(0) |> Qx.cx(0, 1)

      default = Simulation.run(bell, shots: 1)
      explicit = Simulation.run(bell, renormalize: false, shots: 1)

      assert Nx.to_flat_list(default.state) == Nx.to_flat_list(explicit.state)

      probs = default.state |> Math.probabilities() |> Nx.to_flat_list()
      assert_in_delta Enum.at(probs, 0), 0.5, 1.0e-6
      assert_in_delta Enum.at(probs, 1), 0.0, 1.0e-6
      assert_in_delta Enum.at(probs, 2), 0.0, 1.0e-6
      assert_in_delta Enum.at(probs, 3), 0.5, 1.0e-6
    end
  end

  describe "AC #1: renormalize: true renorms at measurement-time" do
    test "80-gate circuit with renormalize: true ends within 1.0e-6" do
      result = Simulation.run(drift_circuit(80), renormalize: true, shots: 1)
      assert dev(result.state) <= 1.0e-6
    end
  end

  describe "Iron Law #7: invalid :renormalize raises a typed Qx error" do
    setup do
      {:ok, qc: Qx.create_circuit(1, 1) |> Qx.h(0)}
    end

    test "negative integer", %{qc: qc} do
      assert_raise Qx.OptionError, fn -> Simulation.run(qc, renormalize: -1) end
    end

    test "zero", %{qc: qc} do
      assert_raise Qx.OptionError, fn -> Simulation.run(qc, renormalize: 0) end
    end

    test "float", %{qc: qc} do
      assert_raise Qx.OptionError, fn -> Simulation.run(qc, renormalize: 1.5) end
    end

    test "atom", %{qc: qc} do
      assert_raise Qx.OptionError, fn -> Simulation.run(qc, renormalize: :bad) end
    end
  end

  describe "conditional path (execute_single_shot/2) honours renormalize" do
    test "drift before measure: no-renorm trips guard, renormalize: N does not" do
      # 100 drift gates run via the execute_single_shot/2 timeline
      # reduce BEFORE the measure. Without renorm the guard (active in
      # :test) fires during those gates; with renormalize: 10 it does
      # not (proving renorm works on the conditional timeline path,
      # not just the non-conditional path). result.state would be a
      # post-collapse single-shot state, so this asserts on guard
      # behaviour, not on dev(result.state) (which would be vacuous).
      assert_raise Qx.StateNormalizationError, fn ->
        Simulation.run(conditional_pre_measure_drift(100), renormalize: false, shots: 1)
      end

      result = Simulation.run(conditional_pre_measure_drift(100), renormalize: 10, shots: 1)
      assert %Qx.SimulationResult{} = result
    end

    test "drift inside a c_if block: no-renorm trips guard, renormalize: N does not (W1)" do
      # The drift gates live INSIDE an always-executed c_if block. This
      # proves c_if sub-gates are now norm-guarded AND renormalized per
      # the every-n cadence (process_conditional, W1 fix) — before the
      # fix these sub-gates bypassed both. 120 gates ⇒ ~1.3e-6 drift
      # without renorm (clear of @norm_tolerance = 1.0e-6).
      assert_raise Qx.StateNormalizationError, fn ->
        Simulation.run(conditional_in_block_drift(120), renormalize: false, shots: 1)
      end

      result = Simulation.run(conditional_in_block_drift(120), renormalize: 10, shots: 1)
      assert %Qx.SimulationResult{} = result
    end
  end
end
