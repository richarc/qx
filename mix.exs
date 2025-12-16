defmodule Qx.MixProject do
  use Mix.Project

  def project do
    [
      app: :qx,
      version: "0.2.5",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Qx - Quantum Computing Simulator",
      source_url: "https://github.com/richarc/qx",
      homepage_url: "https://github.com/richarc/qx",
      docs: docs(),
      package: package(),
      description:
        "A quantum computing simulator for Elixir with support for up to 20 qubits, statevector simulation, and circuit visualization"
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
      # {:exla, "~> 0.10", optional: true},
      # {:emlx, "~> 0.2", optional: true},
      {:vega_lite, "~> 0.1"},
      {:complex, "~> 0.6"},
      {:usage_rules, "~> 0.1"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Qx",
      name: "Qx - Quantum Computing Simulator",
      source_url: "https://github.com/richarc/qx",
      homepage_url: "https://github.com/richarc/qx",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: [
        "Core API": [Qx],
        "Circuit Building": [Qx.QuantumCircuit, Qx.Operations],
        "Calculation Mode": [Qx.Qubit, Qx.Register],
        "Simulation & Results": [
          Qx.Simulation,
          Qx.SimulationResult
        ],
        Visualization: [Qx.Draw],
        "Error Handling": [
          Qx.Error,
          Qx.QubitIndexError,
          Qx.StateNormalizationError,
          Qx.MeasurementError,
          Qx.ConditionalError,
          Qx.ClassicalBitError,
          Qx.GateError,
          Qx.QubitCountError
        ],
        "Validation & Utilities": [
          Qx.Validation,
          Qx.Math,
          Qx.Format,
          Qx.StateInit
        ],
        "Low-Level Operations": [
          Qx.Calc,
          Qx.Gates
        ],
        Behaviours: [
          Qx.Behaviours.QuantumState
        ]
      ],
      groups_for_extras: [
        Documentation: ~r/README.*/,
        "Release Notes": ~r/CHANGELOG.*/
      ]
    ]
  end

  defp package do
    [
      name: "qx_sim",
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE",
        "CHANGELOG.md"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/richarc/qx",
        "Changelog" => "https://github.com/richarc/qx/blob/main/CHANGELOG.md"
      },
      maintainers: ["Craig Richards"]
    ]
  end
end
