File.mkdir_p!("bench/output")

qubit_sizes = [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]

scenarios =
  Map.new(qubit_sizes, fn n ->
    circuit =
      Qx.create_circuit(n, n)
      |> Qx.h(0)
      |> then(fn c -> Enum.reduce(1..(n - 1), c, fn i, acc -> Qx.cx(acc, i - 1, i) end) end)

    {"GHZ n=#{n}", fn -> Qx.run(circuit, 1) end}
  end)

Benchee.run(
  scenarios,
  time: 5,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/output/ghz.html"}
  ]
)
