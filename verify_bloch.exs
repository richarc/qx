# Script to verify Bloch sphere generation
Nx.default_backend(Nx.BinaryBackend)
alias Qx.Qubit

# Ensure output directory exists
File.mkdir_p!("output/bloch")

# Define test cases
cases = [
  {"zero", Qubit.new()},
  {"one", Qubit.one()},
  {"plus", Qubit.plus()},
  {"minus", Qubit.minus()},
  {"i_state", Qubit.from_bloch(:math.pi() / 2, :math.pi() / 2)},
  {"minus_i", Qubit.from_bloch(:math.pi() / 2, -:math.pi() / 2)},
  {"random", Qubit.random()}
]

# Generate SVGs
Enum.each(cases, fn {name, qubit} ->
  IO.puts("Generating #{name}...")
  svg = Qubit.draw_bloch(qubit, title: "State: |#{name}⟩")

  # Basic validation
  if String.starts_with?(svg, "<svg") and String.contains?(svg, "|0⟩") do
    IO.puts("  ✓ Valid SVG structure")
  else
    IO.puts("  ✗ Invalid SVG structure")
  end

  File.write!("output/bloch/#{name}.svg", svg)
end)

IO.puts("\nGenerated 7 Bloch sphere SVGs in output/bloch/")
