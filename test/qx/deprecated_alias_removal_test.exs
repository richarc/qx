defmodule Qx.DeprecatedAliasRemovalTest do
  use ExUnit.Case, async: true

  # v0.10 closes the 0.8.x deprecation windows: the aliases are gone,
  # the canonical names remain.

  describe "removed aliases" do
    test "Qx.StateInit.bell_state/0,1,2 no longer exists" do
      Code.ensure_loaded!(Qx.StateInit)

      for arity <- 0..2 do
        refute function_exported?(Qx.StateInit, :bell_state, arity)
      end
    end

    test "Qx.StateInit.ghz_state/1,2 no longer exists" do
      Code.ensure_loaded!(Qx.StateInit)

      for arity <- 1..2 do
        refute function_exported?(Qx.StateInit, :ghz_state, arity)
      end
    end

    test "Qx.Math.basis_state/2 no longer exists" do
      Code.ensure_loaded!(Qx.Math)
      refute function_exported?(Qx.Math, :basis_state, 2)
    end

    test "Qx.histogram/1,2 no longer exists" do
      Code.ensure_loaded!(Qx)

      for arity <- 1..2 do
        refute function_exported?(Qx, :histogram, arity)
      end
    end
  end

  describe "canonical replacements still exported" do
    test "the _vector constructors, basis_state/3, and draw_histogram survive" do
      Code.ensure_loaded!(Qx.StateInit)
      Code.ensure_loaded!(Qx)

      assert function_exported?(Qx.StateInit, :bell_state_vector, 2)
      assert function_exported?(Qx.StateInit, :ghz_state_vector, 2)
      assert function_exported?(Qx.StateInit, :basis_state, 3)
      assert function_exported?(Qx, :draw_histogram, 2)
    end
  end
end
