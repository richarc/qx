defmodule Qx.Hardware.PortalTest do
  @moduledoc """
  Verifies `Qx.Hardware.Portal.transpile/3` (and `me/1`) against the
  qxportal `/api/v1` contract via Bypass.
  """
  use ExUnit.Case, async: true

  alias Qx.Hardware.Config
  alias Qx.Hardware.Portal

  setup do
    bypass = Bypass.open()

    config = %Config{
      portal_url: "http://localhost:#{bypass.port}",
      portal_token: "qx_live_test_token",
      ibm_api_key: "ibm",
      ibm_crn: "crn",
      ibm_region: "us-south",
      backend: "ibm_brisbane"
    }

    %{bypass: bypass, config: config}
  end

  defp json_resp(conn, status, payload) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(payload))
  end

  defp sample_qasm,
    do: "OPENQASM 3.0;\nqubit[2] q;\nh q[0];\ncx q[0], q[1];\nmeasure q;"

  defp sample_opts,
    do: [
      coupling_map: [[0, 1], [1, 2]],
      basis_gates: ["id", "rz", "sx", "x", "cx"],
      optimization_level: 1
    ]

  describe "me/1" do
    test "returns identity on 200", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/me", fn conn ->
        assert ["Bearer qx_live_test_token"] = Plug.Conn.get_req_header(conn, "authorization")

        json_resp(conn, 200, %{
          data: %{
            email: "test@example.com",
            role: "user",
            api_key_name: "default"
          }
        })
      end)

      assert {:ok, identity} = Portal.me(config)
      assert identity.email == "test@example.com"
      assert identity.role == "user"
    end

    test "401 maps to :unauthorized", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/v1/me", fn conn ->
        json_resp(conn, 401, %{error: "unauthorized"})
      end)

      assert Portal.me(config) == {:error, :unauthorized}
    end
  end

  describe "transpile/3 happy path" do
    test "returns parsed transpile result on 200", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        assert ["Bearer qx_live_test_token"] = Plug.Conn.get_req_header(conn, "authorization")
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert {:ok, decoded} = Jason.decode(body)
        assert decoded["qasm"] =~ "OPENQASM 3.0;"
        assert decoded["backend"] == "ibm_brisbane"
        assert decoded["coupling_map"] == [[0, 1], [1, 2]]
        assert decoded["optimization_level"] == 1

        json_resp(conn, 200, %{
          data: %{
            qasm: "OPENQASM 3.0;\n// transpiled\n",
            metadata: %{depth: 5, size: 8, num_qubits: 2}
          }
        })
      end)

      assert {:ok, result} = Portal.transpile(config, sample_qasm(), sample_opts())
      assert result.qasm =~ "transpiled"
      assert result.metadata == %{depth: 5, size: 8, num_qubits: 2}
    end

    test "defaults backend + optimization_level from config", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert {:ok, decoded} = Jason.decode(body)
        assert decoded["backend"] == "ibm_brisbane"
        # config.optimization_level defaults to 1
        assert decoded["optimization_level"] == 1

        json_resp(conn, 200, %{
          data: %{qasm: "OPENQASM 3.0;", metadata: %{depth: 0, size: 0, num_qubits: 0}}
        })
      end)

      assert {:ok, _result} = Portal.transpile(config, sample_qasm())
    end
  end

  describe "transpile/3 error mapping" do
    test "401 maps to :unauthorized", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        json_resp(conn, 401, %{error: "unauthorized"})
      end)

      assert Portal.transpile(config, sample_qasm(), sample_opts()) == {:error, :unauthorized}
    end

    test "422 maps to {:invalid_qasm, detail}", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        json_resp(conn, 422, %{error: "invalid_qasm", detail: "Parse error at line 1"})
      end)

      assert Portal.transpile(config, sample_qasm(), sample_opts()) ==
               {:error, {:invalid_qasm, "Parse error at line 1"}}
    end

    test "422 falls back to error code when detail missing", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        json_resp(conn, 422, %{error: "invalid_qasm"})
      end)

      assert Portal.transpile(config, sample_qasm(), sample_opts()) ==
               {:error, {:invalid_qasm, "invalid_qasm"}}
    end

    test "429 with retry-after maps to {:rate_limited, secs}", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", "12")
        |> json_resp(429, %{error: "rate_limited"})
      end)

      assert Portal.transpile(config, sample_qasm(), sample_opts()) ==
               {:error, {:rate_limited, 12}}
    end

    test "502 maps to :transpile_failed", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        json_resp(conn, 502, %{error: "transpile_failed"})
      end)

      assert Portal.transpile(config, sample_qasm(), sample_opts()) ==
               {:error, :transpile_failed}
    end

    test "503 maps to :transpile_unavailable", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        json_resp(conn, 503, %{error: "transpile_unavailable"})
      end)

      assert Portal.transpile(config, sample_qasm(), sample_opts()) ==
               {:error, :transpile_unavailable}
    end

    test "504 maps to :transpile_timeout", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        json_resp(conn, 504, %{error: "transpile_timeout"})
      end)

      assert Portal.transpile(config, sample_qasm(), sample_opts()) ==
               {:error, :transpile_timeout}
    end

    test "other status falls through to {:http, status, body}", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/v1/transpile", fn conn ->
        json_resp(conn, 418, %{error: "teapot"})
      end)

      assert {:error, {:http, 418, %{"error" => "teapot"}}} =
               Portal.transpile(config, sample_qasm(), sample_opts())
    end

    test "network failure maps to {:network, reason}", %{bypass: bypass, config: config} do
      Bypass.down(bypass)
      assert {:error, {:network, _}} = Portal.transpile(config, sample_qasm(), sample_opts())
    end
  end
end
