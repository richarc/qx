defmodule Qx.Hardware.ConfigFromEnvTest do
  @moduledoc """
  `from_env/1` and `from_env!/1` mutate process-global env vars during
  the test body. `async: false` so concurrent async tests cannot read
  poisoned `QX_*` values inside the put/restore window.
  """
  use ExUnit.Case, async: false

  alias Qx.Hardware.Config
  alias Qx.Hardware.ConfigError

  @full_env %{
    "QX_PORTAL_URL" => "https://api.qxquantum.com",
    "QX_PORTAL_TOKEN" => "ptok",
    "QX_IBM_API_KEY" => "ibm",
    "QX_IBM_CRN" => "crn",
    "QX_IBM_REGION" => "us-east",
    "QX_IBM_BACKEND" => "ibm_brisbane"
  }

  describe "from_env/1" do
    test "reads QX_* environment variables" do
      with_env(@full_env, fn ->
        assert {:ok, %Config{} = config} = Config.from_env()
        assert config.portal_url == "https://api.qxquantum.com"
        assert config.backend == "ibm_brisbane"
      end)
    end

    test "explicit opts override env" do
      with_env(@full_env, fn ->
        assert {:ok, %Config{shots: 1024}} = Config.from_env(shots: 1024)
      end)
    end

    test "from_env!/1 raises when a required env var is missing" do
      env = Map.put(@full_env, "QX_PORTAL_URL", nil)

      with_env(env, fn ->
        assert_raise ConfigError, fn -> Config.from_env!() end
      end)
    end
  end

  defp with_env(env, fun) do
    previous =
      for {k, _} <- env, into: %{} do
        {k, System.get_env(k)}
      end

    try do
      Enum.each(env, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)

      fun.()
    after
      Enum.each(previous, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end
  end
end
