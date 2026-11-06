defmodule Qx.SimulationSlicingKernelsTest do
  use ExUnit.Case, async: true

  # Execution-level coverage (Iron Law #9) for routing CP / CY / CRx / CRy /
  # CRz / CZ / SWAP / iSWAP through the `Qx.CalcFast` slicing kernels instead
  # of materialised 2^n × 2^n matrices (plan: calcfast-reshape-kernels).
  #
  # The expected states are computed here from the legacy `Qx.Gates` n-qubit
  # matrix builders — exactly the values `Qx.Simulation` produced before the
  # change — so these tests pin "same results, new kernels" for `get_state/1`
  # and for the `steps/2` stream.

  alias Qx.Gates

  @tolerance 1.0e-6

  # Single-qubit gate embedded on qubit q of n (MSB), via Kronecker products.
  defp embed_1q(gate, q, n) do
    eye = Nx.eye(2, type: :c64)

    0..(n - 1)
    |> Enum.map(fn i -> if i == q, do: gate, else: eye end)
    |> Enum.reduce(fn m, acc -> kron(acc, m) end)
  end

  defp kron(a, b) do
    {ra, ca} = Nx.shape(a)
    {rb, cb} = Nx.shape(b)

    Nx.outer(a, b)
    |> Nx.reshape({ra, ca, rb, cb})
    |> Nx.transpose(axes: [0, 2, 1, 3])
    |> Nx.reshape({ra * rb, ca * cb})
  end

  # CCX on (c1, c2, t) of n: permutation of the basis, MSB convention.
  defp ccx_matrix(c1, c2, t, n) do
    dim = Integer.pow(2, n)
    bit = fn i, q -> Bitwise.band(Bitwise.bsr(i, n - 1 - q), 1) end

    perm =
      for i <- 0..(dim - 1) do
        if bit.(i, c1) == 1 and bit.(i, c2) == 1,
          do: Bitwise.bxor(i, Bitwise.bsl(1, n - 1 - t)),
          else: i
      end

    Nx.eye(dim, type: :c64) |> Nx.take(Nx.tensor(perm))
  end

  # Oracle matrix for one circuit instruction.
  defp oracle_matrix({:h, [q], []}, n), do: embed_1q(Gates.hadamard(), q, n)
  defp oracle_matrix({:ry, [q], [th]}, n), do: embed_1q(Gates.ry(th), q, n)
  defp oracle_matrix({:cx, [c, t], []}, n), do: Gates.controlled_gate(Gates.pauli_x(), c, t, n)
  defp oracle_matrix({:cz, [c, t], []}, n), do: Gates.controlled_gate(Gates.pauli_z(), c, t, n)
  defp oracle_matrix({:cy, [c, t], []}, n), do: Gates.controlled_gate(Gates.pauli_y(), c, t, n)

  defp oracle_matrix({:cp, [c, t], [th]}, n),
    do: Gates.controlled_gate(Gates.phase(th), c, t, n)

  defp oracle_matrix({:crx, [c, t], [th]}, n), do: Gates.controlled_gate(Gates.rx(th), c, t, n)
  defp oracle_matrix({:cry, [c, t], [th]}, n), do: Gates.controlled_gate(Gates.ry(th), c, t, n)
  defp oracle_matrix({:crz, [c, t], [th]}, n), do: Gates.controlled_gate(Gates.rz(th), c, t, n)
  defp oracle_matrix({:swap, [a, b], []}, n), do: Gates.swap(a, b, n)
  defp oracle_matrix({:iswap, [a, b], []}, n), do: Gates.iswap(a, b, n)
  defp oracle_matrix({:cswap, [c, a, b], []}, n), do: Gates.cswap(c, a, b, n)
  defp oracle_matrix({:ccx, [c1, c2, t], []}, n), do: ccx_matrix(c1, c2, t, n)

  defp oracle_state(instructions, n) do
    initial =
      Nx.concatenate([
        Nx.tensor([1.0], type: :c64),
        Nx.broadcast(Nx.tensor(0.0, type: :c64), {Integer.pow(2, n) - 1})
      ])

    Enum.reduce(instructions, initial, fn inst, state ->
      Nx.dot(oracle_matrix(inst, n), state)
    end)
  end

  defp build_circuit(instructions, n) do
    Enum.reduce(instructions, Qx.create_circuit(n), fn
      {:h, [q], []}, c -> Qx.h(c, q)
      {:ry, [q], [th]}, c -> Qx.ry(c, q, th)
      {:cx, [a, b], []}, c -> Qx.cx(c, a, b)
      {:cz, [a, b], []}, c -> Qx.cz(c, a, b)
      {:cy, [a, b], []}, c -> Qx.cy(c, a, b)
      {:cp, [a, b], [th]}, c -> Qx.cp(c, a, b, th)
      {:crx, [a, b], [th]}, c -> Qx.crx(c, a, b, th)
      {:cry, [a, b], [th]}, c -> Qx.cry(c, a, b, th)
      {:crz, [a, b], [th]}, c -> Qx.crz(c, a, b, th)
      {:swap, [a, b], []}, c -> Qx.swap(c, a, b)
      {:iswap, [a, b], []}, c -> Qx.iswap(c, a, b)
      {:cswap, [x, a, b], []}, c -> Qx.cswap(c, x, a, b)
      {:ccx, [a, b, t], []}, c -> Qx.ccx(c, a, b, t)
    end)
  end

  defp qft_instructions(n) do
    rotations =
      for j <- 0..(n - 1), inst <- [{:h, [j], []} | cp_chain(j, n)], do: inst

    swaps = for i <- 0..(div(n, 2) - 1)//1, do: {:swap, [i, n - 1 - i], []}
    rotations ++ swaps
  end

  defp cp_chain(j, n) do
    for k <- (j + 1)..(n - 1)//1 do
      {:cp, [k, j], [2 * :math.pi() / :math.pow(2, k - j + 1)]}
    end
  end

  # Every gate kind routed through the new kernels, mixed orderings,
  # non-adjacent qubits, on a non-trivial superposition.
  @mixed [
    {:h, [0], []},
    {:h, [1], []},
    {:h, [2], []},
    {:h, [3], []},
    {:ry, [1], [0.4]},
    {:cry, [0, 2], [0.9]},
    {:cswap, [1, 0, 3], []},
    {:iswap, [2, 3], []},
    {:cz, [3, 1], []},
    {:crz, [2, 0], [0.5]},
    {:crx, [1, 3], [1.2]},
    {:cy, [3, 0], []},
    {:cp, [0, 3], [0.3]},
    {:ccx, [3, 1, 2], []},
    {:iswap, [3, 0], []},
    {:swap, [1, 2], []},
    {:cx, [2, 0], []}
  ]

  defp assert_state_close(actual, expected) do
    max_err = actual |> Nx.subtract(expected) |> Nx.abs() |> Nx.reduce_max() |> Nx.to_number()
    assert max_err < @tolerance, "max |Δ| = #{max_err} ≥ #{@tolerance}"
  end

  describe "Qx.get_state/1 matches the pre-change matrix path" do
    test "QFT n = 4 (CP + SWAP)" do
      insts = qft_instructions(4)
      assert_state_close(Qx.get_state(build_circuit(insts, 4)), oracle_state(insts, 4))
    end

    test "QFT n = 5 on a non-trivial input (odd n, unswapped middle qubit)" do
      prep = [{:h, [0], []}, {:ry, [2], [0.7]}, {:cx, [0, 4], []}]
      insts = prep ++ qft_instructions(5)
      assert_state_close(Qx.get_state(build_circuit(insts, 5)), oracle_state(insts, 5))
    end

    test "mixed CRY / CSWAP / iSWAP / CZ / CRZ / CRX / CY / CP / CCX / SWAP circuit" do
      assert_state_close(Qx.get_state(build_circuit(@mixed, 4)), oracle_state(@mixed, 4))
    end
  end

  describe "Qx.steps/2 executes the same kernels" do
    test "every step's state matches the oracle prefix (mixed circuit)" do
      steps = @mixed |> build_circuit(4) |> Qx.steps() |> Enum.to_list()

      assert length(steps) == length(@mixed)

      steps
      |> Enum.with_index(1)
      |> Enum.each(fn {step, k} ->
        assert_state_close(step.state, oracle_state(Enum.take(@mixed, k), 4))
      end)
    end
  end

  describe "static guards (Iron Law #3 / matrix materialisation)" do
    defp code_lines(relative) do
      __DIR__
      |> Path.join("../../" <> relative)
      |> File.read!()
      |> String.split("\n")
      |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
      |> Enum.join("\n")
    end

    test "Qx.CalcFast uses no gather (Nx.take) or mask (Nx.select) kernels" do
      src = code_lines("lib/qx/calc_fast.ex")
      refute src =~ "Nx.take"
      refute src =~ "Nx.select"
    end

    test "Qx.Simulation builds no 2^n × 2^n gate matrices" do
      src = code_lines("lib/qx/simulation.ex")
      refute src =~ ~r/Gates\.(swap|iswap|cswap|cnot|toffoli|controlled_gate)\(/
    end
  end
end
