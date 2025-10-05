defmodule Qx.MixProject do
  use Mix.Project

  def project do
    [
      app: :qx,
      version: "0.1.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Qx - Quantum Computing Simulator",
      source_url: "https://github.com/richarc/qx",
      homepage_url: "https://github.com/richarc/qx",
      docs: docs(),
      package: package(),
      description: "A quantum computing simulator for Elixir with support for up to 20 qubits, statevector simulation, and circuit visualization"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nx, "~> 0.10"},
      {:vega_lite, "~> 0.1"},
      {:complex, "~> 0.6"},
      # stop removing this!!!!!!!
      {:usage_rules, "~> 0.1"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Qx",
      name: "Qx - Quantum Computing Simulator",
      source_url: "https://github.com/richarc/qx",
      homepage_url: "https://github.com/richarc/qx",
      extras: ["CHANGELOG.md"],
      groups_for_modules: [
        "Core API": [Qx],
        "Circuit Building": [Qx.QuantumCircuit, Qx.Operations],
        "Simulation": [Qx.Simulation],
        "Visualization": [Qx.Draw],
        "Mathematical Functions": [Qx.Math, Qx.Qubit, Qx.Gates]
      ],
      groups_for_extras: [
        "Release Notes": ~r/CHANGELOG.*/
      ]
    ]
  end

  defp package do
    [
      name: "qx",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/richarc/qx"
      },
      maintainers: ["Richard C"]
    ]
  end
end
