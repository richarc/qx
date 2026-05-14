# Run a Bell circuit on IBM Quantum hardware.
#
# Requires the following environment variables:
#
#     QX_PORTAL_URL=https://api.qxquantum.com
#     QX_PORTAL_TOKEN=<your qxportal token>
#     QX_IBM_API_KEY=<your IBM Cloud API key>
#     QX_IBM_CRN=<your IBM Quantum service CRN>
#     QX_IBM_REGION=us-east
#     QX_IBM_BACKEND=ibm_brisbane
#
# Optional knobs (override via opts to `Qx.Hardware.Config.from_env!/1`
# or by direct construction of `Qx.Hardware.Config`):
#
#     optimization_level: 0..3 (default 1)
#     shots: 1..100_000 (default 4096)
#
# Usage:
#
#     mix run examples/hardware/run_on_ibm.exs

# Load deps from this project — works whether the script is run with
# `mix run` (inside the qx checkout) or via Mix.install (outside it).
unless Code.ensure_loaded?(Qx.Hardware) do
  Mix.install([{:qx, "~> 0.7"}])
end

config = Qx.Hardware.Config.from_env!()

IO.puts("Submitting Bell-state circuit to backend #{config.backend}...")

circuit =
  Qx.QuantumCircuit.new(2, 2)
  |> Qx.h(0)
  |> Qx.cx(0, 1)
  |> Qx.measure(0, 0)
  |> Qx.measure(1, 1)

case Qx.Hardware.run(circuit, config, on_status: &IO.inspect/1) do
  {:ok, result} ->
    IO.puts("\nCounts:")
    IO.inspect(result.counts)

  {:error, reason} ->
    IO.puts("\nFailed:")
    IO.inspect(reason)
    System.halt(1)
end
