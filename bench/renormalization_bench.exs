File.mkdir_p!("bench/output")

# AC #4 evidence: the default (:off) path must not regress vs the
# pre-feature baseline. "baseline (no opt)" and "renormalize: false"
# both take the identical :off code path — they must benchmark within
# noise of each other. The renorm data points show the (opt-in) cost.

short =
  Qx.create_circuit(3, 3)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.rx(2, 0.7)
  |> Qx.h(1)
  |> Qx.cx(1, 2)

long =
  Enum.reduce(1..100, Qx.create_circuit(3, 3), fn i, acc ->
    case rem(i, 3) do
      0 -> Qx.h(acc, rem(i, 3))
      1 -> Qx.rx(acc, rem(i, 3), 0.3)
      2 -> Qx.cx(acc, rem(i, 3), rem(i + 1, 3))
    end
  end)

Benchee.run(
  %{
    "short baseline (no opt)" => fn -> Qx.run(short, shots: 1) end,
    "short renormalize: false" => fn -> Qx.run(short, shots: 1, renormalize: false) end,
    "short renormalize: true" => fn -> Qx.run(short, shots: 1, renormalize: true) end,
    "long(100) renormalize: false" => fn -> Qx.run(long, shots: 1, renormalize: false) end,
    "long(100) renormalize: 10" => fn -> Qx.run(long, shots: 1, renormalize: 10) end
  },
  time: 5,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/output/renormalization.html"}
  ]
)
