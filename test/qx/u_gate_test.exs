defmodule Qx.UGateTest do
  use ExUnit.Case

  alias Qx.Export.OpenQASM

  describe "u gate instruction" do
    test "adds {:u, [qubit], [theta, phi, lambda]} to circuit instructions" do
      qc = Qx.create_circuit(1) |> Qx.u(0, :math.pi(), 0, :math.pi())

      assert [{:u, [0], [theta, phi, lambda]}] = Qx.QuantumCircuit.get_instructions(qc)
      assert_in_delta theta, :math.pi(), 1.0e-10
      assert_in_delta phi, 0.0, 1.0e-10
      assert_in_delta lambda, :math.pi(), 1.0e-10
    end

    test "preserves qubit index and parameters" do
      qc = Qx.create_circuit(3) |> Qx.u(2, 0.5, 1.0, 1.5)

      assert [{:u, [2], [0.5, 1.0, 1.5]}] = Qx.QuantumCircuit.get_instructions(qc)
    end
  end

  describe "u gate statevector behaviour" do
    test "U(pi, 0, pi) acts as X gate on |0⟩ → |1⟩" do
      state = Qx.create_circuit(1) |> Qx.u(0, :math.pi(), 0, :math.pi()) |> Qx.get_state()

      assert_in_delta Complex.real(Nx.to_number(state[0])), 0.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[1])), 1.0, 1.0e-5
    end

    test "U(0, 0, 0) acts as identity on |0⟩ → |0⟩" do
      state = Qx.create_circuit(1) |> Qx.u(0, 0, 0, 0) |> Qx.get_state()

      assert_in_delta Complex.real(Nx.to_number(state[0])), 1.0, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[1])), 0.0, 1.0e-5
    end

    test "U(pi/2, 0, pi) acts as Hadamard: |0⟩ → (|0⟩ + |1⟩)/√2" do
      state = Qx.create_circuit(1) |> Qx.u(0, :math.pi() / 2, 0, :math.pi()) |> Qx.get_state()

      inv_sqrt2 = 1.0 / :math.sqrt(2)
      assert_in_delta Complex.real(Nx.to_number(state[0])), inv_sqrt2, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[1])), inv_sqrt2, 1.0e-5
    end

    test "U(pi/2, 0, 0): |0⟩ → (|0⟩ + |1⟩)/√2 (RY rotation)" do
      state = Qx.create_circuit(1) |> Qx.u(0, :math.pi() / 2, 0, 0) |> Qx.get_state()

      inv_sqrt2 = 1.0 / :math.sqrt(2)
      assert_in_delta Complex.real(Nx.to_number(state[0])), inv_sqrt2, 1.0e-5
      assert_in_delta Complex.real(Nx.to_number(state[1])), inv_sqrt2, 1.0e-5
    end

    test "U(pi, pi/2, pi/2) acts as Y gate (up to global phase) on |0⟩ → i|1⟩" do
      state =
        Qx.create_circuit(1)
        |> Qx.u(0, :math.pi(), :math.pi() / 2, :math.pi() / 2)
        |> Qx.get_state()

      amp1 = Nx.to_number(state[1])
      assert_in_delta Complex.real(Nx.to_number(state[0])), 0.0, 1.0e-5
      # |amplitude| = 1
      mag = :math.sqrt(Complex.real(amp1) ** 2 + Complex.imag(amp1) ** 2)
      assert_in_delta mag, 1.0, 1.0e-5
    end
  end

  describe "u gate error handling" do
    test "raises ArgumentError for non-numeric theta" do
      qc = Qx.create_circuit(1)
      assert_raise ArgumentError, fn -> Qx.u(qc, 0, "bad", 0, 0) end
    end

    test "raises ArgumentError for non-numeric phi" do
      qc = Qx.create_circuit(1)
      assert_raise ArgumentError, fn -> Qx.u(qc, 0, 0, "bad", 0) end
    end

    test "raises ArgumentError for non-numeric lambda" do
      qc = Qx.create_circuit(1)
      assert_raise ArgumentError, fn -> Qx.u(qc, 0, 0, 0, "bad") end
    end

    test "raises FunctionClauseError for out-of-range qubit index" do
      qc = Qx.create_circuit(1)
      assert_raise FunctionClauseError, fn -> Qx.u(qc, 5, 0, 0, 0) end
    end
  end

  describe "u gate OpenQASM export" do
    test "exports u gate as u(theta, phi, lambda) q[qubit];" do
      circuit = Qx.create_circuit(1) |> Qx.u(0, :math.pi(), 0.0, :math.pi())
      qasm = OpenQASM.to_qasm(circuit)

      assert qasm =~ "u("
      assert qasm =~ "q[0];"
    end
  end
end
