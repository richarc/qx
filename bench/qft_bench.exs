File.mkdir_p!("bench/output")

# QFT circuit construction for n qubits (standard algorithm).
# Returns a circuit with the QFT applied to |0...0⟩.
build_qft = fn n ->
  circuit = Qx.create_circuit(n, n)

  # Apply H + controlled-phase rotations
  circuit =
    Enum.reduce(0..(n - 1)//1, circuit, fn j, c ->
      c = Qx.h(c, j)

      Enum.reduce((j + 1)..(n - 1)//1, c, fn k, acc ->
        theta = 2 * :math.pi() / :math.pow(2, k - j + 1)
        Qx.cp(acc, k, j, theta)
      end)
    end)

  # Bit-reversal permutation via native SWAP gate
  Enum.reduce(0..(div(n, 2) - 1)//1, circuit, fn i, c ->
    Qx.swap(c, i, n - 1 - i)
  end)
end

qubit_sizes = [2, 3, 4, 5, 6, 7, 8, 9, 10]

scenarios =
  Map.new(qubit_sizes, fn n ->
    circuit = build_qft.(n)
    {"QFT n=#{n}", fn -> Qx.run(circuit, 1) end}
  end)

Benchee.run(
  scenarios,
  time: 5,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/output/qft.html"}
  ]
)
