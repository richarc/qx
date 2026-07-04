# Kino.Render implementations for the taught structs, compiled only
# when the optional :kino dependency is present. This is the sanctioned
# pattern from spec/api-design-principles.md §6: rich Livebook display
# comes from protocol impls, never from functions changing behaviour.
if Code.ensure_loaded?(Kino.Render) do
  defimpl Kino.Render, for: Qx.QuantumCircuit do
    def to_livebook(circuit) do
      %Qx.Draw.Image{svg: svg} = Qx.Draw.circuit(circuit)
      svg |> Kino.Image.new(:svg) |> Kino.Render.to_livebook()
    end
  end

  defimpl Kino.Render, for: Qx.SimulationResult do
    def to_livebook(result) do
      header = "**#{result.shots} shots**\n\n| Outcome | Count |\n|---|---|\n"

      rows =
        result.counts
        |> Enum.sort_by(fn {_outcome, count} -> -count end)
        |> Enum.map_join("\n", fn {outcome, count} -> "| #{outcome} | #{count} |" end)

      body = if result.counts == %{}, do: "_no measurements_", else: header <> rows

      body |> Kino.Markdown.new() |> Kino.Render.to_livebook()
    end
  end

  defimpl Kino.Render, for: Qx.Step do
    def to_livebook(step) do
      %{state: dirac, amplitudes: amps, probabilities: probs} = Qx.Step.show(step)

      rows =
        amps
        |> Enum.zip(probs)
        |> Enum.map_join("\n", fn {{basis, amp}, {_basis, prob}} ->
          "| #{String.replace(basis, "|", "\\|")} | #{amp} | #{Float.round(prob, 4)} |"
        end)

      markdown =
        "**#{dirac}**\n\n| Basis | Amplitude | Probability |\n|---|---|---|\n" <> rows

      markdown |> Kino.Markdown.new() |> Kino.Render.to_livebook()
    end
  end
end
