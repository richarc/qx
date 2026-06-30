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

  describe "URL/host validation (loopback allowlist)" do
    # Reuses @valid_attrs from the "new/1" describe (module-wide attribute).

    test "portal_url: https to a remote host is accepted" do
      assert {:ok, %Config{}} = Config.new(@valid_attrs)
    end

    test "portal_url: http to loopback is accepted (localhost / 127.0.0.1 / ::1, with/without port)" do
      for url <- [
            "http://localhost",
            "http://localhost:4000",
            "http://127.0.0.1:9999",
            "http://[::1]:8080"
          ] do
        assert {:ok, %Config{}} = Config.new(Keyword.put(@valid_attrs, :portal_url, url)),
               "expected #{url} accepted"
      end
    end

    test "portal_url: plaintext http to a remote host is rejected" do
      for url <- ["http://remote-host", "http://example.com:8080", "http://api.qxquantum.com"] do
        assert {:error, %ConfigError{field: :portal_url, reason: reason}} =
                 Config.new(Keyword.put(@valid_attrs, :portal_url, url)),
               "expected #{url} rejected"

        assert reason =~ "loopback"
      end
    end

    test "base_url / iam_url default nil and are not validated" do
      assert {:ok, %Config{base_url: nil, iam_url: nil}} = Config.new(@valid_attrs)
    end

    test "base_url / iam_url: http to loopback is accepted" do
      attrs =
        @valid_attrs
        |> Keyword.put(:base_url, "http://localhost:8080")
        |> Keyword.put(:iam_url, "http://localhost:8081/identity/token")

      assert {:ok, %Config{}} = Config.new(attrs)
    end

    test "base_url: plaintext http to a remote host is rejected" do
      assert {:error, %ConfigError{field: :base_url, reason: reason}} =
               Config.new(Keyword.put(@valid_attrs, :base_url, "http://attacker/api/v1"))

      assert reason =~ "loopback"
    end

    test "iam_url: plaintext http to a remote host is rejected" do
      assert {:error, %ConfigError{field: :iam_url, reason: reason}} =
               Config.new(Keyword.put(@valid_attrs, :iam_url, "http://attacker/identity/token"))

      assert reason =~ "loopback"
    end

    test "loopback look-alike hosts are rejected (no allowlist bypass)" do
      # `localhost@evil.com` parses to host evil.com (userinfo stripped); the
      # subdomain/suffix tricks are not string-equal to a loopback host.
      for url <- [
            "http://localhost@evil.com",
            "http://localhost.attacker.com",
            "http://127.0.0.1.attacker.com",
            "http://notlocalhost"
          ] do
        assert {:error, %ConfigError{field: :portal_url}} =
                 Config.new(Keyword.put(@valid_attrs, :portal_url, url)),
               "expected #{url} rejected"
      end
    end

    test "loopback host matching is case-insensitive (http://LOCALHOST accepted)" do
      assert {:ok, %Config{}} =
               Config.new(Keyword.put(@valid_attrs, :portal_url, "http://LOCALHOST:4000"))
    end

    test "https to a remote host is accepted for base_url / iam_url" do
      attrs =
        @valid_attrs
        |> Keyword.put(:base_url, "https://api.example.com")
        |> Keyword.put(:iam_url, "https://iam.example.com/identity/token")

      assert {:ok, %Config{}} = Config.new(attrs)
    end

    test "non-http(s) scheme is rejected on every URL field" do
      for {field, url} <- [
            portal_url: "ws://nope",
            base_url: "ftp://nope",
            iam_url: "gopher://nope"
          ] do
        assert {:error, %ConfigError{field: ^field}} =
                 Config.new(Keyword.put(@valid_attrs, field, url))
      end
    end

    test "malformed / empty-host URL is rejected" do
      for {field, url} <- [
            portal_url: "http://",
            base_url: "not a uri",
            iam_url: "https://"
          ] do
        assert {:error, %ConfigError{field: ^field}} =
                 Config.new(Keyword.put(@valid_attrs, field, url))
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

  describe "inspect/1 secret redaction (qx-o9h)" do
    setup do
      config =
        Config.new!(
          portal_url: "https://api.qxquantum.com",
          portal_token: "PTOK-SECRET-123",
          ibm_api_key: "IBMKEY-SECRET-456",
          ibm_crn: "crn:v1:bluemix:SECRET-789",
          ibm_region: "us-east",
          backend: "ibm_brisbane"
        )

      config = %{config | access_token: "ACCESS-SECRET-000"}
      %{config: config, dump: inspect(config)}
    end

    test "no credential value appears in inspect output", %{dump: dump} do
      refute dump =~ "PTOK-SECRET-123"
      refute dump =~ "IBMKEY-SECRET-456"
      refute dump =~ "SECRET-789"
      refute dump =~ "ACCESS-SECRET-000"
    end

    test "secrets redacted even when the struct is nested in a tuple/log shape",
         %{config: config} do
      dump = inspect({:error, {:ibm_submit, %{config: config}}})
      refute dump =~ "PTOK-SECRET-123"
      refute dump =~ "IBMKEY-SECRET-456"
      refute dump =~ "ACCESS-SECRET-000"
    end

    test "non-secret fields stay visible", %{dump: dump} do
      assert dump =~ "ibm_brisbane"
      assert dump =~ "us-east"
      assert dump =~ "api.qxquantum.com"
    end
  end
end
