defmodule Qx.DoctestDirectivesTest do
  # Modules whose `iex>` examples had no `doctest` directive anywhere, so the
  # examples were never run (TDD rule 4).
  use ExUnit.Case, async: true

  doctest Qx.Simulation
  doctest Qx.Step
  doctest Qx.Draw.StateTable
  doctest Qx.Draw.Image
  doctest Qx.Gates
  doctest Qx.Calc
end
