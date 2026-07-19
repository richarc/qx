defmodule Qx.MixProject do
  use Mix.Project

  def project do
    [
      app: :qx,
      version: "0.11.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.github": :test,
        "coveralls.cobertura": :test
      ],
      name: "Qx - Quantum Computing Simulator",
      source_url: "https://github.com/richarc/qx",
      homepage_url: "https://github.com/richarc/qx",
      docs: docs(),
      package: package(),
      dialyzer: dialyzer(),
      description:
        "A quantum computing library for Elixir with statevector simulation, circuit visualization, and direct execution on IBM Quantum hardware",
      usage_rules: usage_rules()
    ]
  end

  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: [:usage_rules]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nx, "~> 0.12"},
      # Acceleration backends (EXLA / EMLX) are NOT deps of Qx — users add them
      # to their own project and set `config :nx, :default_backend`. See the
      # "Performance & Acceleration" section of README.md.
      # Optional: needed only for the VegaLite-returning chart functions
      # (Qx.draw/draw_counts/draw_histogram); they raise a typed
      # Qx.MissingDependencyError when it's absent.
      {:vega_lite, "~> 0.1", optional: true},
      # Optional: enables rich Livebook rendering via Kino.Render impls
      # for Qx structs. Qx never calls Kino APIs outside those impls.
      {:kino, "~> 0.12", optional: true},
      {:complex, "~> 0.7"},
      {:nimble_parsec, "~> 1.4"},
      {:req, "~> 0.6"},
      {:jason, "~> 1.4"},
      {:usage_rules, "~> 1.2", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:plug, "~> 1.0", only: :test},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_core_path: "priv/plts",
      plt_local_path: "priv/plts"
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
      # Old changelog entries name modules that were later hidden
      # (e.g. the calc engine); history stays as written.
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      groups_for_modules: [
        "Core API": [Qx],
        "Circuit Building": [Qx.QuantumCircuit, Qx.Operations],
        "Composite Patterns": [Qx.Patterns],
        "Simulation & Results": [
          Qx.Simulation,
          Qx.SimulationResult,
          Qx.Step
        ],
        Visualization: [Qx.Draw, Qx.Draw.Image, Qx.Draw.StateTable],
        "Hardware Execution": [
          Qx.Hardware,
          Qx.Hardware.Config,
          Qx.Hardware.Ibm,
          Qx.Hardware.Portal
        ],
        "Error Handling": [
          Qx.Error,
          Qx.OptionError,
          Qx.QubitIndexError,
          Qx.StateNormalizationError,
          Qx.StateShapeError,
          Qx.MeasurementError,
          Qx.ConditionalError,
          Qx.ClassicalBitError,
          Qx.GateError,
          Qx.QubitCountError,
          Qx.Hardware.NoMeasurementsError,
          Qx.Hardware.ConfigError,
          Qx.QasmParseError,
          Qx.QasmUnsupportedError,
          Qx.MissingDependencyError
        ],
        Utilities: [
          Qx.Math,
          Qx.StateInit
        ]
      ],
      groups_for_extras: [
        Documentation: ~r/README.*/,
        "Release Notes": ~r/CHANGELOG.*/
      ]
    ]
  end

  defp aliases do
    [
      bench: [
        "run --no-halt bench/ghz_bench.exs",
        "run --no-halt bench/qft_bench.exs",
        "run --no-halt bench/renormalization_bench.exs"
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
