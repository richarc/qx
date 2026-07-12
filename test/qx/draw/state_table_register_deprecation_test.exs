defmodule Qx.Draw.StateTableRegisterDeprecationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  test "tensor input to draw_state renders silently (no deprecation warning)" do
    tensor = Qx.create_circuit(1) |> Qx.h(0) |> Qx.get_state()

    warn = capture_io(:stderr, fn -> assert %Qx.Draw.StateTable{} = Qx.draw_state(tensor) end)

    assert warn == ""
  end

  test "Register input to draw_state emits a deprecation warning and still renders" do
    register = Qx.Register.new(1)

    warn =
      capture_io(:stderr, fn ->
        assert %Qx.Draw.StateTable{} = Qx.draw_state(register)
      end)

    assert warn =~ "deprecated"
  end
end
