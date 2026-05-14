defmodule Qx.Hardware.ConfigTest do
  use ExUnit.Case, async: true

  alias Qx.Hardware.Config
  alias Qx.Hardware.ConfigError

  doctest Qx.Hardware.Config

  describe "new/1" do
    @valid_attrs [
      portal_url: "https://api.qxquantum.com",
      portal_token: "ptok",
      ibm_api_key: "ibm",
      ibm_crn: "crn",
      ibm_region: "us-east",
      backend: "ibm_brisbane"
    ]

    test "returns {:ok, config} for valid attrs" do
      assert {:ok, %Config{} = config} = Config.new(@valid_attrs)
      assert config.optimization_level == 1
      assert config.shots == 4096
      assert config.identity == nil
      assert config.backends_list == []
    end

    test "accepts a map as well as a keyword list" do
      assert {:ok, %Config{}} = Config.new(Map.new(@valid_attrs))
    end

    test "missing required field returns ConfigError tagged with the field" do
      attrs = Keyword.delete(@valid_attrs, :portal_token)

      assert {:error, %ConfigError{field: :portal_token, reason: reason}} = Config.new(attrs)
      assert reason =~ "required"
    end

    test "empty-string field is rejected" do
      attrs = Keyword.put(@valid_attrs, :ibm_api_key, "")
      assert {:error, %ConfigError{field: :ibm_api_key}} = Config.new(attrs)
    end

    test "non-binary required field is rejected" do
      attrs = Keyword.put(@valid_attrs, :backend, 42)
      assert {:error, %ConfigError{field: :backend}} = Config.new(attrs)
    end

    test "rejects portal_url with non-http(s) scheme" do
      attrs = Keyword.put(@valid_attrs, :portal_url, "ftp://nope")

      assert {:error, %ConfigError{field: :portal_url, reason: reason}} = Config.new(attrs)
      assert reason =~ "scheme"
    end

    test "rejects optimization_level outside 0..3" do
      assert {:error, %ConfigError{field: :optimization_level}} =
               Config.new(Keyword.put(@valid_attrs, :optimization_level, 4))

      assert {:error, %ConfigError{field: :optimization_level}} =
               Config.new(Keyword.put(@valid_attrs, :optimization_level, -1))
    end

    test "accepts optimization_level 0, 1, 2, 3" do
      for level <- 0..3 do
        assert {:ok, %Config{optimization_level: ^level}} =
                 Config.new(Keyword.put(@valid_attrs, :optimization_level, level))
      end
    end

    test "rejects shots outside 1..100_000" do
      assert {:error, %ConfigError{field: :shots}} =
               Config.new(Keyword.put(@valid_attrs, :shots, 0))

      assert {:error, %ConfigError{field: :shots}} =
               Config.new(Keyword.put(@valid_attrs, :shots, 100_001))
    end

    test "rejects non-allowlisted region" do
      attrs = Keyword.put(@valid_attrs, :ibm_region, "mars-1")
      assert {:error, %ConfigError{field: :ibm_region}} = Config.new(attrs)
    end

    test "accepts all allowlisted regions" do
      for region <- ~w(us-east us-south eu-de eu-es jp-tok au-syd) do
        assert {:ok, %Config{ibm_region: ^region}} =
                 Config.new(Keyword.put(@valid_attrs, :ibm_region, region))
      end
    end
  end

  describe "new!/1" do
    test "returns struct on success" do
      attrs = [
        portal_url: "https://api.qxquantum.com",
        portal_token: "ptok",
        ibm_api_key: "ibm",
        ibm_crn: "crn",
        ibm_region: "us-east",
        backend: "ibm_brisbane"
      ]

      assert %Config{} = Config.new!(attrs)
    end

    test "raises ConfigError on failure" do
      assert_raise ConfigError, fn ->
        Config.new!(portal_url: "ftp://nope")
      end
    end
  end
end
