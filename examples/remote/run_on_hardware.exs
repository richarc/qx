# Run a Bell state circuit on quantum hardware via QxServer
#
# Prerequisites:
#   1. Start qx_server: cd ../qx_server && mix run --no-halt
#   2. Configure IBM credentials on the server via environment variables
#   3. Optionally set QX_SERVER_API_KEY for auth
#
# Usage:
#   mix run examples/remote/run_on_hardware.exs

config = Qx.Remote.Config.new!(
  url: System.get_env("QX_SERVER_URL", "http://localhost:4040"),
  api_key: System.get_env("QX_SERVER_API_KEY")
)

# Build a Bell state circuit
circuit =
  Qx.create_circuit(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

IO.puts("Submitting Bell state circuit...")

{:ok, result} =
  Qx.Remote.run(circuit, config,
    backend: "ibm_fez",
    shots: 4096,
    on_status: fn status ->
      IO.puts("  Status: #{status["status"]}")
    end
  )

IO.puts("\nResults:")
IO.puts("  Shots: #{result.shots}")
IO.puts("  Counts: #{inspect(result.counts)}")
IO.puts("  Most frequent: #{inspect(Qx.SimulationResult.most_frequent(result))}")
