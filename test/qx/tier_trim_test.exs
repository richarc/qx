defmodule Qx.TierTrimTest do
  @moduledoc """
  Guards the v0.11 StateInit/Math tier trim (findings R-07/R-08/R-13).

  Asserts, via the compiled doc chunks:
  - the 17 trimmed functions carry `@deprecated` metadata,
  - the survivors do not,
  - `Qx.Behaviours.QuantumState` is demoted to hidden,
  - the two dead internal converters are gone.

  NOTE: functional coverage that the deprecated functions still WORK
  (the non-breaking half of the trim contract) lives in the original
  describe blocks of `test/qx/math_test.exs` and
  `test/qx/state_init_test.exs`. Those blocks are kept deliberately —
  do not delete them before the functions are removed at 1.0.
  """
  use ExUnit.Case, async: true

  @math_deprecated [
    kron: 2,
    inner_product: 2,
    outer_product: 2,
    trace: 1,
    unitary?: 1,
    apply_gate: 2,
    identity: 1,
    complex: 2
  ]

  @state_init_deprecated [
    zero_state: 2,
    one_state: 1,
    plus_state: 1,
    minus_state: 1,
    superposition_state: 2,
    random_state: 2,
    bell_state_vector: 2,
    ghz_state_vector: 2,
    w_state: 2
  ]

  describe "Qx.Math trimmed surface" do
    test "the 8 orphaned/wrapper functions carry deprecated metadata" do
      meta = deprecated_by_function(Qx.Math)

      for {name, arity} <- @math_deprecated do
        msg = meta[{name, arity}]

        assert is_binary(msg) and String.trim(msg) != "",
               "expected Qx.Math.#{name}/#{arity} to be @deprecated with a non-empty message"
      end
    end

    test "survivors normalize/1 and probabilities/1 are NOT deprecated" do
      meta = deprecated_by_function(Qx.Math)

      assert meta[{:normalize, 1}] == nil
      assert meta[{:probabilities, 1}] == nil
    end

    test "dead internal converters are deleted" do
      Code.ensure_loaded!(Qx.Math)

      refute function_exported?(Qx.Math, :complex_to_tensor, 1)
      refute function_exported?(Qx.Math, :tensor_to_complex, 1)
    end
  end

  describe "Qx.StateInit trimmed surface" do
    test "the 9 orphaned constructors carry deprecated metadata" do
      meta = deprecated_by_function(Qx.StateInit)

      for {name, arity} <- @state_init_deprecated do
        msg = meta[{name, arity}]

        assert is_binary(msg) and String.trim(msg) != "",
               "expected Qx.StateInit.#{name}/#{arity} to be @deprecated with a non-empty message"
      end
    end

    test "survivor basis_state/3 is NOT deprecated" do
      meta = deprecated_by_function(Qx.StateInit)

      assert meta[{:basis_state, 3}] == nil
    end
  end

  describe "Qx.Behaviours.QuantumState demotion (R-13)" do
    test "moduledoc is hidden" do
      assert {:docs_v1, _, _, _, :hidden, _, _} = Code.fetch_docs(Qx.Behaviours.QuantumState)
    end
  end

  # Maps {name, arity} -> deprecation message (or nil) from the doc chunk.
  # Functions with default arguments appear once, at their max arity.
  defp deprecated_by_function(module) do
    {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(module)

    for {{:function, name, arity}, _, _, _, meta} <- docs, into: %{} do
      {{name, arity}, meta[:deprecated]}
    end
  end
end
